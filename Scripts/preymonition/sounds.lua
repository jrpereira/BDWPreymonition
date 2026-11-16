-- The Sound Cues: takes MCT's MC_NPCAttackIndicator events and plays a sound for
-- each attack, whatever the other templates show. Attack incoming plays when an
-- attack is first seen (its parry window opens, the yellow arrow), Perfect
-- opportunity when its perfect opportunity window opens (the red arrow), and
-- Unblockable Attack when an unblockable attack comes. preymonition.sound loads
-- and plays the files through UE4SSLuaSoundBridge.
local Sound=require('preymonition.sound')

local records={}
-- Whether combat is on: game events arrive only while it is.
local active=false
local M={}

local function silent() end
local log={enabled=function() return false end}
for _,name in ipairs({'trace','debug','info','warn','error','critical'}) do log[name]=silent end
function M.setLog(logger) log=logger end

-- Failures are logged once per kind; repeats are counted when combat ends.
local failures={}
local function fail(kind,why)
    local count=failures[kind]
    failures[kind]=(count or 0)+1
    if not count then log.error('sound cues ',kind,' failed: ',why) end
end

-- Plays one of a record's sounds, when one is chosen, for an arrow direction
-- (nil: centred). A failure is reported once per sound and never stops the rest.
local failedSounds={}
local function play(record,path,direction)
    if not path or record.silent then return end
    local ok,why=pcall(Sound.play,path,direction,record.how)
    if not ok then
        if not failedSounds[path] then
            failedSounds[path]=true
            log.warn('sound unavailable: ',why)
        end
        return
    end
    log.trace('sound ',path,' play id ',why)
end

-- A preview event (ModCore Templates' live preview in the mod menu) reaches only
-- the preview records, a game event only the others.
local function each(event,callback)
    local preview=event.preview==true
    for _,record in ipairs(records) do
        if record.preview==preview then callback(record) end
    end
end

local function forget(record)
    record.source,record.direction,record.critical,record.paths=nil,nil,nil,nil
end

-- An attack in the direction of the one still open counts as that one, whatever
-- its indicator: the game sometimes reports one attack twice, and its sound would
-- play again. It stays open until all of them resolve.
local function same(record,event)
    if not (record.source and record.direction==event.direction) then return false end
    record.paths[event.path]=true
    return true
end
local function open(record,event)
    record.source,record.direction,record.paths=event.path,event.direction,{[event.path]=true}
end

local handlers={}

-- An attack is first seen: its parry window opens. A repeated event for the
-- same attack plays nothing again.
function handlers.arrow(event)
    each(event,function(record)
        if same(record,event) then return end
        open(record,event)
        record.critical=nil
        play(record,record.sounds.incoming,event.direction)
    end)
end

-- Its perfect opportunity window opens, once per attack. An attack first seen
-- here plays only Perfect opportunity.
function handlers.critical(event)
    each(event,function(record)
        if same(record,event) then
            if record.critical then return end
        else
            open(record,event)
        end
        record.critical=true
        play(record,record.sounds.perfect,event.direction)
    end)
end

function handlers.resolve(event)
    each(event,function(record)
        if record.paths and record.paths[event.path] then
            record.paths[event.path]=nil
            if next(record.paths)==nil then forget(record) end
        end
    end)
end

-- An unblockable attack: its sound plays centred, once until it goes.
function handlers.unblockable(event)
    each(event,function(record)
        if event.active then
            if record.skull then return end
            record.skull=true
            play(record,record.sounds.skull)
        else
            record.skull=nil
        end
    end)
end

-- One MC_NPCAttackIndicator event. Preview events run without combat.
function M.update(event)
    if not next(records) or not (active or event.preview) then return end
    -- A preview event may come silent (its sound button off, or a non-sound setting
    -- selected); the preview then plays nothing for it.
    if event.preview then
        for _,record in ipairs(records) do if record.preview then record.silent=event.silent==true end end
    end
    local handler=handlers[event.kind]
    if not handler then return end
    local ok,why=pcall(handler,event)
    if not ok then fail(event.kind,why) end
end

-- The game's Master and Effects volume scale the sounds; read at attach and
-- whenever combat starts, off the play path.
local function refreshVolume()
    local volume,why=Sound.refreshGameVolume()
    if volume then log.debug('game volume ',volume) else log.debug('game volume unreadable: ',why) end
end

function M.wake()
    if active then return end
    active=true
    refreshVolume()
end

-- Combat ended: the attacks are forgotten.
function M.sleep()
    if not active then return end
    active=false
    for _,record in ipairs(records) do
        if not record.preview then
            forget(record)
            record.skull=nil
        end
    end
    for kind,count in pairs(failures) do
        if count>1 then log.warn('sound cues ',kind,' failed ',count-1,' more times') end
    end
    failures={}
end

-- How the sounds play, from the Sound Notifications settings: Sound volume (1 as
-- recorded); Enable directional sound (pan by side, ahead and behind set apart,
-- behind muffled); Differentiate back/front by pitch, the back and front
-- percentages from as recorded as playback rates.
local function options(settings)
    local pitch=type(settings.SoundPitch)=='table' and settings.SoundPitch or {}
    return {volume=(settings.SoundVolume or 100)/100,directional=settings.SoundDirectional~=0,
        back=1+(pitch[1] or -20)/100,front=1+(pitch[2] or 20)/100}
end

function M.attach(_,params,onCleanup)
    local settings=params.settings or {}
    local record={preview=params.preview==true,how=options(settings),
        sounds={incoming=Sound.arrow(settings.SoundIncoming),perfect=Sound.arrow(settings.SoundPerfect),
            skull=Sound.unblockable(settings.SoundUnblockable)}}
    -- Chosen sounds load now rather than at their first play, mid-combat. A sound
    -- that cannot load (no sound bridge, its file gone or refused) plays nothing.
    for key,path in pairs(record.sounds) do
        local ok,why=Sound.preload(path)
        if not ok then
            log.warn('sound unavailable: ',why)
            record.sounds[key]=nil
        end
    end
    if next(record.sounds) then refreshVolume() end
    onCleanup(function()
        for index,current in ipairs(records) do
            if current==record then table.remove(records,index); break end
        end
        log.debug('sound cues detached; ',#records,' attached')
        return true
    end)
    records[#records+1]=record
    log.info(record.preview and 'preview sound cues attached' or 'sound cues attached')
end

return M
