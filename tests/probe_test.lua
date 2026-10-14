package.preload['preymonition.cue'] = function()
    return {
        path = function(object) return object.path end,
        pass = function(callback, ...) return pcall(callback, ...) end,
    }
end
local Probe = dofile('Preymonition/Scripts/preymonition/probe.lua')

local function param(value) return { get = function() return value end } end
local function name(text) return { ToString = function() return text end } end

local lines = {}
local log = {}
for _, level in ipairs({ 'debug', 'info', 'warn' }) do
    log[level] = function(...) lines[#lines + 1] = level:upper() .. ' ' .. table.concat({ ... }) end
end

local hooks, ids, failing = {}, 0, 'UpdateAttackWarning'
function RegisterHook(path, callback)
    if failing and path:find(failing, 1, true) then error('No UFunction found') end
    ids = ids + 1
    hooks[path] = callback
    return ids, ids + 100
end
local function find(text)
    for _, line in ipairs(lines) do if line:find(text, 1, true) then return line end end
end

-- A hook that fails to register leaves the others hooked.
Probe.start(log)
assert(find('WARN probe could not hook /Script/Dawnwalker.DawnwalkerPlayerCharacter:UpdateAttackWarning: '),
    'a failed hook logs why')
assert(find('INFO probe hooked /Script/DogwoodUI.CombatWarningAttackBase:ShouldShowWarning (ids 1, 101)'),
    'the others still hook and log their ids')
assert(ids == 1, 'the probe hooks nothing else')

hooks, failing = {}, nil
Probe.start(log)
hooks['/Script/Dawnwalker.DawnwalkerPlayerCharacter:UpdateAttackWarning'](
    param({ path = '/Game/Player' }), param(true), param(name('weapon_r')))
assert(find('DEBUG probe DawnwalkerPlayerCharacter:UpdateAttackWarning #1: started true, socket weapon_r, on /Game/Player'),
    'the warning logs its parameters')
hooks['/Script/DogwoodUI.CombatWarningAttackBase:ShouldShowWarning']({ get = function() error('stale') end }, nil)
assert(find('DEBUG probe CombatWarningAttackBase:ShouldShowWarning #1: active nil, visible unknown, on none'),
    'an unreadable parameter logs as none and never throws')
-- The queue: each attack with its instigator's owner, newest last.
local owner = { path = '/Game/Map.Map:PersistentLevel.Guard_1' }
local component = { IsValid = function() return true end, GetOwner = function() return owner end }
local queue = { { Direction = 2, AttackType = 1, bIsUnblockable = false, ChainCount = 0, TimePerformed = 12.5,
    Instigator = component, PlayedAttackMontage = { path = '/Game/Anim/AM_Slash.AM_Slash' } } }
function queue:GetArrayNum() return 1 end
Probe.queue(log, { path = '/Engine/Transient.WBP_CombatTargetIndicator_C_1', AttackQueue = queue }, 'show top')
assert(find('DEBUG probe queue at show top: 1 attack(s) on WBP_CombatTargetIndicator_C_1'), 'the queue logs its size')
assert(find('DEBUG probe queue  #1: direction 2, type 1, unblockable false, chain 0, at 12.50, by Guard_1, montage AM_Slash, action none'),
    'and each attack')
queue[1] = { Instigator = { IsValid = function() error('stale') end } }
Probe.queue(log, { path = 'X', AttackQueue = queue }, 'critical top')
assert(find('DEBUG probe queue  #1: unreadable: '), 'an unreadable attack logs and never throws')
print('PASS: probe hooks log registration outcomes and each call\'s parameters')
