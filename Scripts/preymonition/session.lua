-- Attack detection, event coalescing and cue animation for attached HUDs.
local Animation=require('preymonition.animation')
local Cue=require('preymonition.cue')
local Events=require('preymonition.events')
local Sound=require('preymonition.sound')
local MC=require('mc')

-- The game reuses its indicator widgets and updates them from C++, which UE4SS
-- hooks never see; the indicator blueprint's own events register with
-- HookProcessInternal but never fire. The
-- indicator blueprint styles the attacked arrow and its centre icon through
-- this native Image call, so the call names the attack's direction and state.
-- It is hooked only during combat: MCT wakes the template when combat starts
-- and puts it to sleep when combat ends.
local ARROW_HOOK='/Script/UMG.Image:SetBrushFromAtlasInterface'
local FRAME_MS=16
-- Direction names for the log, from the indicator's arrow names.
local DIRECTIONS={}
for index,key in ipairs(Cue.ARROWS) do DIRECTIONS[index]=key:match('^(%u%l+)Arrow$'):lower() end

local queue=Events.new(16)
local cues={}
-- Whether combat is on and the arrow hook registered.
local active=false
local pending=false
local M={}
-- Queues deferred work for the next frame; defined with the hooks below.
local push

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
-- detached, and a drain after sleep finds the queue empty.
local function later(milliseconds,callback)
    if milliseconds<=FRAME_MS and frames() then
        ExecuteInGameThreadAfterFrames(1,callback)
    else
        ExecuteWithDelay(milliseconds,function() ExecuteInGameThread(callback) end)
    end
end

-- Failures inside the game's calls are logged once per kind; repeats are
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

local handlers={}

-- A cue built before the shield sprite was found retries it; clear until then.
local function styleShield(record)
    local ok,sprite=pcall(Cue.styleShield,record.ui)
    if not ok then log.warn('shield styling failed: ',sprite)
    elseif not sprite then log.debug('shield sprite still not found; shield stays clear') end
end

-- Plays a cue's sound for an event, when one is chosen, at the attacker: the
-- one given, else the one behind the indicator, else the player. A failure is
-- reported once per sound and never stops the cue.
local failedSounds={}
local function play(record,path,indicator,attacker)
    if not path then return end
    local ok,why=pcall(function()
        if not attacker then
            local found,behind=pcall(Cue.attacker,indicator)
            attacker=found and behind or nil
        end
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
    record.source,record.direction,record.critical,record.early=nil,nil,nil,nil
    if record.model:hide(false) then pump(record) end
end

-- The attack went critical: its arrow turns red and holds until it resolves.
local function escalate(record,indicator,path,direction)
    record.critical=true
    Cue.style(record.ui,indicator,direction)
    Cue.critical(record.ui,direction)
    record.model:critical(direction)
    log.debug('critical ',DIRECTIONS[direction],' from ',path)
    pump(record)
end

-- Shows an attack from an indicator in the cue of the same world. Each attack
-- styles its arrow when it shows up and again when it turns critical. Nothing
-- the hook can read tells the two apart: in play the native colour, brush and
-- tint read the same both times. So the second styling of the shown arrow is
-- the critical one.
local function present(indicator,path,direction,event)
    local record=cueFor(indicator)
    if not record then log.trace('arrow #',event.sequence,': no cue in the indicator world'); return end
    if record.source==path and record.direction==direction then
        if record.critical then return end
        escalate(record,indicator,path,direction)
        return
    end
    record.indicator=path
    -- The game's early warning already showed this attack: the arrow takes it
    -- over without showing or sounding again.
    if record.early and record.direction==direction then
        record.early=nil
        record.source=path
        log.debug('show ',DIRECTIONS[direction],' from ',path,' (shown early)')
        return
    end
    Cue.style(record.ui,indicator,direction)
    record.source,record.direction,record.critical,record.early=path,direction,nil,nil
    if record.model:show(direction,event.path..':'..event.sequence) then
        log.debug('show ',DIRECTIONS[direction],' from ',path)
        play(record,record.sounds.arrow,indicator)
        pump(record)
    end
end

-- The indicator's centre icon is about to change. Sword means no attack is
-- pending, so a shown arrow resolved; SkullRed is an unblockable attack, shown
-- as a skull in place of the shield until the icon changes again.
local function onCentre(image,sprite,sequence)
    local indicator=Cue.indicatorOf(image)
    if not indicator then return end
    local path=Cue.path(indicator)
    sprite=sprite or ''
    log.trace('centre #',sequence,': ',sprite,' on ',path)
    local record=cueFor(indicator)
    if not record then return end
    -- The game updates hidden twin indicators too. A hidden indicator's skull
    -- is not on screen, and only the indicator that showed the skull, or a
    -- visible one, takes it away.
    local visible=Cue.visible(indicator)
    if visible or record.skullSource==path then
        local skull=visible and sprite:find('SkullRed',1,true)~=nil
        if skull then record.skullSource,record.earlySkull=path,nil end
        if skull~=(record.skull==true) then
            record.skull=skull
            if not skull then record.skullSource=nil end
            local ok,why=pcall(Cue.centre,record.ui,skull and 'skull' or 'shield')
            if not ok or not why then log.warn('centre sprite unavailable: ',why) end
            if skull then play(record,record.sounds.skull,indicator) end
            record.model:unblockable(skull)
            pump(record)
            log.debug(skull and 'unblockable attack' or 'unblockable passed')
        end
    end
    if sprite:find('Sword',1,true) and record.source==path then release(record,'attack resolved:') end
end

-- An indicator arrow was just restyled, in the same frame the game shows it:
-- lit for an attack, dark when the game turns it off. Returns whether it was
-- handled; an arrow not lit yet is checked again next frame.
local function onArrow(image,direction,sequence)
    local started=log.enabled('TRACE') and os.clock()
    local indicator=Cue.indicatorOf(image)
    if not indicator then log.trace('arrow #',sequence,': not an indicator arrow'); return true end
    local path=Cue.path(indicator)
    -- The game updates hidden indicators too, and an arrow's parents end inside
    -- its indicator's own tree, so the indicator's visibility is checked by
    -- itself. A hidden source indicator means its attack is over.
    if not Cue.visible(indicator) then
        log.trace('arrow #',sequence,': ',DIRECTIONS[direction],' on a hidden indicator')
        for _,record in ipairs(cues) do
            if record.source==path then release(record,'indicator hidden:') end
        end
        return true
    end
    local lit=Cue.lit(image)
    if log.enabled('TRACE') then
        log.trace('arrow #',sequence,': ',DIRECTIONS[direction],lit and ' lit, ' or ' dark, ',Cue.describe(image))
    end
    if lit then
        present(indicator,path,direction,{path=path,sequence=sequence})
    else
        for _,record in ipairs(cues) do
            if record.source==path and record.direction==direction then release(record,'arrow went dark:') end
        end
    end
    if started then
        log.trace('arrow #',sequence,' handled in ',string.format('%.1f',(os.clock()-started)*1000),' ms')
    end
    return lit,path
end

-- Next frame, an indicator that styled an arrow not lit at the time: an arrow
-- lit now and not already shown is an attack. Its arrows are checked once per
-- frame however many it styled. This never turns an arrow critical or out.
function handlers.arrow(event)
    local indicator=Cue.resolve(event.path)
    if not indicator or not Cue.visible(indicator) then return end
    local record=cueFor(indicator)
    if not record then return end
    for direction=1,#Cue.ARROWS do
        if not (record.source==event.path and record.direction==direction) then
            local image=Cue.arrowOf(indicator,direction)
            if image and Cue.lit(image) then
                log.debug('arrow #',event.sequence,' lit late')
                present(indicator,event.path,direction,event)
                return
            end
        end
    end
end

-- Combat ended: the cue fades out and resets, unless it is a preview.
local function endCombat()
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) then
            log.debug('combat ended; ',record.preview and 'preview stays visible' or 'fading out')
            record.source,record.direction,record.critical,record.early=nil,nil,nil,nil
            record.skullSource,record.earlySkull=nil,nil
            if record.skull then
                record.skull=nil
                pcall(Cue.centre,record.ui,'shield')
                record.model:unblockable(false)
            end
            record.model:hide(not record.preview)
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
            if record.model:engage() then
                log.debug('combat started; cue fading in')
                pump(record)
            else
                log.debug('combat started; cue already showing')
            end
        end
    end
end



local function drain()
    local events=queue:drain()
    log.trace('drain ',#events,' event(s), ',queue.dropped,' dropped so far')
    for _,event in ipairs(events) do
        local ok,why=pcall(handlers[event.kind],event)
        if not ok then fail(event.kind,why) end
    end
end

local schedule
-- The deferred drain runs as one pass.
local function drainLater()
    pending=false
    Cue.pass(drain)
    if #queue.items>0 then schedule() end
end

function schedule()
    if pending or not active then return end
    pending=true
    local ok,why=pcall(later,1,drainLater)
    if not ok then pending=false; queue:clear(); fail('event schedule',why) end
end

function push(kind,path)
    if not active or not next(cues) or not path then
        log.trace(kind,' ignored: ',not active and 'inactive' or not path and 'no path' or 'no cue attached')
        return
    end
    log.trace(kind,' queued ',path)
    queue:push(kind,path)
    schedule()
end

-- Takes no more events and drops queued ones; animations already running finish.
local function pause()
    active=false
    pending=false
    queue:clear()
end

-- The game's early warning: for some attacks, often the first of an exchange,
-- the player's helper indicator is told about the attack 0.1-0.9 s before the
-- indicator arrow lights, with its direction (EARLY_DIRECTIONS maps the game's
-- 1-4 to our arrows), whether it is unblockable and its attacker. The cue shows
-- it then; the arrow or skull takes it over when it lights, and an early show
-- nothing takes over goes after EARLY_TIMEOUT_MS.
local EARLY_HOOK='/Script/Dawnwalker.DawnwalkerPlayerCharacter:ShowHelperAttackIndicator'
local EARLY_DIRECTIONS={[1]=4,[2]=3,[3]=1,[4]=2}
local EARLY_TIMEOUT_MS=1200
local earlyHook=nil
local earlies=0

local function expire(record,token)
    if record.earlyToken~=token or record.detached or not Cue.valid(record.ui) then return end
    if record.early then
        record.early=nil
        release(record,'early show expired:')
    end
    if record.earlySkull then
        record.earlySkull,record.skull=nil,nil
        pcall(Cue.centre,record.ui,'shield')
        record.model:unblockable(false)
        pump(record)
        log.debug('early unblockable expired')
    end
end

local function earlyWarning(data)
    local attack=data:get()
    local direction=EARLY_DIRECTIONS[tonumber(attack.Direction)]
    local unblockable=attack.bIsUnblockable==true
    local attacker
    local component=attack.Instigator
    if component and component:IsValid() then attacker=MC.call(component,'GetOwner') end
    if not (attacker and MC.valid(attacker)) then attacker=nil end
    earlies=earlies+1
    for _,record in ipairs(cues) do
        if not record.detached and Cue.valid(record.ui) then
            local shown=false
            if unblockable then
                if not record.skull then
                    record.skull,record.earlySkull=true,true
                    local ok,why=pcall(Cue.centre,record.ui,'skull')
                    if not ok or not why then log.warn('centre sprite unavailable: ',why) end
                    play(record,record.sounds.skull,nil,attacker)
                    record.model:unblockable(true)
                    shown=true
                end
            elseif direction and not record.source and not record.early then
                -- The arrow's artwork and rest come from the last indicator seen.
                local indicator=record.indicator and Cue.resolve(record.indicator)
                if indicator then
                    Cue.style(record.ui,indicator,direction)
                    record.direction,record.critical,record.early=direction,nil,true
                    record.model:show(direction,'early:'..earlies)
                    play(record,record.sounds.arrow,nil,attacker)
                    shown=true
                end
            end
            if shown then
                log.debug('early ',unblockable and 'unblockable' or DIRECTIONS[direction],' by ',
                    attacker and Cue.path(attacker) or 'unknown')
                pump(record)
                record.earlyToken=(record.earlyToken or 0)+1
                local token=record.earlyToken
                local ok,why=pcall(later,EARLY_TIMEOUT_MS,function()
                    local done,failure=Cue.pass(expire,record,token)
                    if not done then fail('early expiry',failure) end
                end)
                if not ok then fail('early schedule',why) end
            else
                log.debug('early warning ',unblockable and 'unblockable' or tostring(attack.Direction),' not shown')
            end
        end
    end
end

local function onEarlyWarning(_,data)
    if not active or not next(cues) then return end
    local ok,why=Cue.pass(earlyWarning,data)
    if not ok then fail('early warning',why) end
end

local hook=nil
local sequence=0
-- Styling calls seen this combat, and those that were the indicator's.
local styled,handled=0,0

local function ready()
    return active and next(cues)~=nil
end

-- Every atlas image passes through the styling call, and the game styles an
-- indicator's arrows and centre icon in one frame, in order. Both are handled
-- during the call so our cue changes in that same frame, in the game's order:
-- the centre icon before the call, from the sprite argument; an arrow after
-- it, once its brush and colour are set.
-- Hoisted so a styling call builds no closure.
local function spriteName(sprite) return Cue.name(sprite:get()) end

local function centreStyling(context,sprite)
    local object=context:get()
    if Cue.known(object)~='Reticle' then return end
    handled=handled+1
    local read,name=pcall(spriteName,sprite)
    sequence=sequence+1
    onCentre(object,read and name or nil,sequence)
end

local function arrowStyling(context)
    local object=context:get()
    local direction=Cue.arrowIndex(object)
    if not direction then return end
    handled=handled+1
    sequence=sequence+1
    local lit,path=onArrow(object,direction,sequence)
    if not lit then push('arrow',path) end
end

local function beforeStyling(context,sprite)
    if not ready() then return end
    local ok,why=Cue.pass(centreStyling,context,sprite)
    if not ok then fail('centre icon',why) end
end

local function afterStyling(context)
    styled=styled+1
    if not ready() then return end
    local ok,why=Cue.pass(arrowStyling,context)
    if not ok then fail('arrow',why) end
end

-- Combat started: hook the arrow styling and show the idle cue.
function M.wake()
    if active then return end
    local registered,pre,post=pcall(RegisterHook,ARROW_HOOK,beforeStyling,afterStyling)
    if not (registered and type(pre)=='number' and type(post)=='number') then
        error(registered and 'hook unavailable: '..ARROW_HOOK or pre,0)
    end
    hook={pre,post}
    active=true
    styled,handled=0,0
    -- The early warning is a bonus: without it the cue still follows the arrows.
    local early,earlyPre,earlyPost=pcall(RegisterHook,EARLY_HOOK,onEarlyWarning)
    if early and type(earlyPre)=='number' then
        earlyHook={earlyPre,earlyPost}
    else
        log.warn('early warning unavailable: ',early and 'no hook id' or earlyPre)
    end
    log.debug('arrow hook registered (ids ',pre,', ',post,'); animation steps ',frames() and 'every frame' or 'by ExecuteWithDelay')
    local ok,why=Cue.pass(startCombat)
    if not ok then error(why,0) end
end

-- Combat ended, the template was deselected or MCT stopped: unhook and fade out.
function M.sleep()
    local wasActive=active
    pause()
    if wasActive then
        log.debug('combat saw ',styled,' styling calls, ',handled,' of them the indicator\'s')
        reportFailures()
        local ok,why=Cue.pass(endCombat)
        if not ok then error(why,0) end
    end
    if earlyHook then
        local removed,why=pcall(UnregisterHook,EARLY_HOOK,earlyHook[1],earlyHook[2])
        if not removed then log.warn('early warning hook removal failed: ',why) end
        earlyHook=nil
    end
    if not hook then return end
    local removed,why=pcall(UnregisterHook,ARROW_HOOK,hook[1],hook[2])
    if not removed then error('hook removal failed: '..tostring(why),0) end
    hook=nil
    log.debug('arrow hook removed')
end

function M.attach(hud,layer,params,onCleanup,preview)
    local settings=params.settings or {}
    local record={detached=false,preview=preview==true,
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
    record.ui=Cue.build(hud,layer,assert(params.screen,'screen unavailable'),params.settings or {})
    local ui=record.ui
    record.model=Animation.new({
        now=function() return Cue.now(ui) end,
        apply=function(state) Cue.apply(ui,state) end,
        -- Only the Opportunity shield grows when it pops in.
        grow=ui.visuals.watermark==3,
    })
    record.model:step()
    cues[#cues+1]=record
    log.info('cue attached, size ',(params.settings or {}).ShieldSize or 20,'%, screen ',
        params.screen.width,'x',params.screen.height,' @',params.screen.scale,
        record.preview and ', preview' or '','; shield ',ui.sprite or 'not found yet',
        '; flash ',ui.flash or 'texture not found')
    if record.preview then
        styleShield(record)
        if record.model:show(1,'preview') then pump(record) end
    end
end

return M
