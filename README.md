Name
====

lua-resty-nats - Lua NATS client driver for ngx_lua based on the cosocket API

Table of Contents
=================

* [Name](#name)
* [Description](#description)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [new](#new)
    * [connect](#connect)
    * [set_keepalive](#set_keepalive)
    * [get_reused_times](#get_reused_times)
    * [close](#close)
    * [subscribe](#subscribe)
    * [unsubscribe](#unsubscribe)
    * [publish](#pbulish)
    * [request](#request)
    * [wait](#wait)
* [Limitations](#limitations)
* [Installation](#installation)
* [Usage](#usage)

Description
===========

This Lua library is a NATS client driver for the ngx_lua nginx module:

https://github.com/openresty/lua-nginx-module

This Lua library takes advantage of ngx_lua's cosocket API, which ensures
100% nonblocking behavior.

Note that at least [ngx_lua-0.10.15](https://github.com/chaoslawful/lua-nginx-module/tags) or [openresty-1.15.8.1](http://openresty.org/#Download) is required.

Also, the [bit library](http://bitop.luajit.org/) is also required. If you're using LuaJIT 2 with ngx_lua, then the `bit` library is already available by default.

Synopsis
========

```lua

    # nginx.conf

    server {
        location /nats {
            default_type 'application/json';
            lua_socket_connect_timeout 300s;
            lua_socket_send_timeout    30s;
            lua_socket_read_timeout    30s;
            content_by_lua_file /usr/local/openresty/nginx/conf/lua_resty_nats_pub.lua;
        }

    }
    
    #/usr/local/openresty/nginx/conf/lua_resty_nats_pub.lua
    #see usage below
```

[Back to TOC](#table-of-contents)

Methods
=======

[Back to TOC](#table-of-contents)

new
---
`syntax: n, err = nats:new()`

Creates a NATS connection object. In case of failures, returns `nil` and a string describing the error.

[Back to TOC](#table-of-contents)

connect
-------
`syntax: ok, err = n:connect(host, port)`

Attempts to connect to the remote NATS server.

* `host`

    the host name for the NATS server.
    
* `port`

    the port that the NATS server is listening on.


[Back to TOC](#table-of-contents)

set_keepalive
------------
`syntax: ok, err = n:set_keepalive(max_idle_timeout, pool_size)`

Puts the current NATS connection immediately into the ngx_lua cosocket connection pool.

You can specify the max idle timeout (in ms) when the connection is in the pool and the maximal size of the pool every nginx worker process.

In case of success, returns `1`. In case of errors, returns `nil` with a string describing the error.

Only call this method in the place you would have called the `close` method instead. Calling this method will immediately turn the current `resty.nats` object into the `closed` state. Any subsequent operations other than `connect()` on the current objet will return the `closed` error.

[Back to TOC](#table-of-contents)

get_reused_times
----------------
`syntax: times, err = n:get_reused_times()`

This method returns the (successfully) reused times for the current connection. In case of error, it returns `nil` and a string describing the error.

If the current connection does not come from the built-in connection pool, then this method always returns `0`, that is, the connection has never been reused (yet). If the connection comes from the connection pool, then the return value is always non-zero. So this method can also be used to determine if the current connection comes from the pool.

[Back to TOC](#table-of-contents)

close
-----
`syntax: ok, err = n:close()`

Closes the current nats connection and returns the status.

In case of success, returns `1`. In case of errors, returns `nil` with a string describing the error.

[Back to TOC](#table-of-contents)

subscribe
----------
`syntax: sid, err = n:subscribe(subject, callback)'

Subcribe a subject from nats server

Returns a unique sid in success and otherwise returns `nil` and a string describing the error.

[Back to TOC](#table-of-contents)

unsubscribe
-----------
`syntax: ok, err = n:unsubscribe(sid)`

Unsubscribe subject identified by sid from  nats server

It returns true in success and otherwise returns `nil` and a string describing the error.

[Back to TOC](#table-of-contents)

publish
-----
`syntax: ok, err = n:publish(subject, payload, reply_to)'

Publishes the message payload to the given subject, optionally supplying a reply_to subject.

It returns true in success and otherwise returns `nil` and a string describing the error.

[Back to TOC](#table-of-contents)

request
----------
`syntax: ok, err = n:request(subject, payload, callback)'

Request-Reply was implemented by request. 

It returns true in success and otherwise returns `nil` and a string describing the error.

[Back to TOC](#table-of-contents)

wait
------------------
`syntax: n:wait(cnt)`

Waits are typically used in conjunction with requests. Its function is to wait for cnt returns to be received.

It returns true in success and otherwise returns `nil` and a string describing the error.

[Back to TOC](#table-of-contents)

Limitations
===========

* This library cannot be used in code contexts like init_by_lua*, set_by_lua*, log_by_lua*, and
header_filter_by_lua* where the ngx_lua cosocket API is not available.
* The `resty.nats` object instance cannot be stored in a Lua variable at the Lua module level,
because it will then be shared by all the concurrent requests handled by the same nginx
 worker process (see
https://github.com/openresty/lua-nginx-module#data-sharing-within-an-nginx-worker ) and
result in bad race conditions when concurrent requests are trying to use the same `resty.nats` instance.
You should always initiate `resty.nats` objects in function local
variables or in the `ngx.ctx` table. These places all have their own data copies for
each request.

[Back to TOC](#table-of-contents)

Installation
============

* Important:
    Official openresty cannot support nats pool (set_keepalive) because of the existence of heartbeat with NATs server.
    
    File src/ngx_http_lua_socket_tcp.c handled the heartbeat, thus maintaining the connection.

    You need replace openresty-1.15.8.2/bundle/ngx_lua-0.10.15/src/ngx_http_lua_socket_tcp.c, and rebuild openresty.

    lua-resty-nats is test under openresty-1.15.8.1/openresty-1.15.8.2.

With [LuaRocks](https://luarocks.org/):

```
    luarocks install lua-resty-jit-uuid
    luarocks install lua-resty-nats
```

Or simplely put 
    jit-uuid.lua  (https://github.com/thibaultcha/lua-resty-jit-uuid/tree/master/lib/resty) 
    nats.lua      (https://github.com/lijianbing/lua-resty-nats/tree/master/lib/resty)
under openresty/lualib/resty/.

[Back to TOC](#table-of-contents)

Usage
=========

```lua

    local nats = require "resty.nats"
    local internal_error = '{"code": 500, "msg": "Service is temporarily unavailable. Please try again later"}'
    local n = nats:new()
    local ok, err = n:connect("127.0.0.1", 4222)
    if not ok then
        ngx.say(internal_error)
        ngx.exit(200)
    end

    ngx.req.read_body()
    local data = ngx.req.get_body_data()

    local function request_callback(msg)
        ngx.say(msg.payload)
    end
    ok, err = n:request('rpc', data, request_callback)
    if not ok then
        ngx.say(internal_error)
        ngx.exit(200)
    else
        ok,err = n:wait(1)
        if not ok and err then
            ngx.say(internal_error)
            ngx.exit(200)
        end
    end
    ok, err = n:set_keepalive(0, 1024)

```
[Back to TOC](#table-of-contents)
