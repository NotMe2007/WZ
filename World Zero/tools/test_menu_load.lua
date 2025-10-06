-- Smoke test for Features/Menu.lua M.load() merging persisted settings
local function ensure_dir(dir)
    if package.config:sub(1,1) == "\\" then
        os.execute(('if not exist "%s" mkdir "%s"'):format(dir, dir))
    else
        os.execute(('mkdir -p "%s"'):format(dir))
    end
end

local dir = 'game data'
ensure_dir(dir)
local path = dir .. '/settings.json'

local content = [[
{
  AutoUpgrade = false,
  Settings = {
    Dungeon = {
      Enabled = true,
      AutoSelectHighest = true
    }
  }
}
]]

local fh, err = io.open(path, 'wb')
if not fh then
    print('Cannot write settings file:', err)
    os.exit(2)
end
fh:write(content)
fh:close()

-- Load the module (it will attempt to pcall(M.load) at the end)
local ok, M = pcall(function() return dofile('Features/Menu.lua') end)
if not ok or type(M) ~= 'table' then
    print('Failed to load Menu module:', M)
    os.exit(2)
end

local passed = true
local function expect(path, expected)
    local got = M.get(path)
    if got ~= expected then
        print('FAIL', path, 'expected', tostring(expected), 'got', tostring(got))
        passed = false
    else
        print('OK', path, tostring(got))
    end
end

expect('AutoUpgrade', false)
expect('Settings.Dungeon.Enabled', true)
expect('Settings.Dungeon.AutoSelectHighest', true)

if passed then
    print('SMOKE TEST PASSED')
    os.exit(0)
else
    print('SMOKE TEST FAILED')
    os.exit(1)
end
