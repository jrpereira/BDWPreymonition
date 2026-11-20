-- Counts down to an attack's Perfect Opportunity window: takes MCT's MC_NPCAttackIndicator
-- requests and times them; preymonition.countdown_render draws the result. Times
-- are game time, which stops while the game is paused.
--
-- When MCT names the attacker (the event's stub), the game already knows the
-- attack's hit window as its arrow shows; the Perfect Opportunity window opened OPEN_BEFORE
-- seconds before the hit window started (measured 2026-11-12, five attacks, within
-- 0.05 s). The count runs to that moment, and the red bar to the hit window's end.
-- Without a hit window the count is an estimate: LEAD seconds times the game's
-- parry window multiplier, read when combat starts (0.42 s at 1.4; single attacks
-- ranged from 0.02 to 0.81 s), and the red bar runs over WINDOW seconds.
--
-- Either way NOW comes only from the game's own Perfect Opportunity window, so it is never
-- early: a window opening sooner cuts the count short, and a count that runs out
-- first holds at 0.0 until it opens. Everything goes as soon as the attack resolves.
--
-- In ModCore Templates' live preview (the mod menu) there is no attack to time and
-- the game may be paused: a preview countdown runs on real time and counts
-- PREVIEW_LEAD, the gap between an arrow and its critical in the npc.attacks
-- preview script, so it reaches 0.0 as NOW comes, and its red bar runs over
-- PREVIEW_WINDOW, the time from there to the attack's resolve.
local Combat=require('preymonition.combat')
local Render=require('preymonition.countdown_render')
local Placement=require('preymonition.placement')

local OPEN_BEFORE=0.18
local LEAD,FALLBACK=0.3,1.4
local WINDOW=1
local PREVIEW_LEAD,PREVIEW_WINDOW=0.7,0.5
local FRAME_MS=16

local records={}
-- Whether combat is on: requests arrive only while it is.
local active=false
local M={LEAD=LEAD,WINDOW=WINDOW,OPEN_BEFORE=OPEN_BEFORE,PREVIEW_LEAD=PREVIEW_LEAD,PREVIEW_WINDOW=PREVIEW_WINDOW}

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
-- the remaining share of the bar, whether it is the Perfect Opportunity window, and whether it
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
-- The preview steps by frames too: the engine ticks with the mod menu open (checked
-- live, 2026-11-16), and an ExecuteWithDelay every frame for minutes crashed the game.
-- timer is ignored.
local function later(callback,timer)
    if rawget(_G,'EngineTickAvailable')==true and type(rawget(_G,'ExecuteInGameThreadAfterFrames'))=='function' then
        ExecuteInGameThreadAfterFrames(1,callback)
    else
        -- On the game thread: ExecuteWithDelay runs its callback on UE4SS's async thread,
        -- in this mod's Lua state while the game thread may use it.
        if type(rawget(_G,'ExecuteInGameThreadWithDelay'))=='function' then
            ExecuteInGameThreadWithDelay(math.max(1,math.floor(FRAME_MS)),callback)
        else
            ExecuteWithDelay(FRAME_MS,function() ExecuteInGameThread(callback) end)
        end
    end
end

-- A record's clock: game time, or real time for a preview.
local function clock(record)
    return Render.now(record.ui,record.preview)
end

local pump
-- Draws a record now; asks for the next frame while its view still changes.
local function render(record)
    if not Render.valid(record.ui) then return end
    local view,moving=M.view(record,clock(record))
    Render.show(record.ui,view)
    if moving then pump(record) end
end

function pump(record)
    if record.scheduled then return end
    record.scheduled=true
    local ok,why=pcall(later,record.onFrame,record.preview)
    if not ok then record.scheduled=false; fail('schedule',why) end
end

-- The records an event reaches. A preview event (ModCore Templates' live preview
-- in the mod menu, the menu's widget as its indicator) reaches only the preview
-- records, a game event only the others in the indicator's world.
local function each(event,callback)
    local preview=event.preview==true
    for _,record in ipairs(records) do
        if record.preview==preview and Render.valid(record.ui)
            and (preview or Render.sameWorld(record.ui,event.indicator)) then
            callback(record)
        end
    end
end

local handlers={}

-- An attack shows: its count starts. The game's arrow sometimes shows twice for
-- one attack; the count already running for it carries on.
function handlers.arrow(event)
    each(event,function(record)
        if record.source==event.path and record.direction==event.direction then return end
        record.source,record.direction,record.opened=event.path,event.direction,nil
        local now=clock(record)
        record.started=now
        local from,to=hitWindowOf(event)
        if record.preview then
            record.count,record.hitEnd=PREVIEW_LEAD,nil
        elseif from and to>now then
            record.count,record.hitEnd=math.max(0,from-OPEN_BEFORE-now),to
            log.debug('counting ',string.format('%.2f',record.count),' s to the Perfect Opportunity window from the hit window')
        else
            record.count,record.hitEnd=record.lead,nil
            log.debug('counting ',string.format('%.2f',record.count),' s, estimated: ',
                event.stub and 'no hit window' or 'no attacker')
        end
        render(record)
    end)
end

-- Its Perfect Opportunity window opened: NOW, once per attack.
function handlers.critical(event)
    each(event,function(record)
        if record.opened and record.source==event.path and record.direction==event.direction then return end
        if record.source~=event.path or record.direction~=event.direction then
            local _,to=hitWindowOf(event)
            record.hitEnd=to
        end
        record.source,record.direction=event.path,event.direction
        local now=clock(record)
        record.opened=now
        -- The red bar runs to the hit window's end, or over WINDOW without one
        -- (PREVIEW_WINDOW in a preview).
        record.window=record.hitEnd and record.hitEnd>now and record.hitEnd-now
            or (record.preview and PREVIEW_WINDOW or WINDOW)
        render(record)
    end)
end

function handlers.resolve(event)
    each(event,function(record)
        if record.source==event.path then clear(record); render(record) end
    end)
end

-- One MC_NPCAttackIndicator request.
function M.update(event)
    if not next(records) or not (active or event.preview) then return end
    local handler=handlers[event.kind]
    if not handler then return end
    local ok,why=pcall(handler,event)
    if not ok then fail(event.kind,why) end
end

-- A record takes the current difficulty's parry window multiplier for its count.
local function pace(record)
    local read,multiplier=pcall(Combat.parryWindow,Render.context(record.ui))
    if not (read and multiplier) then
        log.debug('parry window unreadable',read and '' or ': '..tostring(multiplier),'; assuming ',FALLBACK)
        multiplier=FALLBACK
    end
    record.lead=LEAD*multiplier
    log.debug('parry window ',multiplier,'; counting ',string.format('%.2f',record.lead),' s')
end

-- Combat started: every count takes the current difficulty's pace. A preview's
-- keeps its own timing.
function M.wake()
    if active then return end
    active=true
    for _,record in ipairs(records) do
        if not record.preview and Render.valid(record.ui) then pace(record) end
    end
end

-- Combat ended: the countdown goes, but the preview's.
function M.sleep()
    if not active then return end
    active=false
    for _,record in ipairs(records) do
        if not record.preview and Render.valid(record.ui) then
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
    local record={lead=LEAD*FALLBACK,count=LEAD*FALLBACK,window=WINDOW,preview=params.preview==true}
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
    local position=Placement.position(settings.Position)
    record.ui=Render.build(hud,layer,assert(params.screen,'screen unavailable'),position)
    records[#records+1]=record
    -- Attached in combat (enabled or applied mid-fight, or woken before it attached):
    -- it takes the combat's pace as wake would give it.
    if active and not record.preview then
        local ok,why=pcall(pace,record)
        if not ok then fail('pace',why) end
    end
    log.info(record.preview and 'preview countdown attached, position ' or 'countdown attached, position ',position)
end

return M
