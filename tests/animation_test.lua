local Animation = dofile('Preymonition/Scripts/preymonition/animation.lua')
local time, applications = 0, 0
local model = Animation.new({
    now = function() return time end,
    apply = function() applications = applications + 1 end,
})
local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.000001, tostring(actual) .. ' ~= ' .. tostring(expected))
end

assert(model.opacity == 0 and model.arrows[1].scale == 0.5)
assert(model:show(1, 'attack-1'))
time = 0.1; model:step(); near(model.opacity, 0.5)
time = 0.3; model:step(); near(model.arrows[1].opacity, 1); near(model.arrows[1].scale, 1)
time = 0.8; model:step(); near(model.arrows[1].scale, 0.8)
assert(not model:has_jobs(), 'delayed step must catch up to the absolute settle deadline')
assert(not model:show(1, 'attack-1'), 'duplicate event identity must be ignored')

-- A new attack in the same direction finishes the old cue before restarting it.
assert(model:show(1, 'attack-2'))
time = 0.85; model:step(); near(model.arrows[1].opacity, 0.5); near(model.arrows[1].scale, 0.65)
time = 0.9; model:step(); near(model.arrows[1].opacity, 0); near(model.arrows[1].scale, 0.5)
time = 1.2; model:step(); near(model.arrows[1].opacity, 1); near(model.arrows[1].scale, 1)
time = 1.4; model:step(); near(model.arrows[1].scale, 0.8)

-- A different direction cross-fades while rapid interruption cancels stale tracks.
assert(model:show(2, 'attack-3'))
time = 1.45; model:step()
assert(model.arrows[1].opacity < 1 and model.arrows[2].opacity > 0)
assert(model:show(3, 'attack-4'))
time = 2.2; model:step()
near(model.arrows[1].opacity, 0); near(model.arrows[2].opacity, 0)
near(model.arrows[3].opacity, 1); near(model.arrows[3].scale, 0.8)
assert(not model:has_jobs())

assert(model:hide(true))
time = 2.4; model:step(); near(model.opacity, 0)
near(model.arrows[3].opacity, 0); near(model.arrows[3].scale, 0.5)
assert(not model:hide(false), 'ordinary hide must not reverse combat-end intent')
assert(not model:has_jobs())
assert(model:show(4, 'attack-5'), 'a later valid attack may restart after combat end')
time = 3.0; model:step(); near(model.opacity, 0.5); near(model.arrows[4].scale, 0.8)
assert(applications > 0)
print('PASS: absolute animation timing, interruption, same-direction retrigger, and combat-end precedence')
