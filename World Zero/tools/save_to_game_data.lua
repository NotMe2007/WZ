-- This file is now plain Lua without Markdown fences.

local M = {}
local DATA_DIR = "game data"

local function is_windows()
    return package.config:sub(1,1) == "\\"
end

local function ensure_dir(dir)
    -- Try to create the directory in a cross-platform way.
    if is_windows() then
        -- Windows: use mkdir if not exists
        os.execute(('if not exist "%s" mkdir "%s"'):format(dir, dir))
    else
        os.execute(('mkdir -p "%s"'):format(dir))
    end
end

local function sanitize_filename(name)
    -- Replace dangerous characters with underscore
    if not name then return "data" end
    return tostring(name):gsub("[^%w%._-]", "_")
end

local function is_array(tbl)
    local i = 0
    for _ in pairs(tbl) do
        i = i + 1
        if tbl[i] == nil then return false end
    end
    return true
end

-- Basic JSON encoder (handles numbers, strings, booleans, nil, tables without cycles)
local function json_encode(value)
    local t = type(value)
    if t == 'nil' then return 'null' end
    if t == 'boolean' then return tostring(value) end
    if t == 'number' then return tostring(value) end
    if t == 'string' then
        -- escape basic characters
        local s = value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r')
        return '"'..s..'"'
    end
    if t == 'table' then
        -- detect array-like
        if is_array(value) then
            local parts = {}
            for i=1,#value do parts[#parts+1] = json_encode(value[i]) end
            return '['..table.concat(parts, ',')..']'
        else
            local parts = {}
            for k,v in pairs(value) do
                parts[#parts+1] = json_encode(tostring(k)) .. ':' .. json_encode(v)
            end
            return '{'..table.concat(parts, ',')..'}'
        end
    end
    -- fallback to stringification
    return json_encode(tostring(value))
end

local function write_file(path, data)
    local fh, err = io.open(path, 'wb')
    if not fh then return false, err end
    fh:write(data)
    fh:close()
    return true
end

-- Public API
function M.ensure()
    ensure_dir(DATA_DIR)
end

function M.save_text(name, text)
    M.ensure()
    local fname = sanitize_filename(name) .. '.txt'
    local path = DATA_DIR .. '/' .. fname
    return write_file(path, tostring(text))
end

function M.save_table(name, tbl)
    M.ensure()
    local fname = sanitize_filename(name) .. '.json'
    local path = DATA_DIR .. '/' .. fname
    local ok, err = write_file(path, json_encode(tbl))
    return ok, err
end

function M.append_log(name, line)
    M.ensure()
    local fname = sanitize_filename(name) .. '.log'
    local path = DATA_DIR .. '/' .. fname
    local fh, err = io.open(path, 'ab')
    if not fh then return false, err end
    fh:write(tostring(line) .. '\n')
    fh:close()
    return true
end

-- convenience function to save generic value
function M.save_value(name, value)
    if type(value) == 'table' then
        return M.save_table(name, value)
    else
        return M.save_text(name, tostring(value))
    end
end

-- Example: automatically save runtime info
function M.save_runtime_snapshot(name)
    local cwd = nil
    pcall(function()
        local handle = io.popen(is_windows() and 'cd' or 'pwd')
        if handle then cwd = handle:read('*l'); handle:close() end
    end)
    local info = {
        time = os.date('%Y-%m-%d %H:%M:%S'),
        lua_version = _VERSION,
        cwd = cwd or ''
    }
    return M.save_table(name or 'snapshot', info)
end

-- Save a Roblox console message record.
-- record: table with keys { time, message, messageType, stackTrace, source }
function M.save_roblox_message(record)
    M.ensure()
    record = record or {}
    record.time = record.time or os.date('%Y-%m-%d %H:%M:%S')
    local json = json_encode(record)
    -- Append to a JSONL file (one JSON per line) for easier post-processing
    local path = DATA_DIR .. '/roblox_console.jsonl'
    local fh, err = io.open(path, 'ab')
    if not fh then
        -- fallback: save as plain log
        return M.append_log('roblox_console', (record.message or '')..' | '..tostring(record.messageType or ''))
    end
    fh:write(json .. '\n')
    fh:close()
    -- also append a human-readable line to a log
    local summary = string.format('[%s] [%s] %s', record.time, tostring(record.messageType or 'INFO'), tostring(record.message or ''))
    M.append_log('roblox_console', summary)
    return true
end

-- Helper to prepare an error record quickly
function M.make_roblox_record(message, messageType, stackTrace, source)
    return {
        time = os.date('%Y-%m-%d %H:%M:%S'),
        message = tostring(message or ''),
        messageType = tostring(messageType or ''),
        stackTrace = tostring(stackTrace or ''),
        source = tostring(source or '')
    }
end

-- Example usage for a phone-side script:
-- Hook LogService.MessageOut/MessagePosted, build a record and send it to PC (client_send.lua)
-- local record = saver.make_roblox_record(message, messageType, stackTrace, script and script:GetFullName())
-- saver.save_roblox_message(record)

return M
