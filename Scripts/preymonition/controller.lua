-- What every template's controller does alike: a log that stays silent until the
-- template's own one arrives, failures logged once per kind, one attack across
-- indicators, deferred frames and the parry window's pace.
local Combat=require('preymonition.combat')

local FRAME_MS=16
-- The parry window multiplier assumed when the game's cannot be read: the second
-- difficulty's.
local M={FALLBACK=1.4}

local function silent() end
-- A log that writes nothing, replaced by the template's leveled logger.
function M.silentLog()
    local log={enabled=function() return false end}
    for _,name in ipairs({'trace','debug','info','warn','error','critical'}) do log[name]=silent end
    return log
end

-- Failures are logged once per kind; repeats are counted and reported when combat
-- ends, so a lasting fault never writes the log on every call. prefix starts each
-- message; current returns the template's log at the time. Returns fail(kind,why)
-- and report().
function M.failures(prefix,current)
    local counts={}
    local function fail(kind,why)
        local count=counts[kind]
        counts[kind]=(count or 0)+1
        if not count then current().error(prefix..tostring(kind),' failed: ',why) end
    end
    local function report()
        for kind,count in pairs(counts) do
            if count>1 then current().warn(prefix..tostring(kind),' failed ',count-1,' more times') end
        end
        counts={}
    end
    return fail,report
end

-- Whether deferred work steps by engine frames: the engine tick is hooked.
function M.frames()
    return rawget(_G,'EngineTickAvailable')==true and type(rawget(_G,'ExecuteInGameThreadAfterFrames'))=='function'
end

-- Runs callback after frames frames (1 by default) on the game thread;
-- ExecuteWithDelay's timer is coarser. A preview steps by frames too: the engine
-- ticks with the mod menu open (checked live, 2026-11-16), and an ExecuteWithDelay
-- every frame for minutes left UE4SS with dead callbacks and crashed the game.
function M.later(callback,frames)
    frames=frames or 1
    if M.frames() then
        ExecuteInGameThreadAfterFrames(frames,callback)
    elseif type(rawget(_G,'ExecuteInGameThreadWithDelay'))=='function' then
        -- On the game thread: ExecuteWithDelay runs its callback on UE4SS's async
        -- thread, in this mod's Lua state while the game thread may use it.
        ExecuteInGameThreadWithDelay(FRAME_MS*frames,callback)
    else
        ExecuteWithDelay(FRAME_MS*frames,function() ExecuteInGameThread(callback) end)
    end
end

-- One attack across indicators. The game sometimes reports one attack on two
-- indicators in the same direction: a report in the direction of the attack a
-- record follows counts as that attack, whatever its indicator, and the attack
-- lasts until every one of them resolves. A record keeps the attack's first
-- indicator as source, its direction and the paths of all its indicators.

-- Whether event is the record's open attack; its indicator is counted when it is.
function M.joins(record,event)
    if not (record.source and record.direction==event.direction) then return false end
    record.paths[event.path]=true
    return true
end

-- The record follows event's attack from now on.
function M.open(record,event)
    record.source,record.direction,record.paths=event.path,event.direction,{[event.path]=true}
end

-- An indicator resolved: whether it was the last of the record's attack.
function M.resolves(record,path)
    local paths=record.paths
    if not (paths and paths[path]) then return false end
    paths[path]=nil
    return next(paths)==nil
end

-- The current difficulty's parry window multiplier, read through context (any
-- live object in the player's world), or FALLBACK when it cannot be read.
function M.pace(context,log)
    local read,multiplier=pcall(Combat.parryWindow,context)
    if read and multiplier then return multiplier end
    log.debug('parry window unreadable',read and '' or ': '..tostring(multiplier),'; assuming ',M.FALLBACK)
    return M.FALLBACK
end

return M
