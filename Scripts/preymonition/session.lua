-- Follows MCT's MC_NPCAttackIndicator events with the cue animation of attached HUDs.
local Animation=require('preymonition.animation')
local Cue=require('preymonition.cue')
local Sound=require('preymonition.sound')

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
-- detached.
local function later(milliseconds,callback)
    if milliseconds<=FRAME_MS and frames() then
        ExecuteInGameThreadAfterFrames(1,callback)
    else
        ExecuteWithDelay(milliseconds,function() ExecuteInGameThread(callback) end)
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
    local ok,why=pcall(later,FRAME_MS,record.onFrame)
    if not ok then record.scheduled=false; record.model:cancel(); fail('animation schedule',why) end
end

-- sameWorld already fails for a cue that is gone.
local function cueFor(indicator)
    for _,record in ipairs(cues) do
        if Cue.sameWorld(indicator,record.ui) then return record end
    end
end

-- A cue built before the shield sprite was found retries it; clear until then.
local function styleShield(record)
    local ok,sprite=pcall(Cue.styleShield,record.ui)
    if not ok then log.warn('shield styling failed: ',sprite)
    elseif not sprite then log.debug('shield sprite still not found; shield stays clear') end
end

-- Plays a cue's sound for an event, when one is chosen, at the attacker behind
-- the indicator, else the player. A failure is reported once per sound and
-- never stops the cue.
local failedSounds={}
local function play(record,path,indicator)
    if not path then return end
    local ok,why=pcall(function()
        local found,attacker=pcall(Cue.attacker,indicator)
        attacker=found and attacker or nil
        log.debug('sound at ',attacker and Cue.path(attacker) or 'the player')
        return Sound.play(path,Cue.context(record.ui),attacker)
    end)
    if ok then log.trace('sound ',path,' playing id ',why) return end
    if not failedSounds[path] then
        failedSounds[path]=true
        log.warn('sound unavailable: ',why)
    end
end

-- The attack resolved: its arrow goes at once, the idle cue stays.
local function release(record,why)
    log.debug(why,' ',record.direction and DIRECTIONS[record.direction] or 'none')
    record.source,record.direction,record.critical=nil,nil,nil
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
-- an attack as arrow when it shows up and as critical when its parry window
-- opens; for the cue's own attack either escalates it.
local function present(indicator,path,direction,event)
    local record=cueFor(indicator)
    if not record then log.trace('arrow #',event.sequence,': no cue in the indicator world'); return end
    if record.source==path and record.direction==direction then
        if record.critical then return end
        escalate(record,path,direction)
        return
    end
    if not record.ui.artwork then log.debug('arrow artwork not found yet; attack not shown') return end
    Cue.arm(record.ui,direction)
    record.source,record.direction,record.critical=path,direction,nil
    if record.model:show(direction,event.path..':'..event.sequence) then
        log.debug('show ',DIRECTIONS[direction],' from ',path)
        play(record,record.sounds.arrow,indicator)
        pump(record)
    end
end

-- The unblockable skull showed on an indicator, or went: shown as a skull in
-- place of the shield until it goes.
local function unblockable(event)
    local record=cueFor(event.indicator)
    if not record then return end
    local path=event.path
    if event.active then
        if record.skull then return end
        record.skull=true
        local ok,why=pcall(Cue.centre,record.ui,'skull')
        if not ok or not why then log.warn('centre sprite unavailable: ',why) end
        play(record,record.sounds.skull,event.indicator)
        record.model:unblockable(true)
        pump(record)
        log.debug('unblockable attack')
    elseif record.skull then
        record.skull=nil
        local ok,why=pcall(Cue.centre,record.ui,'shield')
        if not ok or not why then log.warn('centre sprite unavailable: ',why) end
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
        if record.source==path then
            release(record,event.reason=='sword' and 'attack resolved:' or 'indicator hidden:')
        end
    end
end

-- Combat ended: the cue fades out and resets.
local function endCombat()
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) then
            log.debug('combat ended; fading out')
            record.source,record.direction,record.critical=nil,nil,nil
            if record.skull then
                record.skull=nil
                pcall(Cue.centre,record.ui,'shield')
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
local function startCombat()
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) then
            local read,multiplier=pcall(Cue.parryWindow,Cue.context(record.ui))
            if not (read and multiplier) then
                log.debug('parry window unreadable',read and '' or ': '..tostring(multiplier),'; assuming ',FALLBACK)
                multiplier=FALLBACK
            end
            record.model:setDuration(PER_MULTIPLIER*multiplier)
            log.debug('parry window ',multiplier,'; animations take ',
                string.format('%.0f',PER_MULTIPLIER*multiplier*1000),' ms')
            styleShield(record)
            if not Cue.artwork(record.ui) then log.warn('arrow artwork unavailable') end
            if record.model:engage() then
                log.debug('combat started; cue fading in')
                pump(record)
            else
                log.debug('combat started; cue already showing')
            end
        end
    end
end

-- MC_NPCAttackIndicator events, by kind. An arrow and a critical arrow are
-- presented alike: the parry window of a cue's own attack escalates it, and a
-- critical arrow from another indicator shows as that indicator's attack.
local function arrow(event) present(event.indicator,event.path,event.direction,event) end
local handlers={
    arrow=arrow,
    critical=arrow,
    resolve=resolve,
    unblockable=unblockable,
}

-- One MC_NPCAttackIndicator event, in a pass.
function M.update(event)
    if not (active and next(cues)) then return end
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

-- Combat ended, the template was deselected or MCT stopped: fade out.
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
    local record={detached=false,
        sounds={arrow=Sound.ARROW[settings.ParrySound],skull=Sound.UNBLOCKABLE[settings.UnblockableSound]}}
    record.onFrame=function()
        local ok,why=Cue.pass(frame,record)
        if not ok then record.scheduled=false; fail('animation step',why) end
    end
    -- Chosen sounds load now rather than at their first play, mid-combat.
    for _,path in pairs(record.sounds) do
        if not Sound.preload(path) then log.warn('sound event unavailable: ',path) end
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
        now=function() return Cue.now(ui) end,
        apply=function(state) Cue.apply(ui,state) end,
        -- Only the Critical shield grows when it pops in.
        grow=ui.visuals.watermark==3,
    })
    record.model:step()
    cues[#cues+1]=record
    log.info('cue attached, scale ',settings.GeneralScale or 0,'%, position ',settings.GeneralPosition or 1,', screen ',
        params.screen.width,'x',params.screen.height,' @',params.screen.scale,
        '; shield ',ui.sprite or 'not found yet','; flash ',ui.flash or 'texture not found')
end

return M
