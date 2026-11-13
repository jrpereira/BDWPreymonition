-- Counts down to an attack's parry window: takes MCT's MC_NPCAttackIndicator
-- requests and times them; preymonition.countdown_render draws the result. Times
-- are game time, which stops while the game is paused.
--
-- When MCT names the attacker (the event's stub), the game already knows the
-- attack's hit window as its arrow shows; the parry window opened OPEN_BEFORE
-- seconds before the hit window started (measured 2026-11-12, five attacks, within
-- 0.05 s). The count runs to that moment, and the red bar to the hit window's end.
-- Without a hit window the count is an estimate: LEAD seconds times the game's
-- parry window multiplier, read when combat starts (0.42 s at 1.4; single attacks
-- ranged from 0.02 to 0.81 s), and the red bar runs over WINDOW seconds.
--
-- Either way NOW comes only from the game's own parry window, so it is never
-- early: a window opening sooner cuts the count short, and a count that runs out
-- first holds at 0.0 until it opens. Everything goes as soon as the attack resolves.
local Combat=require('preymonition.combat')
local Render=require('preymonition.countdown_render')

local OPEN_BEFORE=0.18
local LEAD,FALLBACK=0.3,1.4
local WINDOW=1
local FRAME_MS=16

local records={}
-- Whether combat is on: requests arrive only while it is.
local active=false
local M={LEAD=LEAD,WINDOW=WINDOW,OPEN_BEFORE=OPEN_BEFORE}

local function silent() end
local log={enabled=function() return false end}
for _,name in ipairs({'trace','debug','info','warn','error','critical'}) do log[name]=silent end
function M.setLog(logger) log=logger end

-- Failures are logged once per kind; repeats are counted when combat ends.
local failures={}
local function fail(kind,why)
    local count=failures[kind]
    failures[kind]=(count or 0)+1
    if not count then log.error('countdown ',kind,' failed: ',why) end
end

-- What a record shows at a time: nil when no attack is counted; else the text,
-- the remaining share of the bar, whether it is the parry window, and whether it
-- still changes.
function M.view(record,now)
    if record.opened then
        local fraction=math.max(0,1-(now-record.opened)/record.window)
        return {text='NOW',fraction=fraction,now=true},fraction>0
    end
    if not record.started then return nil,false end
    local remaining=math.max(0,record.count-(now-record.started))
    -- Tenths, rounded up: 0.0 shows only once the count has run out.
    local tenths=math.ceil(remaining*10-1e-9)
    local fraction=record.count>0 and remaining/record.count or 0
    return {text=string.format('%d.%ds',tenths//10,tenths%10),fraction=fraction},remaining>0
end

local function clear(record)
    record.source,record.direction,record.started,record.opened,record.hitEnd=nil,nil,nil,nil,nil
end

-- The attack's hit window from its attacker, when MCT names one and the game has it.
local function hitWindowOf(event)
    if not event.stub then return nil end
    local ok,from,to=pcall(Combat.hitWindow,event.stub)
    if not ok then fail('hit window',from) return nil end
    return from,to
end

-- Next frame when the engine tick is hooked; ExecuteWithDelay's timer is coarser.
local function later(callback)
    if rawget(_G,'EngineTickAvailable')==true and type(rawget(_G,'ExecuteInGameThreadAfterFrames'))=='function' then
        ExecuteInGameThreadAfterFrames(1,callback)
    else
        ExecuteWithDelay(FRAME_MS,function() ExecuteInGameThread(callback) end)
    end
end

local pump
-- Draws a record now; asks for the next frame while its view still changes.
local function render(record)
    if not Render.valid(record.ui) then return end
    local view,moving=M.view(record,Render.now(record.ui))
    Render.show(record.ui,view)
    if moving then pump(record) end
end

function pump(record)
    if record.scheduled then return end
    record.scheduled=true
    local ok,why=pcall(later,record.onFrame)
    if not ok then record.scheduled=false; fail('schedule',why) end
end

-- The records in the indicator's world.
local function each(indicator,callback)
    for _,record in ipairs(records) do
        if Render.valid(record.ui) and Render.sameWorld(record.ui,indicator) then
            callback(record)
        end
    end
end

local handlers={}

-- An attack shows: its count starts. The game's arrow sometimes shows twice for
-- one attack; the count already running for it carries on.
function handlers.arrow(event)
    each(event.indicator,function(record)
        if record.source==event.path and record.direction==event.direction then return end
        record.source,record.direction,record.opened=event.path,event.direction,nil
        local now=Render.now(record.ui)
        record.started=now
        local from,to=hitWindowOf(event)
        if from and to>now then
            record.count,record.hitEnd=math.max(0,from-OPEN_BEFORE-now),to
            log.debug('counting ',string.format('%.2f',record.count),' s to the parry window from the hit window')
        else
            record.count,record.hitEnd=record.lead,nil
            log.debug('counting ',string.format('%.2f',record.count),' s, estimated: ',
                event.stub and 'no hit window' or 'no attacker')
        end
        render(record)
    end)
end

-- Its parry window opened: NOW, once per attack.
function handlers.critical(event)
    each(event.indicator,function(record)
        if record.opened and record.source==event.path and record.direction==event.direction then return end
        if record.source~=event.path or record.direction~=event.direction then
            local _,to=hitWindowOf(event)
            record.hitEnd=to
        end
        record.source,record.direction=event.path,event.direction
        local now=Render.now(record.ui)
        record.opened=now
        -- The red bar runs to the hit window's end, or over WINDOW without one.
        record.window=record.hitEnd and record.hitEnd>now and record.hitEnd-now or WINDOW
        render(record)
    end)
end

function handlers.resolve(event)
    each(event.indicator,function(record)
        if record.source==event.path then clear(record); render(record) end
    end)
end

-- One MC_NPCAttackIndicator request.
function M.update(event)
    if not (active and next(records)) then return end
    local handler=handlers[event.kind]
    if not handler then return end
    local ok,why=pcall(handler,event)
    if not ok then fail(event.kind,why) end
end

-- Combat started: the count takes the current difficulty's parry window.
function M.wake()
    if active then return end
    active=true
    for _,record in ipairs(records) do
        if Render.valid(record.ui) then
            local read,multiplier=pcall(Combat.parryWindow,Render.context(record.ui))
            if not (read and multiplier) then
                log.debug('parry window unreadable',read and '' or ': '..tostring(multiplier),'; assuming ',FALLBACK)
                multiplier=FALLBACK
            end
            record.lead=LEAD*multiplier
            log.debug('parry window ',multiplier,'; counting ',string.format('%.2f',record.lead),' s')
        end
    end
end

-- Combat ended: the countdown goes.
function M.sleep()
    if not active then return end
    active=false
    for _,record in ipairs(records) do
        if Render.valid(record.ui) then
            clear(record)
            local ok,why=pcall(render,record)
            if not ok then fail('combat end',why) end
        end
    end
    for kind,count in pairs(failures) do
        if count>1 then log.warn('countdown ',kind,' failed ',count-1,' more times') end
    end
    failures={}
end

function M.attach(hud,layer,params,onCleanup)
    local settings=params.settings or {}
    local record={lead=LEAD*FALLBACK,count=LEAD*FALLBACK,window=WINDOW}
    record.onFrame=function()
        record.scheduled=false
        if record.detached then return end
        local ok,why=pcall(render,record)
        if not ok then fail('frame',why) end
    end
    onCleanup(function()
        record.detached=true
        for index,current in ipairs(records) do
            if current==record then table.remove(records,index); break end
        end
        if record.ui then Render.destroy(record.ui) end
        log.debug('countdown detached; ',#records,' attached')
        return true
    end)
    local position=settings.Position or 1
    record.ui=Render.build(hud,layer,assert(params.screen,'screen unavailable'),position)
    records[#records+1]=record
    log.info('countdown attached, position ',position)
end

return M
