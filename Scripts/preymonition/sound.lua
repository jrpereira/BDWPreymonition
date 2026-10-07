-- The game's Wwise events the cue can play, posted at the player.
local Cue=require('preymonition.cue')
local MC=require('mc')

local EVENTS='/Game/Audio/AK_Events/Events/'
local function event(path)
    local name=path:match('([^/]+)$')
    return EVENTS..path..'.'..name
end

local PARRY=event('SFX/Weapons/Weapons_MC/Weapons_MC_Parries/WPN_MC_Parry_Sword_Long')
local TIME=event('UI/UI_Notifications/UI_HUD_TimePushWarning')
local FOCUS=event('UI/Gameplay/Focus_Mode/sfx_focusmode_start')
local DEATH=event('UI/UI_Notifications/UI_Player_Death_Stinger')

local M={
    -- Setting value to label and to event; 0 plays nothing.
    ARROW_LABELS={[0]='None',[1]='Parry',[2]='Time',[3]='Focus'},
    ARROW={[1]=PARRY,[2]=TIME,[3]=FOCUS},
    UNBLOCKABLE_LABELS={[0]='None',[1]='Time',[2]='Focus',[3]='Death'},
    UNBLOCKABLE={[1]=TIME,[2]=FOCUS,[3]=DEATH},
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
