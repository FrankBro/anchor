

# Module anchor_protocol #
* [Function Index](#index)
* [Function Details](#functions)


<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#decode-2">decode/2</a></td><td></td></tr><tr><td valign="top"><a href="#decode-3">decode/3</a></td><td></td></tr><tr><td valign="top"><a href="#encode-2">encode/2</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="decode-2"></a>

### decode/2 ###


<pre><code>
decode(ReqId::pos_integer(), Data::binary()) -&gt; {ok, binary(), <a href="#type-response">response()</a>}
</code></pre>
<br />


<a name="decode-3"></a>

### decode/3 ###


<pre><code>
decode(ReqId::pos_integer(), Data::binary(), Response::<a href="#type-response">response()</a>) -&gt; {ok, binary(), <a href="#type-response">response()</a>}
</code></pre>
<br />


<a name="encode-2"></a>

### encode/2 ###


<pre><code>
encode(ReqId::pos_integer(), X2::atom() | tuple()) -&gt; {ok, binary()}
</code></pre>
<br />


