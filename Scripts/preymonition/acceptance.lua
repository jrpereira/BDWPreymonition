-- Developer aid for the bridge hooks' acceptance run (LEX G3): an
-- acceptance.txt next to mod.json logs every attack the cue detects as a
-- DETECT line, and hooks the indicator's icon change through the event
-- bridge's function hooks, logging each call beside it. Both lines carry the
-- same os.clock and the bridge's frame counter, for work/hooks-acceptance/compare.py.
-- Off without the file; the release path never touches the bridge's hooks.
local Cue=require('preymonition.cue')

local M={}

local TARGET='/Game/_Dawnwalker/UI/_Unified/Combat/WBP_CombatTargetIndicator.WBP_CombatTargetIndicator_C:OnObservedStubIconTypeChanged'

local enabled=false
local handle
local reported

local function hooks()
    local bridge=rawget(_G,'UE4SSLuaEventBridge')
    local ok,api=pcall(function() return bridge.Hooks end)
    return ok and api or nil
end

-- The bridge's frame counter as a line field, or nothing before its first hook.
local function frame()
    local api=hooks()
    local ok,stats=pcall(function() return api.GetStats() end)
    local ticks=ok and type(stats)=='table' and tonumber(stats.ticks)
    return ticks and string.format(' frame=%d',ticks) or ''
end

local function write(line) print(line..'\n') end

-- Whether DETECT lines are written; the session calls detect regardless.
function M.enabled() return enabled end

-- An attack the cue detected, from inside the brush hook that saw it.
function M.detect(kind,path)
    if not enabled or not path then return end
    write(string.format('[Preymonition] DETECT t=%.4f%s kind=%s path=%s',os.clock(),frame(),kind,path))
end

-- The indicator's path as the cue names it: the bridge's path resolved and
-- named again, so both lines pair by the same text.
local function pathOf(call)
    local raw=call.object and call.object.path
    if type(raw)~='string' then return nil end
    local ok,object=pcall(Cue.resolve,raw)
    return ok and object and Cue.path(object) or raw
end

local function onIcon(call)
    local icon=call.params and call.params.IconType
    if type(icon)=='table' then icon=icon.value end
    write(string.format('[hooks] t=%.4f%s phase=%s icon=%s path=%s',os.clock(),frame(),tostring(call.phase),
        tostring(icon),tostring(pathOf(call))))
end

local function hook(log)
    if handle then return end
    local api=hooks()
    if not api then
        if not reported then reported=true; log.warn('acceptance: event bridge hooks unavailable') end
        return
    end
    local ok,result,why=pcall(api.Hook,TARGET,{params={'IconType'},object_paths=true,post=onIcon})
    if ok and result then
        handle=result
        log.info('acceptance: hooked ',TARGET)
    elseif not reported then
        reported=true
        log.warn('acceptance: could not hook ',TARGET,': ',ok and why or result)
    end
end

-- Turns the aid on and hooks the indicator once, on the game thread; a class
-- not loaded yet leaves the hook pending in the bridge, which attaches it when
-- the class loads.
function M.start(log)
    enabled=true
    if handle then return end
    local run=rawget(_G,'ExecuteInGameThread')
    if type(run)=='function' then run(function() hook(log) end) else hook(log) end
end

-- The bridge's counters and the hook's status, at the end of each fight.
function M.report()
    if not enabled then return end
    local api=hooks()
    local ok,stats=pcall(function() return api.GetStats() end)
    if ok and type(stats)=='table' then
        local slots=type(stats.slots)=='table' and (tostring(stats.slots.a)..','..tostring(stats.slots.b)) or 'none'
        write(string.format('[hooks] stats queued=%s high_water=%s rejected=%s delivery=%s ticks=%s entries=%s slots=%s',
            tostring(stats.queued),tostring(stats.high_water),tostring(stats.rejected),tostring(stats.delivery),
            tostring(stats.ticks),tostring(stats.entries),slots))
    end
    if not handle then return end
    local read,status=pcall(function() return handle:Status() end)
    if read and type(status)=='table' then
        write(string.format('[hooks] status state=%s reason=%s calls=%s matched=%s delivered=%s dropped=%s reentries=%s',
            tostring(status.state),tostring(status.reason),tostring(status.calls),tostring(status.matched),
            tostring(status.delivered),tostring(status.dropped),tostring(status.reentries)))
    end
end

return M
