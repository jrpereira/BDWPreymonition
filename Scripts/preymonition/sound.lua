-- The game's Wwise events the cue can play, posted at the player.
local Cue=require('preymonition.cue')
local MC=require('mc')

local EVENTS='/Game/Audio/AK_Events/Events/'
local function event(path)
    local name=path:match('([^/]+)$')
    return EVENTS..path..'.'..name
end

local SHORT_SWOOSH=event('UI/UI_Inventory/UI_Claws_Equip')
local LONG_SWOOSH=event('UI/UI_Inventory/UI_Sword_Equip')
local GROWL=event('UI/UI_Gameplay/UI_Dialogue_Select_GiveInToHunger')
local BOOM=event('UI/UI_MainMenu/UI_PauseMenu_Resume')

local M={
    -- Setting value to label and to event; 0 plays nothing.
    ARROW_LABELS={[0]='None',[1]='Short Swoosh',[2]='Long Swoosh'},
    ARROW={[1]=SHORT_SWOOSH,[2]=LONG_SWOOSH},
    UNBLOCKABLE_LABELS={[0]='None',[1]='Growl',[2]='Boom'},
    UNBLOCKABLE={[1]=GROWL,[2]=BOOM},
}

-- A sound picker's menu choices: each label, previewing its event when chosen;
-- None previews silence.
function M.choices(labels,events)
    local out={}
    for value,label in pairs(labels) do out[value]={label=label,sound=events[value] or 'none'} end
    return out
end

-- Loads an event when the cue attaches rather than at its first play, mid-combat.
function M.preload(path)
    return Cue.find(path)~=nil
end

-- Posts an event at the source actor's location, or at the player's without
-- one; context is any live object in the player's world. Errors when the
-- event, both actors or Wwise are unavailable.
function M.play(path,context,source)
    local sound=assert(Cue.find(path),'sound event unavailable: '..path)
    local wwise=assert(Cue.default('/Script/AkAudio.Default__AkGameplayStatics'),'Wwise unavailable')
    if not MC.valid(source) then
        local statics=assert(Cue.default('/Script/Engine.Default__GameplayStatics'),'GameplayStatics unavailable')
        source=statics:GetPlayerPawn(context,0)
        assert(MC.valid(source),'player unavailable')
    end
    -- Wwise answers a refused event, such as one whose bank is not loaded, with
    -- playing id 0 instead of an error.
    local id=wwise:PostEventAtLocation(sound,source:K2_GetActorLocation(),{Pitch=0,Yaw=0,Roll=0},context)
    assert(id~=0,'Wwise did not play '..path)
    return id
end

return M
