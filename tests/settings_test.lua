local handlers, shared, queue = {}, {}, {}
ModRef = {
    GetSharedVariable = function(_, key) return shared[key] end,
    SetSharedVariable = function(_, key, value) shared[key] = value end,
}
RegisterConsoleCommandHandler = function(name, callback) handlers[name] = callback end
ExecuteInGameThread = function(callback) queue[#queue+1] = callback end
local config_text
local original_open = io.open
io.open = function(path, mode)
    if path:match('/config%.ini$') then
        if config_text == nil then return nil end
        return { read = function() return config_text end, close = function() end }
    end
    return original_open(path, mode)
end
local runtime = dofile('Scripts/main.lua')
assert(runtime.settings.Enabled == 1 and runtime.settings.Debug == 0)
local command, handler = next(handlers)
assert(command and not next(handlers, command), 'exactly one subscription')
local function notify(revision)
    shared[command..'.data'] = revision..'\n456e61626c6564 1 0\n4465627567 0 1\n'
    assert(handler())
end
config_text = '[General]\nEnabled=0\nDebug=1\n'
assert(runtime.settings.Enabled == 1, 'preview/file edit must not affect runtime until Apply')
notify(1); notify(2)
assert(#queue == 1, 'coalesce pending Apply work')
queue[1](); queue = {}
assert(runtime.settings.Enabled == 0 and runtime.settings.Debug == 1)
assert(runtime.revision == 2)
notify(2); assert(#queue == 0, 'duplicate revision ignored')
notify(3); queue[1](); queue = {}
assert(runtime.revision == 2, 'unchanged config no-op')
config_text = '[General]\nEnabled=2\nDebug=0\n'
notify(4); queue[1](); queue = {}
assert(runtime.settings.Enabled == 0 and runtime.settings.Debug == 1, 'invalid Apply retains state')
io.open = original_open
local Config = dofile('Scripts/config.lua')
assert(not pcall(Config.parse, '[Other]\nEnabled=1'))
assert(Config.parse('[General]\nEnabled=0 ; comment\nDebug=0').Enabled == 0)
print('PASS: startup, subscription, Apply, coalescing, unchanged values, invalid config')
