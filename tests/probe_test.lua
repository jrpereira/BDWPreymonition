package.preload['preymonition.cue'] = function()
    return {
        path = function(object) return object.path end,
        pass = function(callback, ...) return pcall(callback, ...) end,
    }
end
local Probe = dofile('Preymonition/Scripts/preymonition/probe.lua')

local function param(value) return { get = function() return value end } end
local function name(text) return { ToString = function() return text end } end
local function actor(path) return { path = path } end

local lines = {}
local log = {}
for _, level in ipairs({ 'debug', 'info', 'warn' }) do
    log[level] = function(...) lines[#lines + 1] = level:upper() .. ' ' .. table.concat({ ... }) end
end
local function find(text)
    for _, line in ipairs(lines) do if line:find(text, 1, true) then return line end end
end
local function count(text)
    local found = 0
    for _, line in ipairs(lines) do if line:find(text, 1, true) then found = found + 1 end end
    return found
end

local PLAYER = '/Script/Dawnwalker.DawnwalkerPlayerCharacter:'
local SOUNDS = '/Script/Dawnwalker.CharacterSoundsComponent:'
local AUDIO = '/Script/Dawnwalker.AudioPlayerCombatComponent:'
local WARNING = '/Game/_Dawnwalker/UI/Combat/WBP_Combat_AttackWarning.WBP_Combat_AttackWarning_C:OnShowWarning'

-- The Blueprint warning is not loaded yet at first, as at mod start.
local hooks, ids, loaded = {}, 0, false
function RegisterHook(path, callback)
    if path == WARNING and not loaded then error('No UFunction found') end
    ids = ids + 1
    hooks[path] = callback
    return ids, ids + 100
end

Probe.start(log)
assert(find('INFO probe hooked ' .. PLAYER .. 'OnEnemyAttack (ids '), 'a registered hook logs its ids')
assert(find('WARN probe could not hook ' .. WARNING .. ': '), 'a failed hook logs why')
assert(find('INFO probe hooked ' .. SOUNDS .. 'OnHitDodged'), 'the others still hook')
local registered = ids
Probe.start(log)
assert(ids == registered and count('could not hook') == 1, 'a retry registers nothing twice and reports a failure once')
loaded = true
Probe.start(log)
assert(ids == registered + 1 and find('INFO probe hooked ' .. WARNING), 'a retry hooks the Blueprint once loaded')

local guard = actor('/Game/Map.Map:PersistentLevel.Guard_1')
local player = actor('/Game/Map.Map:PersistentLevel.BP_PlayerCharacter_C_1')
hooks[PLAYER .. 'UpdateAttackWarning'](param(player), param(true), param(name('weapon_r')))
assert(find('DEBUG probe DawnwalkerPlayerCharacter:UpdateAttackWarning #1: started true, socket weapon_r, on BP_PlayerCharacter_C_1'),
    'the warning logs its parameters')
hooks[PLAYER .. 'OnEnemyAttack'](param(player), param(guard), param(true))
assert(find('DEBUG probe DawnwalkerPlayerCharacter:OnEnemyAttack #1: active true, by Guard_1'), 'an enemy attack names its attacker')
hooks[SOUNDS .. 'OnAttackAnimationTriggered'](param({ GetOwner = function() return guard end }))
assert(find('DEBUG probe CharacterSoundsComponent:OnAttackAnimationTriggered #1: by Guard_1'), 'a swing names its owner')
hooks[AUDIO .. 'OnHitImpact'](param(player), param(2), param({}), param(1), param(guard), param(player), param(false))
assert(find('DEBUG probe AudioPlayerCombatComponent:OnHitImpact #1: strength 2, stunned false, Guard_1 on BP_PlayerCharacter_C_1'),
    'a hit names both sides')
hooks[AUDIO .. 'OnParryImpact'](param(player), param({}), param({}), param(guard), param(player))
assert(find('DEBUG probe AudioPlayerCombatComponent:OnParryImpact #1: Guard_1 on BP_PlayerCharacter_C_1'), 'and a parry')

-- The AI board's indicator states.
local BOARD = '/Script/RebelAI.RebelAIBoard:'
local board = actor('/Game/Map.Map:PersistentLevel.Guard_1.RebelAIBoard_0')
hooks[BOARD .. 'AddIndicatorState'](param(board), param({ IconType = 3 }), param(2), param(false))
assert(find('DEBUG probe RebelAIBoard:AddIndicatorState #1: icon 3, priority 2, bottom false, on /Game/Map.Map:PersistentLevel.Guard_1.RebelAIBoard_0'),
    'an added indicator state logs its icon')
hooks[BOARD .. 'ActivateParryWindowForIndicatorState'](param(board), param(7))
assert(find('DEBUG probe RebelAIBoard:ActivateParryWindowForIndicatorState #1: id 7, on '), 'the parry window logs its state id')
hooks[BOARD .. 'RemoveIndicatorState'](param(board), param(7))
assert(find('DEBUG probe RebelAIBoard:RemoveIndicatorState #1: id 7, on '), 'and the removal')

-- The helper indicator carries the attack's data.
local component = { IsValid = function() return true end, GetOwner = function() return guard end }
hooks[PLAYER .. 'ShowHelperAttackIndicator'](param(player), param({ Direction = 2, AttackType = 1,
    bIsUnblockable = false, ChainCount = 0, TimePerformed = 12.5, Instigator = component,
    PlayedAttackMontage = actor('/Game/Anim/AM_Slash.AM_Slash') }))
assert(find('DEBUG probe DawnwalkerPlayerCharacter:ShowHelperAttackIndicator #1: direction 2, type 1, unblockable false, chain 0, at 12.50, by Guard_1, montage AM_Slash'),
    'the helper indicator logs its attack')
hooks[PLAYER .. 'ShowHelperAttackIndicator'](param(player), param({ Instigator = { IsValid = function() error('stale') end } }))
assert(find('ShowHelperAttackIndicator #2: unreadable: '), 'unreadable attack data logs and never throws')

-- Unreadable parameters log as none.
hooks['/Script/DogwoodUI.CombatWarningAttackBase:ShouldShowWarning']({ get = function() error('stale') end }, nil)
assert(find('DEBUG probe CombatWarningAttackBase:ShouldShowWarning #1: active nil, visible unknown, on none'),
    'an unreadable parameter logs as none and never throws')
print('PASS: probe hooks log registration outcomes, retry, and each call\'s parameters')
