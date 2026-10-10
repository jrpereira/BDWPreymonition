-- Attack detection, event coalescing and cue animation for attached HUDs.
local Animation=require('preymonition.animation')
local Cue=require('preymonition.cue')
local Events=require('preymonition.events')
local Sound=require('preymonition.sound')

-- The game reuses its indicator widgets and updates them from C++, which UE4SS
-- hooks never see; this UE4SS cannot hook blueprint functions either. The
-- indicator blueprint styles the attacked arrow and its centre icon through
-- this native Image call, so the call names the attack's direction and state.
local HOOKS={
    {'/Script/UMG.Image:SetBrushFromAtlasInterface','arrow'},
    {'/Script/DogwoodCombat.PlayerCombatComponent:OnCombatEnded','combat_end'},
    {'/Script/DogwoodCombat.PlayerCombatComponent:OnCombatStarted','combat_start',optional=true},
}
local FRAME_MS=16
local DIRECTIONS={'top','bottom','left','right'}

local queue=Events.new(16)
local cues={}
local active=false
local pending=false
-- Invalidates deferred callbacks scheduled before the session last stopped.
local token=0
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

local function later(milliseconds,callback)
    local current=token
    local function run() if current==token then callback() end end
    if milliseconds<=FRAME_MS and frames() then
        ExecuteInGameThreadAfterFrames(1,run)
    else
        ExecuteWithDelay(milliseconds,function() ExecuteInGameThread(run) end)
    end
end

local function pump(record)
    if record.scheduled or record.detached or not record.model:has_jobs() then return end
    record.scheduled=true
    if not record.steps then record.steps,record.since=0,os.clock() end
    local ok,why=pcall(later,FRAME_MS,function()
        record.scheduled=false
        if record.detached or not Cue.valid(record.ui) then return end
        local stepped,more=pcall(record.model.step,record.model)
        record.steps=record.steps+1
        if not stepped then record.model:cancel(); log.error('animation step failed: ',more); return end
        if more then pump(record) return end
        if log.enabled('TRACE') then
            log.trace('animation settled after ',record.steps,' steps in ',
                string.format('%.0f',(os.clock()-record.since)*1000),' ms',
                record.direction and '; '..DIRECTIONS[record.direction]..' arrow '
                    ..Cue.describeArrow(record.ui,record.direction) or '')
        end
        record.steps=nil
    end)
    if not ok then record.scheduled=false; record.model:cancel(); log.error('animation schedule failed: ',why) end
end

local function cueFor(indicator)
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) and Cue.sameWorld(indicator,record.ui) then return record end
    end
end

local handlers={}

-- A cue built before the shield sprite was found retries it; clear until then.
local function styleShield(record)
    local ok,sprite=pcall(Cue.styleShield,record.ui)
    if not ok then log.warn('shield styling failed: ',sprite)
    elseif not sprite then log.debug('shield sprite still not found; shield stays clear') end
end

-- Plays a cue's sound for an event, when one is chosen; a failure is reported
-- once per sound and never stops the cue.
local failedSounds={}
local function play(record,path)
    if not path then return end
    local ok,why=pcall(function() return Sound.play(path,Cue.context(record.ui)) end)
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

-- Shows an attack from an indicator in the cue of the same world.
local function present(indicator,path,direction,event)
    local record=cueFor(indicator)
    if not record then log.trace('arrow #',event.sequence,': no cue in the indicator world'); return end
    -- Combat state follows the start and end hooks; after an end only a start re-enables.
    if record.ended then log.trace('arrow #',event.sequence,': ignored, combat ended'); return end
    -- Each attack styles its arrow twice: when it shows up, and when it turns
    -- red. Red holds until the attack resolves; later stylings change nothing.
    if record.source==path and record.direction==direction then
        if record.critical then return end
        record.critical=true
        Cue.style(record.ui,indicator,direction)
        Cue.critical(record.ui,direction)
        record.model:critical(direction)
        log.debug('critical ',DIRECTIONS[direction],' from ',path)
        pump(record)
        return
    end
    Cue.style(record.ui,indicator,direction)
    record.source,record.direction,record.critical=path,direction,nil
    if record.model:show(direction,event.path..':'..event.sequence) then
        log.debug('show ',DIRECTIONS[direction],' from ',path)
        play(record,record.sounds.arrow)
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
    if not record or record.ended then return end
    -- A hidden indicator's skull is not on screen.
    local skull=sprite:find('SkullRed',1,true)~=nil and Cue.visible(indicator)
    if skull~=(record.skull==true) then
        record.skull=skull
        local ok,why=pcall(Cue.centre,record.ui,skull and 'skull' or 'shield')
        if not ok or not why then log.warn('centre sprite unavailable: ',why) end
        if skull then play(record,record.sounds.skull) end
        log.debug(skull and 'unblockable attack' or 'unblockable passed')
    end
    if sprite:find('Sword',1,true) and record.source==path then release(record,'attack resolved:') end
end

-- An indicator arrow was just restyled, in the same frame the game shows it:
-- lit for an attack, dark when the game turns it off. Returns whether it was
-- handled; an arrow not lit yet is checked again next frame.
local function onArrow(image,direction,sequence)
    local started=os.clock()
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
    log.trace('arrow #',sequence,' handled in ',string.format('%.1f',(os.clock()-started)*1000),' ms')
    return lit
end

-- Next frame, an arrow that was not lit when styled: if it is lit now and not
-- already shown, it is an attack. It never turns an arrow critical or out.
function handlers.arrow(event)
    local image=Cue.resolve(event.path)
    local direction=Cue.arrowIndex(image)
    local indicator=direction and Cue.indicatorOf(image)
    if not indicator or not Cue.visible(indicator) or not Cue.lit(image) then return end
    local path=Cue.path(indicator)
    local record=cueFor(indicator)
    if not record or (record.source==path and record.direction==direction) then return end
    log.debug('arrow #',event.sequence,' lit late')
    present(indicator,path,direction,event)
end

function handlers.combat_end(event)
    log.trace('combat end #',event.sequence,' ',event.path)
    local component=Cue.resolve(event.path)
    if not component then return end
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) and Cue.sameWorld(component,record.ui) then
            log.debug('combat ended; ',record.preview and 'preview stays visible' or 'fading out')
            record.ended=true
            record.source,record.direction,record.critical=nil,nil,nil
            if record.skull then
                record.skull=nil
                pcall(Cue.centre,record.ui,'shield')
            end
            record.model:hide(not record.preview)
            pump(record)
        end
    end
end

function handlers.combat_start(event)
    log.trace('combat start #',event.sequence,' ',event.path)
    local component=Cue.resolve(event.path)
    if not component then return end
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) and Cue.sameWorld(component,record.ui) then
            record.ended=false
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

local function shortName(object)
    return object:GetFName():ToString()
end


local function drain()
    local events=queue:drain()
    log.trace('drain ',#events,' event(s), ',queue.dropped,' dropped so far')
    for _,event in ipairs(events) do
        local ok,why=pcall(handlers[event.kind],event)
        if not ok then log.error(event.kind,' failed: ',why) end
    end
end

local function schedule()
    if pending or not active then return end
    pending=true
    local ok,why=pcall(later,1,function()
        pending=false
        drain()
        if #queue.items>0 then schedule() end
    end)
    if not ok then pending=false; queue:clear(); log.error('event schedule failed: ',why) end
end

local function push(kind,path,data)
    if not active or not next(cues) or not path then
        log.trace(kind,' ignored: ',not active and 'inactive' or not path and 'no path' or 'no cue attached')
        return
    end
    log.trace(kind,' queued ',path,data and ' '..tostring(data) or '')
    queue:push(kind,path,data)
    schedule()
end

local function stop()
    active=false
    pending=false
    token=token+1
    queue:clear()
end

local hooks={}
local sequence=0

local function ready()
    return active and next(cues)~=nil
end

-- Every atlas image passes through the styling call, and the game styles an
-- indicator's arrows and centre icon in one frame, in order. Both are handled
-- during the call so our cue changes in that same frame, in the game's order:
-- the centre icon before the call, from the sprite argument; an arrow after
-- it, once its brush and colour are set.
local function beforeStyling(context,sprite)
    if not ready() then return end
    local ok,why=pcall(function()
        local object=context:get()
        if shortName(object)~='Reticle' then return end
        local _,name=pcall(function() return shortName(sprite:get()) end)
        sequence=sequence+1
        onCentre(object,name,sequence)
    end)
    if not ok then log.error('centre icon failed: ',why) end
end

local function afterStyling(context)
    if not ready() then return end
    local ok,why=pcall(function()
        local object=context:get()
        local direction=Cue.arrowIndex(object)
        if not direction then return end
        sequence=sequence+1
        if not onArrow(object,direction,sequence) then push('arrow',Cue.path(object)) end
    end)
    if not ok then log.error('arrow failed: ',why) end
end

local function register(spec)
    local path,kind=spec[1],spec[2]
    local before,after=function(context)
        -- Copy only the path here; widget reads wait for the deferred drain.
        local ok,value=pcall(function() return Cue.path(context:get()) end)
        if ok then push(kind,value) else log.trace(kind,' hook context unreadable: ',value) end
    end,nil
    if kind=='arrow' then before,after=beforeStyling,afterStyling end
    local registered,pre,post
    if after then registered,pre,post=pcall(RegisterHook,path,before,after)
    else registered,pre,post=pcall(RegisterHook,path,before) end
    if registered and type(pre)=='number' and type(post)=='number' then
        hooks[#hooks+1]={path,pre,post}
        log.trace('hooked ',path)
        return true
    end
    if not spec.optional then error(registered and 'hook unavailable: '..path or pre,0) end
    log.warn('optional hook unavailable: ',path,' ',registered and '' or pre)
    return false
end

function M.loaded(onCleanup)
    assert(not active,'Preymonition session is already active')
    hooks={}
    -- Register release first so a partial registration is still undone.
    onCleanup(function()
        stop()
        local failures={}
        for index=#hooks,1,-1 do
            local hook=hooks[index]
            local ok,why=pcall(UnregisterHook,hook[1],hook[2],hook[3])
            if ok then table.remove(hooks,index) else failures[#failures+1]=tostring(why) end
        end
        if #failures>0 then error('hook removal failed: '..table.concat(failures,'; '),0) end
        log.debug('hooks removed')
        return true
    end)
    active=true
    token=token+1
    for _,spec in ipairs(HOOKS) do register(spec) end
    log.debug(#hooks,' hooks registered; animation steps ',frames() and 'every frame' or 'by ExecuteWithDelay')
end

function M.attach(hud,layer,params,onCleanup,preview)
    local settings=params.settings or {}
    local record={detached=false,preview=preview==true,
        sounds={arrow=Sound.ARROW[settings.ArrowsSound],skull=Sound.UNBLOCKABLE[settings.UnblockableSound]}}
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
    })
    record.model:step()
    cues[#cues+1]=record
    log.info('cue attached, size ',(params.settings or {}).CueS or 20,'%, screen ',
        params.screen.width,'x',params.screen.height,' @',params.screen.scale,
        record.preview and ', preview' or '','; shield ',ui.sprite or 'not found yet',
        '; flash ',ui.flash or 'texture not found')
    if record.preview then
        styleShield(record)
        if record.model:show(1,'preview') then pump(record) end
    end
end

return M
