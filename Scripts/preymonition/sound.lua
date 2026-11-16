-- The Audio Cues' sounds: the mod's own WAV files, played through UE4SSLuaSoundBridge.
-- Attack incoming and Perfect Opportunity play sounds/cue_<key>.wav and an
-- unblockable attack sounds/unblockable_<key>.wav. The menu lists them each time it opens
-- (Scripts/choices/), so a file added while the game runs is offered the next time.

-- Arrows by index: 1 top (ahead), 2 bottom (behind), 3 left, 4 right. The game's
-- left and right arrows show on the opposite sides of the screen, so each pans
-- to the side it shows on.
local PAN={nil,nil,1,-1}
-- A sound from behind is muffled as well as lower: a low-pass at this cutoff, Hz.
local BEHIND_LOWPASS=1200
-- Sounds longer than this are refused at load.
local MAX_SECONDS=3

local M={
    -- Each picker offers None, then the files listed from the sounds folder, saved
    -- by key. The menu previews only game events, so a file keeps the menu's own
    -- change sound.
    ARROW_CHOICES={
        {key='none',label='None',sound='none'},
        {from='choices/cue_sounds.lua'},
    },
    UNBLOCKABLE_CHOICES={
        {key='none',label='None',sound='none'},
        {from='choices/unblockable_sounds.lua'},
    },
}

-- A setting's key as the file it plays, sounds/<prefix><key>.wav, or nil for
-- None. A saved key whose file is gone still names its file: loading it fails,
-- and nothing plays for it.
--
-- The paths name Preymonition's own folder. ModCore Templates runs this code in its own
-- Lua state, and the Sound Bridge resolves a relative path against the mod owning the
-- calling state, so 'sounds/x.wav' would look in ModCore Templates' folder. The folder
-- comes from this file's location: a source with a drive letter is used as it is; any
-- other (relative to the game's working directory, or none) goes up from the caller's
-- folder to this mod's, a sibling in Mods.
local SOURCE=(debug.getinfo(1,'S').source or ''):gsub('^@','')
local ROOT=SOURCE:match('^(.*)[/\\][Ss]cripts[/\\]preymonition[/\\][^/\\]+$')
local FOLDER=ROOT and ROOT:match('([^/\\]+)$') or '9_ModCore_Preymonition'
if not (ROOT and ROOT:match('^%a:[/\\]')) then ROOT='../'..FOLDER end
ROOT=ROOT:gsub('\\','/')
local function file(prefix,key)
    if type(key)~='string' or key=='none' or not key:match('^[%w_]+$') then return nil end
    return ROOT..'/sounds/'..prefix..key:lower()..'.wav'
end
M.ROOT=ROOT
function M.arrow(key) return file('cue_',key) end
function M.unblockable(key) return file('unblockable_',key) end

-- The game's audio settings, by ERebelSetting value: Master and Effects
-- volume sliders (0 to 100) and the Mute switch.
local MASTER,EFFECTS,MUTE=1,3,10
-- The sound bridge plays outside the game's audio engine, so the game's own
-- volume is applied here: Master times Effects, 0 when muted. 1 until read.
local gameVolume=1
local userSettings

local function readSetting(id)
    local out={}
    if not userSettings:GetSetting(id,out) then return nil end
    return tonumber(out.OutSettingValue)
end

-- Rereads the game's volume; returns it, or nil and why when it cannot be read
-- (the last value read stays in use).
function M.refreshGameVolume()
    local ok,result=pcall(function()
        if not (userSettings and userSettings:IsValid()) then
            userSettings=nil
            local find=rawget(_G,'FindFirstOf')
            local found=find and find('RebelGameUserSettings')
            if not (found and found:IsValid()) then error('game settings unavailable',0) end
            userSettings=found
        end
        local master,effects=readSetting(MASTER),readSetting(EFFECTS)
        if not (master and effects) then error('volume settings unreadable',0) end
        local muted={}
        if userSettings:GetSettingAsBool(MUTE,muted) and muted.OutSettingBool then return 0 end
        return math.max(0,math.min(1,master/100))*math.max(0,math.min(1,effects/100))
    end)
    if not ok then return nil,result end
    gameVolume=result
    return result
end

-- This Lua state's sound bridge environment, or nil and why: it must load any path
-- (1.1.0, capability paths="any"), as Preymonition's sounds are outside the folder of
-- the mod whose state runs this code.
local function bridge()
    local Bridge=rawget(_G,'UE4SSLuaSoundBridge')
    if Bridge==nil then return nil,'UE4SSLuaSoundBridge is not installed' end
    local ok,caps=pcall(Bridge.GetCapabilities)
    if not (ok and type(caps)=='table' and (caps.api or 0)>=1 and caps.paths=='any') then
        return nil,'UE4SSLuaSoundBridge 1.1.0 or newer is required'
    end
    return Bridge()
end

-- Loaded sounds by path, kept for the Lua state's life.
local loaded={}

-- Loads a sound when the Audio Cues attach rather than at its first play,
-- mid-combat. Returns true, or false and why.
function M.preload(path)
    if loaded[path] and not loaded[path].released then return true end
    local sounds,why=bridge()
    if not sounds then return false,why end
    local sound,code,message=sounds.Load(path,{max_seconds=MAX_SECONDS})
    if not sound then return false,path..': '..tostring(code)..' '..tostring(message) end
    loaded[path]=sound
    return true
end

-- Plays a loaded sound for an arrow direction (nil: centred, as recorded). how:
-- volume (1 as recorded, scaled by the game's Master and Effects volume); directional, which pans left and right arrows to their
-- side and sets ahead and behind apart; and front and back, the pitch (playback
-- rate, 1 as recorded) of an up and a down arrow. Behind is also muffled. Errors
-- when the sound is not loaded or the bridge refuses it; returns the play id.
function M.play(path,direction,how)
    local sound=assert(loaded[path],'sound not loaded: '..path)
    local options={volume=how.volume*gameVolume}
    if how.directional then
        options.pan=PAN[direction]
        if direction==1 then options.pitch=how.front end
        if direction==2 then options.pitch,options.lowpass=how.back,BEHIND_LOWPASS end
    end
    local id,code,message=sound:Play(options)
    assert(id,tostring(code)..' '..tostring(message))
    return id
end

return M
