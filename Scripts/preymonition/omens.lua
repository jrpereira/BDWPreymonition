-- Follows MCT's MC_NPCAttackIndicator events with the cue animation of attached HUDs.
local Animation=require('preymonition.omens_animation')
local Combat=require('preymonition.combat')
local Cue=require('preymonition.omens_render')

-- MCT watches the game's combat target indicator and delivers each change as an
-- MC_NPCAttackIndicator update event on the next engine tick, about a frame
-- after the game shows it. MCT wakes the template when combat starts and puts
-- it to sleep when combat ends.
local FRAME_MS=16
-- Direction names for the log, from the indicator's arrow names.
local DIRECTIONS={}
for index,key in ipairs(Cue.ARROWS) do DIRECTIONS[index]=key:match('^(%u%l+)Arrow$'):lower() end

local cues={}
-- Whether combat is on: events arrive only while it is.
local active=false
local M={}

-- Replaced by the template's leveled logger; silent until then.
local function silent() end
local log={enabled=function() return false end}
for _,name in ipairs({'trace','debug','info','warn','error','critical'}) do log[name]=silent end

function M.setLog(logger)
    log=logger
end

-- Next frame when the engine tick is hooked; ExecuteWithDelay's timer is coarser.
local function frames()
    return rawget(_G,'EngineTickAvailable')==true and type(rawget(_G,'ExecuteInGameThreadAfterFrames'))=='function'
end

-- Deferred work guards itself: an animation step stops once its cue is
-- detached. The preview steps by frames too: the engine ticks with the mod menu open
-- (checked live, 2026-11-16), and an ExecuteWithDelay every frame for minutes left
-- UE4SS with dead callbacks and crashed the game. timer is ignored.
local function later(milliseconds,callback,timer)
    if milliseconds<=FRAME_MS and frames() then
        ExecuteInGameThreadAfterFrames(1,callback)
    else
        -- On the game thread: ExecuteWithDelay runs its callback on UE4SS's async thread,
        -- in this mod's Lua state while the game thread may use it.
        if type(rawget(_G,'ExecuteInGameThreadWithDelay'))=='function' then
            ExecuteInGameThreadWithDelay(math.max(1,math.floor(milliseconds)),callback)
        else
            ExecuteWithDelay(milliseconds,function() ExecuteInGameThread(callback) end)
        end
    end
end

-- Failures handling events are logged once per kind; repeats are
-- counted and reported when combat ends, so a lasting fault never writes the
-- log on every call.
local failures={}
local function fail(kind,why)
    local count=failures[kind]
    failures[kind]=(count or 0)+1
    if not count then log.error(kind,' failed: ',why) end
end
local function reportFailures()
    for kind,count in pairs(failures) do
        if count>1 then log.warn(kind,' failed ',count-1,' more times') end
    end
    failures={}
end

local pump

-- One animation frame, in a pass: the cue resolves once for the whole step.
local function frame(record)
    record.scheduled=false
    if record.detached or not Cue.valid(record.ui) then return end
    local stepped,more=pcall(record.model.step,record.model)
    record.steps=record.steps+1
    if not stepped then record.model:cancel(); fail('animation step',more); return end
    if more then pump(record) return end
    if log.enabled('TRACE') then
        log.trace('animation settled after ',record.steps,' steps in ',
            string.format('%.0f',(os.clock()-record.since)*1000),' ms',
            record.direction and '; '..DIRECTIONS[record.direction]..' arrow '
                ..Cue.describeArrow(record.ui,record.direction) or '')
    end
    record.steps=nil
end

function pump(record)
    if record.scheduled or record.detached or not record.model:has_jobs() then return end
    record.scheduled=true
    if not record.steps then record.steps,record.since=0,log.enabled('TRACE') and os.clock() or 0 end
    local ok,why=pcall(later,FRAME_MS,record.onFrame,record.preview)
    if not ok then record.scheduled=false; record.model:cancel(); fail('animation schedule',why) end
end

-- sameWorld already fails for a cue that is gone. A preview event (ModCore
-- Templates' live preview in the mod menu) reaches only the preview cue, a game
-- event only the HUD's.
local function cueFor(indicator,preview)
    for _,record in ipairs(cues) do
        if record.preview==(preview==true) and Cue.sameWorld(indicator,record.ui) then return record end
    end
end

-- The attack resolved: its arrow goes at once, the idle cue stays.
local function release(record,why)
    log.debug(why,' ',record.direction and DIRECTIONS[record.direction] or 'none')
    record.source,record.direction,record.critical,record.paths=nil,nil,nil,nil
    if record.model:hide(false) then pump(record) end
end

-- The attack went critical: its arrow turns red and holds until it resolves.
local function escalate(record,path,direction)
    record.critical=true
    Cue.critical(record.ui,direction)
    record.model:critical(direction)
    log.debug('critical ',DIRECTIONS[direction],' from ',path)
    pump(record)
end

-- Shows an attack from an indicator in the cue of the same world. MCT reports
-- an attack as arrow when it shows up (its parry window opens) and as critical
-- when its Perfect Opportunity window opens, which escalates the cue's own
-- attack or shows another attack red from the start.
--
-- Attack Incoming and Perfect Opportunity affect the arrow alone: its attack
-- is still shown from the first arrow (preymonition.omens_render's phases).
-- A held arrow is the yellow arrow until the Perfect Opportunity window opens,
-- shown and moved as the pair says; then it turns red and carries its
-- animation on from there to the end. An arrow not held shows and moves from
-- the first arrow and jumps to its critical size when that window opens.
-- Without red (Perfect Opportunity Off) a critical event counts as an arrow:
-- the arrow stays yellow and moves as usual until the attack resolves.
--
-- An attack in the direction of the arrow still shown counts as that arrow's,
-- whatever its indicator: the game sometimes reports one attack twice, and a new
-- arrow would flash in again. The arrow stays until all of them resolve.
local function present(indicator,path,direction,event)
    local record=cueFor(indicator,event.preview)
    if not record then log.trace('arrow #',event.sequence,': no cue in the indicator world'); return end
    local held=record.held
    local critical=record.red and event.kind=='critical'
    if record.source and record.direction==direction then
        record.paths[path]=true
        -- Only the attack's Perfect Opportunity window changes its arrow; a
        -- repeated arrow event leaves it as it is.
        if record.critical or not critical then return end
        if held then
            record.critical=true
            Cue.critical(record.ui,direction)
            if record.model:reveal(direction) then
                log.debug('reveal ',DIRECTIONS[direction],' from ',path)
                pump(record)
                return
            end
        end
        escalate(record,path,direction)
        return
    end
    -- First seen critical, as MCT reports an attack whose arrow it sent while
    -- the cue showed another: its show starts red now. A held arrow travels from
    -- rest; one not held also takes its critical size at once, as it would
    -- have when that window opened.
    local mode=critical and 'critical' or (held and 'held') or nil
    if critical then Cue.critical(record.ui,direction) else Cue.arm(record.ui,direction) end
    record.source,record.direction,record.critical=path,direction,critical or nil
    record.paths={[path]=true}
    if record.model:show(direction,event.path..':'..event.sequence,mode,record.travel) then
        if critical and not held then record.model:critical(direction) end
        log.debug('show ',DIRECTIONS[direction],mode and ' '..mode or '',' from ',path)
        pump(record)
    end
end

-- The unblockable skull showed on an indicator, or went: shown at the cue's
-- centre until it goes.
local function unblockable(event)
    local record=cueFor(event.indicator,event.preview)
    if not record then return end
    local path=event.path
    if event.active then
        if record.skull then return end
        record.skull=true
        local ok,file,why=pcall(Cue.skull,record.ui,true)
        if not ok or not file then log.warn('unblockable picture unavailable: ',ok and why or file) end
        record.model:unblockable(true)
        pump(record)
        log.debug('unblockable attack')
    elseif record.skull then
        record.skull=nil
        local ok,why=pcall(Cue.skull,record.ui,false)
        if not ok then log.warn('skull clearing failed: ',why) end
        record.model:unblockable(false)
        pump(record)
        log.debug('unblockable passed')
    end
end

-- An indicator's attack ended: the indicator went back to the sword, or was
-- hidden.
local function resolve(event)
    local path=event.path
    for _,record in ipairs(cues) do
        if record.paths and record.paths[path] and record.preview==(event.preview==true) then
            record.paths[path]=nil
            if next(record.paths)==nil then
                release(record,event.reason=='sword' and 'attack resolved:' or 'indicator hidden:')
            end
        end
    end
end

-- Combat ended: the cue goes and resets.
local function endCombat()
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) and not record.preview then
            log.debug('combat ended; cue out')
            record.source,record.direction,record.critical,record.paths=nil,nil,nil,nil
            if record.skull then
                record.skull=nil
                pcall(Cue.skull,record.ui,false)
                record.model:unblockable(false)
            end
            record.model:hide(true)
            pump(record)
        end
    end
end

-- Each attack's animation lasts PER_MULTIPLIER seconds times the game's parry
-- window multiplier, read when combat starts: 280 ms at 1.4, the second
-- difficulty. FALLBACK stands in for the multiplier when it cannot be read.
local PER_MULTIPLIER,FALLBACK=0.2,1.4
-- A cue takes the parry window's pace and shows its idle cue.
local function engage(record)
    local read,multiplier=pcall(Combat.parryWindow,Cue.context(record.ui))
    if not (read and multiplier) then
        log.debug('parry window unreadable',read and '' or ': '..tostring(multiplier),'; assuming ',FALLBACK)
        multiplier=FALLBACK
    end
    record.model:setDuration(PER_MULTIPLIER*multiplier)
    log.debug('parry window ',multiplier,'; animations take ',
        string.format('%.0f',PER_MULTIPLIER*multiplier*1000),' ms')
    log.debug(record.model:engage() and 'idle cue shown' or 'idle cue already showing')
    pump(record)
end
local function startCombat()
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) and not record.preview then engage(record) end
    end
end

-- MC_NPCAttackIndicator events, by kind. An arrow and a critical arrow are
-- presented alike: the Perfect Opportunity window of a cue's own attack
-- escalates it, and a critical arrow from another indicator shows as that
-- indicator's attack.
local function arrow(event) present(event.indicator,event.path,event.direction,event) end
local handlers={
    arrow=arrow,
    critical=arrow,
    resolve=resolve,
    unblockable=unblockable,
}

-- One MC_NPCAttackIndicator event, in a pass.
function M.update(event)
    if not next(cues) or not (active or event.preview) then return end
    local handler=handlers[event.kind]
    if not handler then return end
    local ok,why=Cue.pass(handler,event)
    if not ok then fail(event.kind,why) end
end

-- Combat started: take MCT's attack events and show the idle cue.
function M.wake()
    if active then return end
    active=true
    log.debug('combat started; animation steps ',frames() and 'every frame' or 'by ExecuteWithDelay')
    local ok,why=Cue.pass(startCombat)
    if not ok then error(why,0) end
end

-- Combat ended, the template was deselected or MCT stopped: the cue goes.
function M.sleep()
    if not active then return end
    -- Takes no more events; animations already running finish.
    active=false
    reportFailures()
    local ok,why=Cue.pass(endCombat)
    if not ok then error(why,0) end
end

function M.attach(hud,layer,params,onCleanup)
    local settings=params.settings or {}
    -- The arrow's phases by Attack Incoming and Perfect Opportunity: whether
    -- the yellow arrow is held back until the Perfect Opportunity window opens,
    -- how far it moves, and whether that window turns it red
    -- (preymonition.omens_render's phases).
    local phases=Cue.phases(settings)
    local record={detached=false,preview=params.preview==true,held=phases.held,
        travel=phases.travel,red=phases.red}
    record.onFrame=function()
        local ok,why=Cue.pass(frame,record)
        if not ok then record.scheduled=false; fail('animation step',why) end
    end
    onCleanup(function()
        record.detached=true
        if record.model then record.model:cancel() end
        for index,current in ipairs(cues) do
            if current==record then table.remove(cues,index); break end
        end
        if record.ui then Cue.destroy(record.ui) end
        log.debug('cue detached; ',#cues,' attached')
        return true
    end)
    record.ui=Cue.build(hud,layer,assert(params.screen,'screen unavailable'),settings)
    local ui=record.ui
    record.model=Animation.new({
        now=function() return Combat.now(Cue.context(ui)) end,
        apply=function(state) Cue.apply(ui,state) end,
    })
    record.model:step()
    cues[#cues+1]=record
    -- A preview cue shows at once: there is no combat to wake it. A cue attached
    -- in combat (the template enabled or its settings applied mid-fight, or MCT
    -- waking it before it attaches) takes the combat's pace as wake would give it.
    if record.preview or active then
        local ok,why=Cue.pass(engage,record)
        if not ok then fail(record.preview and 'preview' or 'engage',why) end
    end
    log.info(record.preview and 'preview cue attached, position ' or 'cue attached, position ',ui.visuals.position,', screen ',
        params.screen.width,'x',params.screen.height,' @',params.screen.scale)
    if ui.visuals.missing then
        log.warn('arrow picture for Style ',ui.visuals.style,' did not load; no arrows show')
    end
end

return M
