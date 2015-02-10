-module(anchor_server).
-include("anchor.hrl").

-export([
    async_call/2,
    call/2,
    init/1,
    start_link/0
]).

-record(state, {
    ip          = undefined,
    port        = undefined,
    socket      = undefined,
    queue       = queue:new(),
    req_counter = 0,
    buffer      = <<>>,
    ref         = undefined,
    from        = undefined,
    response    = undefined
}).

%% public
-spec call(term(), pos_integer()) -> ok | {ok, term()} | error().
call(Msg, Timeout) ->
    case async_call(Msg, self()) of
        {ok, Ref} ->
            receive
                {anchor, Ref, Reply} ->
                    Reply
                after Timeout ->
                    {error, timeout}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

-spec async_call(term(), pid()) -> {ok, erlang:ref()} | {error, backlog_full}.
async_call(Msg, Pid) ->
    Ref = make_ref(),
    case anchor_backlog:check(?BACKLOG_TABLE_ID, ?BACKLOG_MAX_SIZE) of
        true ->
            ?MODULE ! {call, Ref, Pid, Msg},
            {ok, Ref};
        _ ->
            {error, backlog_full}
    end.

-spec init(pid()) -> no_return().
init(Parent) ->
    register(?MODULE, self()),
    proc_lib:init_ack(Parent, {ok, self()}),
    anchor_backlog:new(?BACKLOG_TABLE_ID),
    self() ! newsocket,

    loop(#state {
        ip = application:get_env(?APP, ip, ?DEFAULT_IP),
        port = application:get_env(?APP, port, ?DEFAULT_PORT)
    }).

-spec start_link() -> {ok, pid()}.
start_link() ->
    proc_lib:start_link(?MODULE, init, [self()]).

%% private
loop(State) ->
    receive Msg ->
        {ok, State2} = handle_msg(Msg, State),
        loop(State2)
    end.

handle_msg({call, Ref, From, _Msg}, #state {
        socket = undefined
    } = State) ->

    reply(Ref, From, {error, no_socket}),
    {ok, State};
handle_msg({call, Ref, From, Msg}, #state {
        socket = Socket,
        queue = Queue,
        req_counter = ReqCounter
    } = State) ->

    ReqId = req_id(ReqCounter),
    {ok, Packet} = anchor_protocol:encode(ReqId, Msg),
    case gen_tcp:send(Socket, Packet) of
        {error, Reason} ->
            error_logger:error_msg("tcp send error: ~p", [Reason]),
            reply(Ref, From, {error, Reason}),
            gen_tcp:close(Socket),
            tcp_close(Queue, State);
        ok ->
            queue_in({ReqId, Ref, From}, State)
    end;
handle_msg(newsocket, #state {
        ip = Ip,
        port = Port
    } = State) ->

    Opts = [
        binary,
        {active, once},
        {nodelay, true},
        {packet, raw},
        {send_timeout, ?DEFAULT_SEND_TIMEOUT},
        {send_timeout_close, true}
    ],
    case gen_tcp:connect(Ip, Port, Opts) of
        {ok, Socket} ->
            {ok, State#state {
                socket = Socket
            }};
        {error, Reason} ->
            error_logger:error_msg("tcp connect error: ~p", [Reason]),
            erlang:send_after(?DEFAULT_RECONNECT, self(), newsocket),
            {ok, State}
    end;
handle_msg({tcp, Socket, Data}, #state {
        socket = Socket,
        buffer = Buffer
    } = State) ->

    inet:setopts(Socket, [{active, once}]),
    Data2 = <<Buffer/binary, Data/binary>>,
    decode_data(Data2, State);
handle_msg({tcp, _Socket, _Data}, State) ->
    {ok, State};
handle_msg({tcp_closed, Socket}, #state {
        socket = Socket,
        queue = Queue
    } = State) ->

    error_logger:error_msg("tcp closed", []),
    tcp_close(Queue, State);
handle_msg({tcp_error, Socket, Reason}, #state {
        socket = Socket,
        queue = Queue
    } = State) ->

    error_logger:error_msg("tcp error: ~p", [Reason]),
    gen_tcp:close(Socket),
    tcp_close(Queue, State).

%% private
decode_data(<<>>, State) ->
    {ok, State};
decode_data(Data, #state {
        ref = undefined,
        from = undefined
    } = State) ->

    case queue_out(State) of
        {ok, {ReqId, Ref, From}, State2} ->
            {ok, Rest, #response {
                state = Parsing
            } = Resp} = anchor_protocol:decode(ReqId, Data),

            case Parsing of
                complete ->

                    reply(Ref, From, reply(Resp)),
                    decode_data(Rest, State2#state {
                        buffer = <<>>
                    });
                _ ->
                    {ok, State2#state {
                        buffer = Rest,
                        ref = Ref,
                        from = From,
                        response = Resp#response {
                            opaque = ReqId
                        }
                    }}
            end;
        {error, empty} ->
            error_logger:warning_msg("empty queue", []),
            {ok, State}
    end;
decode_data(Data, #state {
        ref = Ref,
        from = From,
        response = #response {
            opaque = ReqId
        } = Resp
    } = State) ->

    {ok, Rest, #response {
        state = Parsing
    } = Resp2} = anchor_protocol:decode(ReqId, Data, Resp),

    case Parsing of
        complete ->
            reply(Ref, From, reply(Resp2)),
            decode_data(Rest, State#state {
                ref = undefined,
                from = undefined,
                buffer = <<>>,
                response = undefined
            });
        _ ->
            {ok, State#state {
                buffer = Rest,
                response = Resp2
            }}
    end.

queue_in(Item, #state {
        queue = Queue,
        req_counter = ReqCounter
    } = State) ->

    {ok, State#state {
        queue = queue:in(Item, Queue),
        req_counter = ReqCounter + 1
    }}.

queue_out(#state {
        queue = Queue
    } = State) ->

    case queue:out(Queue) of
        {{value, Item}, Queue2} ->
            {ok, Item, State#state {
                queue = Queue2
            }};
        {empty, Queue} ->
            {error, empty}
    end.

reply(#response {status = Status} = Response) ->
    case status(Status) of
        ok ->
            return(Response);
        Reason ->
            {error, Reason}
    end.

reply(Ref, From, Msg) ->
    anchor_backlog:decrement(?BACKLOG_TABLE_ID),
    From ! {anchor, Ref, Msg}.

reply_all(Queue, Msg) ->
    [reply(Ref, From, Msg) || {_ReqId, Ref, From} <- queue:to_list(Queue)].

req_id(N) ->
    (N + 1) rem ?MAX_32_BIT_INT.

return(#response {op_code = ?OP_ADD}) -> ok;
return(#response {op_code = ?OP_DECREMENT, value = Value}) ->
    {ok, binary:decode_unsigned(Value)};
return(#response {op_code = ?OP_DELETE}) -> ok;
return(#response {op_code = ?OP_FLUSH}) -> ok;
return(#response {op_code = ?OP_GET, value = Value}) ->
    {ok, Value};
return(#response {op_code = ?OP_INCREMENT, value = Value}) ->
    {ok, binary:decode_unsigned(Value)};
return(#response {op_code = ?OP_NOOP}) -> ok;
return(#response {op_code = ?OP_QUIT}) -> ok;
return(#response {op_code = ?OP_REPLACE}) -> ok;
return(#response {op_code = ?OP_SET}) -> ok;
return(#response {op_code = ?OP_VERSION, value = Value}) ->
    {ok, Value}.

status(?STAT_AUTH_CONTINUE) -> auth_continue;
status(?STAT_AUTH_ERROR) -> auth_error;
status(?STAT_BUSY) -> busy;
status(?STAT_INCR_NON_NUMERIC) -> incr_non_numeric;
status(?STAT_INTERNAL_ERROR) -> internal_error;
status(?STAT_INVALID_ARGS) -> invalid_args;
status(?STAT_ITEM_NOT_STORED) -> item_not_stored;
status(?STAT_KEY_EXISTS) -> key_exists;
status(?STAT_KEY_NOT_FOUND) -> key_not_found;
status(?STAT_NOT_SUPPORTED) -> not_supported;
status(?STAT_OK) -> ok;
status(?STAT_OUT_OF_MEMORY) -> out_of_memory;
status(?STAT_TEMP_FAILURE) -> temp_failure;
status(?STAT_UNKNOWN_COMMAND) -> unknown_command;
status(?STAT_VALUE_TOO_LARGE) -> value_too_large;
status(?STAT_VBUCKET_ERROR) -> vbucket_error.

tcp_close(Queue, State) ->
    reply_all(Queue, {error, tcp_closed}),
    erlang:send_after(?DEFAULT_RECONNECT, self(), newsocket),

    {ok, State#state {
        socket = undefined,
        queue = queue:new(),
        buffer = <<>>,
        ref = undefined,
        from = undefined,
        response = undefined
    }}.
