-- Premonition: directional attack cue HUD for The Blood of Dawnwalker.
local VERSION = "0.1.1"
local function log(message) print('[Premonition] '..tostring(message)..'\n') end
local source = debug.getinfo(1, 'S').source:gsub('^@', '')
local scripts = assert(source:match('^(.*)[/\\][^/\\]+$'), 'Cannot resolve Scripts folder')
local moddir = scripts == 'Scripts' and '.' or assert(scripts:match('^(.*)[/\\]Scripts$'), 'Unexpected mod layout')
local config_path = moddir..'/config.ini'
local function read_config()
    local file = io.open(config_path, 'rb')
    if not file then return nil end
    local text = file:read('*a'); file:close(); return text
end
local Config = dofile(scripts..'/config.lua')
local runtime = dofile(scripts..'/runtime.lua')(log, scripts)
local previous = rawget(_G, 'PremonitionRuntime')
if previous and type(previous.stop) == 'function' then
    local stopped, reason = pcall(function() previous:stop() end)
    if not stopped then error('Cannot replace the previous Premonition runtime: ' .. tostring(reason)) end
end
_G.PremonitionRuntime = runtime
local ok, initial = pcall(Config.parse, read_config())
if not ok then log('Invalid startup config; using defaults: '..tostring(initial)); initial = Config.parse(nil) end
runtime:apply(initial)

local pending = false
local subscribed, failure = pcall(function()
    assert(type(ExecuteInGameThread) == 'function', 'UE4SS game-thread dispatch unavailable')
    local api = dofile(scripts..'/dmm_api.lua')
    api.subscribe('Premonition', function()
        if pending then return end
        pending = true
        local queued, why = pcall(ExecuteInGameThread, function()
            pending = false
            local applied, error_message = pcall(function()
                local text = assert(read_config(), 'Committed config unavailable')
                runtime:apply(Config.parse(text))
            end)
            if not applied then log('Apply failed; previous settings retained: '..tostring(error_message)) end
        end)
        if not queued then pending = false; log('Apply dispatch failed: '..tostring(why)) end
    end)
end)
if not subscribed then log('DMM Apply subscription unavailable; restart after saving settings: '..tostring(failure)) end
log('Loaded v' .. VERSION .. '. Directional attack cue hooks are ' ..
    (runtime.feature.active and 'active.' or 'inactive; review startup errors.'))
return runtime
