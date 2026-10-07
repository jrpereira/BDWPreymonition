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

-- An event asset, loading it when the game has not yet.
local function find(path)
    local found=Cue.resolve(path)
    if found then return found end
    if type(rawget(_G,'LoadAsset'))=='function' then pcall(LoadAsset,path) end
    return Cue.resolve(path)
end

-- Posts an event at the player's location; context is any live object in the
-- player's world. Errors when the event, the player or Wwise is unavailable.
function M.play(path,context)
    local sound=assert(find(path),'sound event unavailable: '..path)
    local wwise=assert(Cue.resolve('/Script/AkAudio.Default__AkGameplayStatics'),'Wwise unavailable')
    local statics=assert(Cue.resolve('/Script/Engine.Default__GameplayStatics'),'GameplayStatics unavailable')
    local pawn=statics:GetPlayerPawn(context,0)
    assert(MC.valid(pawn),'player unavailable')
    wwise:PostEventAtLocation(sound,pawn:K2_GetActorLocation(),{Pitch=0,Yaw=0,Roll=0},context)
end

return M
