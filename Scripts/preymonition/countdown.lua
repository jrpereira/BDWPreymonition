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
local Controller=require('preymonition.controller')
local Render=require('preymonition.countdown_render')
local Widgets=require('preymonition.widgets')
local Placement=require('preymonition.placement')

local OPEN_BEFORE=0.18
local LEAD,FALLBACK=0.3,Controller.FALLBACK
local WINDOW=1
local PREVIEW_LEAD,PREVIEW_WINDOW=0.7,0.5
-- While the game is paused its clock stands still and nothing on screen changes:
-- the count looks again every PAUSED_FRAMES frames rather than every frame.
local PAUSED_FRAMES=5

local records={}
-- Whether combat is on: requests arrive only while it is.
local active=false
local M={}

local log=Controller.silentLog()
function M.setLog(logger) log=logger end

-- Failures are logged once per kind; repeats are counted when combat ends.
local fail,reportFailures=Controller.failures('countdown ',function() return log end)

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
    -- Tenths, rounded up: 0.0 shows only once the count has run out. The text is
    -- formatted again only when they change.
    local tenths=math.ceil(remaining*10-1e-9)
    if record.tenths~=tenths then
        record.tenths,record.text=tenths,string.format('%d.%ds',tenths//10,tenths%10)
    end
    local fraction=record.count>0 and remaining/record.count or 0
    return {text=record.text,fraction=fraction},remaining>0
end

local function clear(record)
    record.source,record.direction,record.paths,record.started,record.opened,record.hitEnd=nil,nil,nil,nil,nil,nil
end

-- The attack's hit window from its attacker, when MCT names one and the game has it.
local function hitWindowOf(event)
    if not event.stub then return nil end
    local ok,from,to=pcall(Combat.hitWindow,event.stub)
    if not ok then fail('hit window',from) return nil end
    return from,to
end

local pump
-- Draws a record now, hud being its live HUD (looked up when not given); asks for
-- the next frame while its view still changes. A request always draws.
local function render(record,hud)
    hud=hud or Render.root(record.ui)
    if not hud then return end
    -- Game time, or real time for a preview.
    local now=Render.now(hud,record.preview)
    local view,moving=M.view(record,now)
    Render.show(record.ui,view)
    record.drawn=now
    if moving then pump(record,1) end
end

-- One frame: one lookup of the HUD and the clock. While the clock stands still
-- (paused) nothing is drawn and the next look waits PAUSED_FRAMES frames.
local function step(record)
    local hud=Render.root(record.ui)
    if not hud then return end
    if Render.now(hud,record.preview)==record.drawn then
        pump(record,PAUSED_FRAMES)
        return
    end
    render(record,hud)
end

function pump(record,frames)
    if record.scheduled then return end
    record.scheduled=true
    local ok,why=pcall(Controller.later,record.onFrame,frames)
    if not ok then record.scheduled=false; fail('schedule',why) end
end

-- The records an event reaches, each with its live HUD. A preview event (ModCore
-- Templates' live preview in the mod menu, the menu's widget as its indicator)
-- reaches only the preview records, a game event only the others in the
-- indicator's world.
local function each(event,callback)
    local preview=event.preview==true
    for _,record in ipairs(records) do
        if record.preview==preview then
            local hud=Render.root(record.ui)
            if hud and (preview or Widgets.sameWorld(hud,event.indicator)) then callback(record,hud) end
        end
    end
end

local handlers={}

-- An attack shows: its count starts. The game's arrow sometimes shows twice for
-- one attack, on the same indicator or another in its direction; the count
-- already running for it carries on (preymonition.controller's joins).
function handlers.arrow(event)
    each(event,function(record,hud)
        if Controller.joins(record,event) then return end
        Controller.open(record,event)
        record.opened=nil
        local now=Render.now(hud,record.preview)
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
        render(record,hud)
    end)
end

-- Its Perfect Opportunity window opened: NOW, once per attack.
function handlers.critical(event)
    each(event,function(record,hud)
        if Controller.joins(record,event) then
            if record.opened then return end
        else
            Controller.open(record,event)
            local _,to=hitWindowOf(event)
            record.hitEnd=to
        end
        local now=Render.now(hud,record.preview)
        record.opened=now
        -- The red bar runs to the hit window's end, or over WINDOW without one
        -- (PREVIEW_WINDOW in a preview).
        record.window=record.hitEnd and record.hitEnd>now and record.hitEnd-now
            or (record.preview and PREVIEW_WINDOW or WINDOW)
        render(record,hud)
    end)
end

-- The count goes once every indicator of its attack resolved.
function handlers.resolve(event)
    each(event,function(record,hud)
        if Controller.resolves(record,event.path) then clear(record); render(record,hud) end
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
    local multiplier=Controller.pace(Render.context(record.ui),log)
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
    Combat.forgetStubs()
    for _,record in ipairs(records) do
        local hud=not record.preview and Render.root(record.ui)
        if hud then
            clear(record)
            local ok,why=pcall(render,record,hud)
            if not ok then fail('combat end',why) end
        end
    end
    reportFailures()
end

-- A font size that could not be set is warned about once.
local fontWarned=false

function M.attach(hud,layer,params,onCleanup)
    local settings=params.settings or {}
    local record={lead=LEAD*FALLBACK,count=LEAD*FALLBACK,window=WINDOW,preview=params.preview==true}
    record.onFrame=function()
        record.scheduled=false
        if record.detached then return end
        local ok,why=pcall(step,record)
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
    if record.ui.fontFailed and not fontWarned then
        fontWarned=true
        log.warn('countdown font size not set; the time keeps the default size: ',record.ui.fontFailed)
    end
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
