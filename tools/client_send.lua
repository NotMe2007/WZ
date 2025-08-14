-- client_send.lua
-- Example Lua client to POST JSON/text to your PC server.
-- It will try LuaSocket first, then fallback to curl via os.execute.

-- Network target defaults — override by calling configure() or setting getgenv().PC_SEND
local PC_IP = '192.168.31.1' -- e.g. 192.168.1.5
local PC_PORT = 8000
local PATH = '/upload'

-- Allow runtime overrides from environment (safe read)
local _env = (type(rawget and rawget(_G, 'getgenv')) == 'function' and rawget(_G, 'getgenv')()) or {}
if type(_env.PC_SEND) == 'table' then
    PC_IP = _env.PC_SEND.ip or PC_IP
    PC_PORT = _env.PC_SEND.port or PC_PORT
    PATH = _env.PC_SEND.path or PATH
end

local function json_encode_simple(t)
    local function quote(s)
        s = tostring(s)
        s = s:gsub('\\','\\\\')
        s = s:gsub('"','\\"')
        s = s:gsub('\n','\\n')
        return '"'..s..'"'
    end
    local ty = type(t)
    if ty == 'string' then return quote(t) end
    if ty == 'number' or ty == 'boolean' then return tostring(t) end
    if ty == 'table' then
        local isarray = true
        local i = 0
        for _ in pairs(t) do i = i + 1; if t[i] == nil then isarray = false; break end end
        local parts = {}
        if isarray then
            for i=1,#t do parts[#parts+1] = json_encode_simple(t[i]) end
            return '['..table.concat(parts, ',')..']'
        else
            for k,v in pairs(t) do parts[#parts+1] = quote(k)..':'..json_encode_simple(v) end
            return '{'..table.concat(parts, ',')..'}'
        end
    end
    return quote(tostring(t))
end

local function post_via_luasocket(url, body)
    local ok_http, http = pcall(require, 'socket.http')
    if not ok_http or not http then return false, 'luasocket.http not available' end
    local ok_ltn, ltn12 = pcall(require, 'ltn12')
    if not ok_ltn or not ltn12 then return false, 'ltn12 not available' end
    local resp = {}
    local r, c, h = http.request{
        url = url,
        method = 'POST',
        headers = { ['Content-Type'] = 'application/json', ['Content-Length'] = tostring(#body) },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(resp),
    }
    -- http.request returns 1 on success in some LuaSocket builds
    local success = (r ~= nil)
    return success, table.concat(resp), c
end

local function post_via_curl(url, body)
    -- If os.execute is not available, give up early
    if type(os) ~= 'table' or type(os.execute) ~= 'function' then return false, 'os.execute not available' end
    -- write to a safe temp file
    local tmp = nil
    pcall(function() tmp = os.tmpname() end)
    if not tmp then tmp = 'tmp_post_body.json' end
    local fh, ferr = io.open(tmp, 'wb')
    if not fh then return false, 'cannot write tmp file: ' .. tostring(ferr) end
    fh:write(body)
    fh:close()
    local cmd = string.format('curl -s -X POST -H "Content-Type: application/json" --data-binary @%s "%s"', tmp, url)
    local res = os.execute(cmd)
    -- best-effort cleanup
    pcall(function() os.remove(tmp) end)
    return res == 0, tostring(res)
end

local function send(data, name)
    local body = json_encode_simple(data)
    local url = string.format('http://%s:%d%s', PC_IP, PC_PORT, PATH)
    -- try luasocket
    local ok, resp_or_err = post_via_luasocket(url, body)
    if ok then print('Sent via LuaSocket:', resp_or_err); return true end
    -- fallback to curl if available
    local ok2, resp2 = post_via_curl(url, body)
    if ok2 then print('Sent via curl'); return true end
    print('Failed to send:', resp_or_err, resp2)
    print('Make sure PC_IP is set and your phone can reach the PC on the network and port')
    return false
end

-- Example usage
local snapshot = {
    time = os.date('%Y-%m-%d %H:%M:%S'),
    player = { name = 'PhonePlayer', level = 20 },
    notes = 'Example from phone client'
}

send(snapshot, 'phone_snapshot')

-- Send a raw JSON string as the POST body (useful for lines already encoded as JSON in a JSONL file)
local function send_raw_json(raw_json)
    if type(raw_json) ~= 'string' then raw_json = tostring(raw_json) end
    local url = string.format('http://%s:%d%s', PC_IP, PC_PORT, PATH)
    local ok, resp_or_err = post_via_luasocket(url, raw_json)
    if ok then print('Sent raw via LuaSocket'); return true end
    local ok2, resp2 = post_via_curl(url, raw_json)
    if ok2 then print('Sent raw via curl'); return true end
    print('Failed to send raw JSON:', resp_or_err, resp2)
    return false
end

-- Cross-platform sleep helper (uses ping on Windows, sleep on POSIX)
local function sleep_seconds(sec)
    sec = tonumber(sec) or 1
    -- Prefer socket.sleep if available (more portable in Lua environments)
    local ok_sock, sock = pcall(require, 'socket')
    if ok_sock and sock and type(sock.sleep) == 'function' then
        sock.sleep(sec)
        return
    end
    -- Fallback to os.execute if available
    if type(os) == 'table' and type(os.execute) == 'function' then
        -- try POSIX sleep
        local ok, _ = pcall(function() os.execute('sleep ' .. tonumber(sec)) end)
        if ok then return end
        -- Windows ping fallback
        local ok2, _ = pcall(function()
            local cmd = string.format('ping -n %d 127.0.0.1 >NUL', math.max(1, math.floor(sec) + 1))
            os.execute(cmd)
        end)
        if ok2 then return end
    end
    -- Busy-wait as last resort
    local t0 = os.clock()
    while os.clock() - t0 < sec do end
end

-- Tail a JSONL file and auto-send new lines to the PC server.
-- path: path to the JSONL file (e.g. 'game data/roblox_console.jsonl')
-- interval: polling interval in seconds (default 2)
local function tail_and_send(path, interval)
    interval = tonumber(interval) or 2
    local last_pos = 0
    while true do
        local fh = io.open(path, 'rb')
        if fh then
            local ok, size = pcall(function() return fh:seek('end') end)
            size = size or 0
            if size < last_pos then
                -- file was truncated/rotated, reset
                last_pos = 0
            end
            fh:seek('set', last_pos)
            -- iterate new lines from the file directly to avoid pattern escaping issues
            for line in fh:lines() do
                local l = line:gsub('\r$', '')
                if l:match('%S') then
                    local ok_send, err = pcall(send_raw_json, l)
                    if not ok_send then
                        print('Error sending line:', err)
                    end
                end
            end
            -- update last_pos to current end
            local newpos = fh:seek()
            if newpos then last_pos = newpos end
            fh:close()
        end
        sleep_seconds(interval)
    end
end

-- Export convenience functions by returning a table if running as a module, else leave local functions accessible.
-- Example (uncomment to run on a phone executor):
-- tail_and_send('game data/roblox_console.jsonl', 2)
local M = {}
M.send = send
M.send_raw_json = send_raw_json
M.tail_and_send = tail_and_send
M.configure = function(opts)
    if type(opts) ~= 'table' then return end
    PC_IP = opts.ip or PC_IP
    PC_PORT = opts.port or PC_PORT
    PATH = opts.path or PATH
end

-- Always return the module table so requiring this file works predictably.
return M
