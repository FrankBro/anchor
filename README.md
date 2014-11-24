

# anchor #

__Authors:__ Louis-Philippe Gauthier.

Non-blocking Erlang Memcached client

[![Build Status](https://travis-ci.org/lpgauth/anchor.svg?branch=master)](https://travis-ci.org/lpgauth/anchor)


## Features ##
* Performance optimized
* Binary protocol
* Pipelining
* Backpressure (OOM protection)
* Async mode



## Examples ##

```erlang

1> application:start(anchor).
ok
2> anchor:get(<<"foo">>).
{error,key_not_found}
3> anchor:set(<<"foo">>, <<"bar">>, 3600).
ok
4> anchor:get(<<"foo">>).
{ok,<<"bar">>}
5> anchor:delete(<<"foo">>).
ok
6> anchor:get(<<"foo">>, 1000, [{async, self()}]).
{ok,#Ref<0.0.0.23623>}
7> flush().
Shell got {anchor,#Ref<0.0.0.23623>,{error,key_not_found}}
ok
```



## Modules ##


<table width="100%" border="0" summary="list of modules">
<tr><td><a href="http://github.com/lpgauth/anchor/blob/cleanup/doc/anchor.md" class="module">anchor</a></td></tr>
<tr><td><a href="http://github.com/lpgauth/anchor/blob/cleanup/doc/anchor_app.md" class="module">anchor_app</a></td></tr>
<tr><td><a href="http://github.com/lpgauth/anchor/blob/cleanup/doc/anchor_backlog.md" class="module">anchor_backlog</a></td></tr>
<tr><td><a href="http://github.com/lpgauth/anchor/blob/cleanup/doc/anchor_protocol.md" class="module">anchor_protocol</a></td></tr>
<tr><td><a href="http://github.com/lpgauth/anchor/blob/cleanup/doc/anchor_server.md" class="module">anchor_server</a></td></tr>
<tr><td><a href="http://github.com/lpgauth/anchor/blob/cleanup/doc/anchor_sup.md" class="module">anchor_sup</a></td></tr></table>

