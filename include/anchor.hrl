% op codes
-define(OP_GET, 16#00).
-define(OP_SET, 16#01).

% protocol
-define(CAS, 16#00).
-define(DATA_TYPE, 16#00).
-define(HEADER_LENGTH, 24).
-define(MAGIC_REQUEST, 16#80).
-define(MAGIC_RESPONSE, 16#81).
-define(VBUCKET, 16#00).

% server
-define(DEFAULT_IP, "127.0.0.1").
-define(DEFAULT_PORT, 11211).
-define(DEFAULT_TIMEOUT, 10000).
-define(DEFAULT_TTL, 0).
-define(RECONNECT_AFTER, 5000).
-define(SERVER, anchor_server).

% utils
-define(CHILD(Mod), {Mod, {Mod, start_link, []}, permanent, 5000, worker, [Mod]}).
-define(MAX_32_BIT_INT, 4294967296).

% records
-record(request, {
    op_code   = undefined,
    data_type = ?DATA_TYPE,
    vbucket   = ?VBUCKET,
    opaque    = <<>>,
    cas       = ?CAS,
    extras    = <<>>,
    key       = <<>>,
    value     = <<>>
}).

-record(response, {
    parsing = header,
    op_code,
    key_length,
    extras_length,
    data_type,
    status,
    body_length,
    opaque,
    cas,
    extras,
    key,
    value
}).
