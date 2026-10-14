-- Developer probe: logs game calls that may announce or settle an attack, next
-- to the cue's own events, to compare their timing in UE4SS.log. Off unless a
-- probe.txt sits next to mod.json; hooks stay registered once made.
local Cue=require('preymonition.cue')

local M={}

local function value(param)
    if param==nil then return nil end
    local ok,result=pcall(function() return param:get() end)
    if ok then return result end
    return param
end

local function path(param)
    local object=value(param)
    return object and Cue.path(object) or 'none'
end

-- An object's last path segment, for readable lines.
local function short(object)
    local full=object and Cue.path(object)
    return full and (full:match('[.:]([^.:]+)$') or full) or 'none'
end

local function name(param)
    return short(value(param))
end

local function fname(param)
    local text=value(param)
    local ok,result=pcall(function() return text:ToString() end)
    return ok and result or tostring(text)
end

-- A component's owning actor, by short name.
local function owner(param)
    local component=value(param)
    local ok,actor=pcall(function() return component:GetOwner() end)
    return ok and short(actor) or 'unknown'
end

-- An AttackData struct: enums as numbers, objects by short name.
local function attack(data)
    local instigator
    local component=data.Instigator
    if component and component:IsValid() then instigator=component:GetOwner() end
    return string.format('direction %s, type %s, unblockable %s, chain %s, at %.2f, by %s, montage %s',
        tostring(data.Direction),tostring(data.AttackType),tostring(data.bIsUnblockable),tostring(data.ChainCount),
        tonumber(data.TimePerformed) or -1,short(instigator),short(data.PlayedAttackMontage))
end

local PLAYER='/Script/Dawnwalker.DawnwalkerPlayerCharacter:'
local SOUNDS='/Script/Dawnwalker.CharacterSoundsComponent:'
local AUDIO='/Script/Dawnwalker.AudioPlayerCombatComponent:'
local BOARD='/Script/RebelAI.RebelAIBoard:'
local INDICATOR='/Game/_Dawnwalker/UI/_Unified/Combat/WBP_CombatTargetIndicator.WBP_CombatTargetIndicator_C:'
local function by(context) return 'by ',owner(context) end
local function between(attacker,defender) return name(attacker),' on ',name(defender) end

local HOOKS={
    -- Warnings.
    {path=PLAYER..'UpdateAttackWarning',
        describe=function(context,started,socket)
            return 'started ',tostring(value(started)),', socket ',fname(socket),', on ',name(context)
        end},
    {path='/Script/DogwoodUI.CombatWarningAttackBase:ShouldShowWarning',
        describe=function(context,active)
            local widget=value(context)
            local ok,visible=pcall(function() return widget:IsVisible() end)
            return 'active ',tostring(value(active)),', visible ',ok and tostring(visible) or 'unknown',
                ', on ',name(context)
        end},
    {path=PLAYER..'OnEnemyAttack',
        describe=function(_,attacker,active) return 'active ',tostring(value(active)),', by ',name(attacker) end},
    {path='/Script/Dawnwalker.QuestConditionCharacterCombatActionType:ParryWindowOpened',
        describe=function(_,target) return 'target ',name(target) end},
    -- The AI's own indicator states: added with an icon type (direction, parry
    -- window or unblockable, ERebelIndicatorIconType), switched to the parry
    -- window, and removed, each on the attacker's AI board.
    {path=BOARD..'AddIndicatorState',
        describe=function(context,state,priority,bottom)
            local icon=value(state)
            local ok,kind=pcall(function() return icon.IconType end)
            return 'icon ',ok and tostring(kind) or 'unreadable',', priority ',tostring(value(priority)),
                ', bottom ',tostring(value(bottom)),', on ',path(context)
        end},
    {path=BOARD..'ActivateParryWindowForIndicatorState',
        describe=function(context,id) return 'id ',tostring(value(id)),', on ',path(context) end},
    {path=BOARD..'RemoveIndicatorState',
        describe=function(context,id) return 'id ',tostring(value(id)),', on ',path(context) end},
    -- The indicator Blueprint's own events, hookable with UE4SS's
    -- HookProcessInternal; loaded with the indicator, so retried at combat start.
    {path=INDICATOR..'OnObservedStubIconTypeChanged',
        describe=function(context,icon) return 'icon ',tostring(value(icon)),', on ',name(context) end},
    {path=INDICATOR..'Display Icon State Directionally',
        describe=function(context,icon) return 'icon ',tostring(value(icon)),', on ',name(context) end},
    {path=INDICATOR..'Apply Attack Style To Arrow',
        describe=function(context,arrow) return 'arrow ',name(arrow),', on ',name(context) end},
    {path=INDICATOR..'Display Unblockable Icon State',describe=function(context) return 'on ',name(context) end},
    {path=INDICATOR..'NotifyIndicatorCleared',describe=function(context) return 'on ',name(context) end},
    -- A Blueprint function: hookable only once its class is loaded, so it is
    -- retried when combat starts.
    {path='/Game/_Dawnwalker/UI/Combat/WBP_Combat_AttackWarning.WBP_Combat_AttackWarning_C:OnShowWarning',
        describe=function(context) return 'on ',path(context) end},
    -- Swings, for every character with a sounds component.
    {path=SOUNDS..'OnAttackAnimationTriggered',describe=by},
    {path=SOUNDS..'OnAttackActiveFrameEntered',describe=by},
    {path=SOUNDS..'OnAttackActiveFrameExited',describe=by},
    -- The game's helper indicator, with the attack's data.
    {path=PLAYER..'ShowHelperAttackIndicator',
        describe=function(_,data)
            local ok,text=pcall(attack,value(data))
            return ok and text or 'unreadable: '..tostring(text)
        end},
    {path=PLAYER..'UpdateHelperAttackIndicator',describe=function() return 'called' end},
    {path=PLAYER..'HideHelperAttackIndicator',describe=function() return 'called' end},
    -- How an attack ended.
    {path=PLAYER..'OnPlayerParriedAttack',describe=function(_,target) return 'target ',name(target) end},
    {path=AUDIO..'OnParryImpact',
        describe=function(_,_,_,attacker,defender) return between(attacker,defender) end},
    {path=AUDIO..'OnBlockImpact',
        describe=function(_,_,_,attacker,defender) return between(attacker,defender) end},
    {path=AUDIO..'OnHitImpact',
        describe=function(_,strength,_,_,attacker,defender,stunned)
            return 'strength ',tostring(value(strength)),', stunned ',tostring(value(stunned)),', ',
                between(attacker,defender)
        end},
    {path=SOUNDS..'OnHitDodged',
        describe=function(_,attacker,defender) return between(attacker,defender) end},
}

-- Registers every probe hook not yet registered and logs each outcome; a hook
-- that fails to register leaves the others and the cue untouched. A failure is
-- reported once; a later call retries it quietly.
function M.start(log)
    for _,hook in ipairs(HOOKS) do
        if not hook.registered then
            local label=hook.path:match('[^.]+$')
            hook.calls=hook.calls or 0
            local registered,pre,post=pcall(RegisterHook,hook.path,function(context,...)
                hook.calls=hook.calls+1
                local calls=hook.calls
                local ok,why=Cue.pass(function(...)
                    log.debug('probe ',label,' #',calls,': ',hook.describe(context,...))
                end,...)
                if not ok then log.warn('probe ',label,' #',calls,' unreadable: ',why) end
            end)
            if registered and type(pre)=='number' then
                hook.registered=true
                log.info('probe hooked ',hook.path,' (ids ',pre,', ',post,')')
            elseif not hook.reported then
                hook.reported=true
                log.warn('probe could not hook ',hook.path,': ',registered and 'no hook id' or pre)
            end
        end
    end
end

return M
