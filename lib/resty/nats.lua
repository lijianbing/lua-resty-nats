local tcp = ngx.socket.tcp
local uuid   = require "resty.jit-uuid"
uuid.seed()

local _M = {}
local mt = { __index = _M }

-- registration callback table
local r = {}


function _M.new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    return setmetatable({ sock = sock, subscribed = false }, mt)
end


function _M.connect(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    local ok, err =  sock:connect(...)
    if not ok then
        return false, err
    end

    -- set verbose to false
    ok, err = sock:send('CONNECT {"verbose":false}\r\n')
    local cnt = sock:getreusedtimes()
    -- receive INFO in new connection
    if cnt==0 then
        -- initial INFO packet
        local data, err = sock:receive()
        if not data then
            return false, err
        end
    end

    -- TODO authorize, CONNECT

    self.connected = true
    return true, ''
end


function _M.set_keepalive(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    if self.subscribed then
        return nil, "subscribed state"
    end
    return sock:setkeepalive_nats(...)
end


local function create_inbox()
    return '_INBOX.' .. uuid()
end


local function parse_message(line)
    local msg = {}
    local res  = {}
    local data    = {}

    for slice in line:gmatch('[^%s]+') do
        table.insert(res, slice)
    end

    msg.type = string.upper(res[1])

    if msg.type == "MSG" then
        msg.subject = res[2]
        msg.sid = res[3]

        -- TODO check this logic
        if res[5] == nil then
            msg.len = tonumber(res[4])
        else
            msg.reply_to = res[4]
            msg.len = tonumber(res[5])
        end
    end

    return msg
end


function _M.subscribe(self, subject, callback)
    if not self.connected then
        return false, "not connected"
    end

    if type(subject) ~= "string" then
        return false, "subject is not a string"
    end

    if type(callback) ~= "function" then
        return false, "callback is not a function"
    end

    local sid = uuid()
    if r[sid] then
        return false, "already subscribed with sid " .. sid
    end

    local _, err = self.sock:send(string.format("SUB %s %s\r\n", subject, sid))
    if err then
        return false, err
    end

    r[sid] = callback
    self.subscribed = true
    return sid, ''
end


function _M.unsubscribe(self, sid)
    if not self.connected then
        return false, "not connected"
    end

    if type(sid) ~= "string" then
        return false, "sid is not a string"
    end

    local _, err = self.sock:send(string.format("UNSUB %s\r\n", sid))
    if err then
        return false, err
    end
    if r[sid] then
        r[sid] = nil
    end
    self.subscribed = false
    return true, ''
end


function _M.publish(self, subject, payload, reply_to)
    if not self.connected then
        return false, "not connected"
    end

    local msg
    if reply_to then
        msg = string.format("PUB %s %s %d\r\n%s\r\n", subject, reply_to, #payload, payload)
    else
        msg = string.format("PUB %s %d\r\n%s\r\n", subject, #payload, payload)
    end

    local _, err = self.sock:send(msg)
    if err then
        return false, err
    end

    return true, ""
end


function _M.request(self, subject, payload, callback)
    if not self.connected then
        return false, "not connected"
    end

    local inbox = create_inbox()
    local cid
    local err
    cid, err = self.subscribe(self, inbox, function(message)
        self.unsubscribe(self, cid)
        callback(message)
    end)
    if not cid then
        return false , err
    end
    self.publish(self, subject, payload, inbox)
    return true, ''
end


function _M.wait(self, quantity)
    quantity = quantity or 0

    local count = 0
    local data, err
    repeat
        data, err = self.sock:receive()
        if not data then
          break
        end

        local msg = parse_message(data)

        if msg.type == "PING" then
            data, err = self.sock:send("PONG\r\n")
            if err then
                break
            end
        elseif msg.type == "MSG" then
            data, err = self.sock:receive(msg.len)
            if not data then
                break
            end
            msg.payload = data
            count = count + 1

            -- discard trailing newline
            data, err = self.sock:receive(2)
            if err then
		break
            end
            if r[msg.sid] then
                r[msg.sid](msg)
	    else
		ngx.log(ngx.WARN, 'sid is null ', msg.sid)
		data = nil
		err = 'sid is null'
		break
            end
        end
    until quantity > 0 and count >= quantity
    if not data and err then
        return false, err
    end
    return true, ''
end


function _M.close(self)
    if not self.connected then
        return false, "not connected"
    end
    return self.sock.close()
end

return _M
