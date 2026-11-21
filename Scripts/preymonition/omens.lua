-- Follows MCT's MC_NPCAttackIndicator events with the cue animation of attached HUDs.
local Animation=require('preymonition.omens_animation')
local Combat=require('preymonition.combat')
local Controller=require('preymonition.controller')
local Cue=require('preymonition.omens_render')

-- MCT watches the game's combat target indicator and delivers each change as an
-- MC_NPCAttackIndicator update event on the next engine tick, about a frame
-- after the game shows it. MCT wakes the template when combat starts and puts
-- it to sleep when combat ends.
-- Direction names for the log, from the indicator's arrow names.
local DIRECTIONS={}
for index,key in ipairs(Cue.ARROWS) do DIRECTIONS[index]=key:match('^(%u%l+)Arrow$'):lower() end

local cues={}
-- Whether combat is on: events arrive only while it is.
local active=false
local M={}

-- Replaced by the template's leveled logger; silent until then.
local log=Controller.silentLog()

function M.setLog(logger)
    log=logger
end

-- Failures handling events are logged once per kind and counted until combat ends.
local fail,reportFailures=Controller.failures('',function() return log end)

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
    -- The next animation frame. Deferred work guards itself: an animation step
    -- stops once its cue is detached.
    local ok,why=pcall(Controller.later,record.onFrame)
    if not ok then record.scheduled=false; record.model:cancel(); fail('animation schedule',why) end
end

-- Runs callback for every cue in the indicator's world, as the other templates
-- do: a HUD replaced but not yet detached shows the attack as well as its
-- successor. sameWorld already fails for a cue that is gone. A preview event
-- (ModCore Templates' live preview in the mod menu) reaches only the preview cue,
-- a game event only the HUD's. False when no cue took it.
local function eachCue(event,callback)
    local preview,found=event.preview==true,false
    for _,record in ipairs(cues) do
        if record.preview==preview and Cue.sameWorld(event.indicator,record.ui) then
            found=true
            callback(record,event)
        end
    end
    return found
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
-- arrow would flash in again. The arrow stays until all of them resolve
-- (preymonition.controller's joins).
local function present(record,event)
    local path,direction=event.path,event.direction
    local held=record.held
    local critical=record.red and event.kind=='critical'
    if Controller.joins(record,event) then
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
    Controller.open(record,event)
    record.critical=critical or nil
    if record.model:show(direction,mode,record.travel) then
        if critical and not held then record.model:critical(direction) end
        log.debug('show ',DIRECTIONS[direction],mode and ' '..mode or '',' from ',path)
        pump(record)
    end
end

-- The unblockable skull showed on an indicator, or went: shown at the cue's
-- centre until it goes.
local function showUnblockable(record,event)
    if event.active then
        if record.skull then return end
        record.skull=true
        -- A picture that did not load was reported at attach; the centre stays clear.
        local ok,why=pcall(Cue.skull,record.ui,true)
        if not ok then fail('unblockable picture',why) end
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
local function unblockable(event) eachCue(event,showUnblockable) end

-- An indicator's attack ended: the indicator went back to the sword, or was
-- hidden.
local function resolve(event)
    for _,record in ipairs(cues) do
        if record.preview==(event.preview==true) and Controller.resolves(record,event.path) then
            release(record,event.reason=='sword' and 'attack resolved:' or 'indicator hidden:')
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
-- difficulty, which stands in for the multiplier when it cannot be read.
local PER_MULTIPLIER=0.2
-- A cue takes the parry window's pace and shows its idle cue.
local function engage(record)
    local multiplier=Controller.pace(Cue.context(record.ui),log)
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
local function arrow(event)
    if not eachCue(event,present) then log.trace('arrow #',event.sequence,': no cue in the indicator world') end
end
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
    log.debug('combat started; animation steps ',Controller.frames() and 'every frame' or 'by ExecuteWithDelay')
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

-- Pictures that did not load, by Style or unblockable file: each is warned about
-- once, at the first attach that misses it.
local warned={}

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
    if ui.visuals.missing and not warned['style:'..tostring(ui.visuals.style)] then
        warned['style:'..tostring(ui.visuals.style)]=true
        log.warn('arrow picture for Style ',ui.visuals.style,' did not load; no arrows show: ',ui.visuals.missing)
    end
    if ui.pictureMissing and not warned['unblockable:'..tostring(ui.visuals.unblockable)] then
        warned['unblockable:'..tostring(ui.visuals.unblockable)]=true
        log.warn('unblockable picture ',ui.visuals.unblockable,' did not load; the centre stays clear: ',ui.pictureMissing)
    end
end

return M
