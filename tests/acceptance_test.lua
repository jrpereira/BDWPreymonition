-- The cue names objects by path; StaticFindObject resolves the bridge's paths.
package.preload['preymonition.cue'] = function()
    return {
        path = function(object) return object.path end,
        resolve = function(path) return StaticFindObject(path) end,
    }
end
local Acceptance = dofile('Preymonition/Scripts/preymonition/acceptance.lua')

local TARGET = '/Game/_Dawnwalker/UI/_Unified/Combat/WBP_CombatTargetIndicator.WBP_CombatTargetIndicator_C:OnObservedStubIconTypeChanged'
local INDICATOR = '/Engine/Transient.GameEngine_0:BP_DawnwalkerGameInstance_C_0.WBP_CombatTargetIndicator_C_2'

local printed, logged = {}, {}
function print(text) printed[#printed + 1] = text end
local log = {}
for _, level in ipairs({ 'info', 'warn' }) do
    log[level] = function(...) logged[#logged + 1] = level:upper() .. ' ' .. table.concat({ ... }) end
end
local function last() return (printed[#printed] or ''):gsub('\n$', '') end

-- Off until started: detections write nothing.
Acceptance.detect('arrow', INDICATOR)
assert(#printed == 0 and not Acceptance.enabled(), 'the aid is silent until started')

-- No bridge: the aid still writes DETECT lines, without a frame, and warns once.
Acceptance.start(log)
Acceptance.start(log)
assert(#logged == 1 and logged[1]:find('hooks unavailable', 1, true), 'a missing bridge is reported once')
os.clock = function() return 12.5 end
Acceptance.detect('arrow', INDICATOR)
assert(last() == '[Preymonition] DETECT t=12.5000 kind=arrow path=' .. INDICATOR, 'DETECT without the bridge: ' .. last())
Acceptance.detect('resolve', nil)
assert(#printed == 1, 'a detection without a path writes nothing')

-- The bridge arrives: the indicator hook registers once, on the game thread.
local hooked, ticks, onGameThread = {}, 812, false
UE4SSLuaEventBridge = { Hooks = {
    Hook = function(target, options)
        assert(onGameThread, 'hooks register on the game thread')
        hooked[#hooked + 1] = { target = target, options = options }
        return { Status = function()
            return { state = 'active', calls = 4, matched = 4, delivered = 4, dropped = 0, reentries = 0 }
        end }
    end,
    GetStats = function()
        return { ticks = ticks, queued = 0, high_water = 3, rejected = 0, delivery = 'tick', entries = 1,
            slots = { a = 0x5B, b = 0x5C } }
    end,
} }
function ExecuteInGameThread(callback) onGameThread = true; callback(); onGameThread = false end
local fresh = dofile('Preymonition/Scripts/preymonition/acceptance.lua')
fresh.start(log)
fresh.start(log)
assert(#hooked == 1 and hooked[1].target == TARGET, 'the indicator icon change is hooked once')
local options = hooked[1].options
assert(options.params[1] == 'IconType' and options.object_paths == true and options.post and not options.pre,
    'only IconType, with object paths, after the call')

-- DETECT carries the bridge's frame counter.
fresh.detect('critical', INDICATOR)
assert(last() == '[Preymonition] DETECT t=12.5000 frame=812 kind=critical path=' .. INDICATOR, last())

-- A hook call: the enum's value and the indicator's path as the cue names it.
local widget = { path = INDICATOR }
function StaticFindObject(path) return path == 'bridge:' .. INDICATOR and widget or nil end
ticks = 813
options.post({ phase = 'post', params = { IconType = { value = 6, name = 'AttackingRight_ParryWindow' } },
    object = { address = 1, path = 'bridge:' .. INDICATOR } })
assert(last() == '[hooks] t=12.5000 frame=813 phase=post icon=6 path=' .. INDICATOR, last())
-- A path the cue cannot resolve is written as the bridge gave it.
options.post({ phase = 'post', params = { IconType = 9 }, object = { path = '/Other.Path' } })
assert(last() == '[hooks] t=12.5000 frame=813 phase=post icon=9 path=/Other.Path', last())

-- Fight end: the bridge's counters and the hook's status.
fresh.report()
assert(printed[#printed - 1]:find('[hooks] stats queued=0 high_water=3 rejected=0 delivery=tick ticks=813 entries=1 slots=91,92', 1, true),
    printed[#printed - 1])
assert(last() == '[hooks] status state=active reason=nil calls=4 matched=4 delivered=4 dropped=0 reentries=0', last())

-- A hook the bridge refuses is reported once and retried at the next start.
local refusing = dofile('Preymonition/Scripts/preymonition/acceptance.lua')
UE4SSLuaEventBridge.Hooks.Hook = function() return nil, 'hooks is off' end
logged = {}
refusing.start(log)
refusing.start(log)
assert(#logged == 1 and logged[1]:find('could not hook', 1, true) and logged[1]:find('hooks is off', 1, true),
    'a refused hook is reported once: ' .. tostring(logged[1]))

print = function(...) io.write(table.concat({ ... }, '\t'), '\n') end
print('PASS: acceptance aid writes DETECT and hook lines with clock, frame and path, hooks once, reports at fight end')
