local Animation = dofile('Preymonition/Scripts/preymonition/animation.lua')
local time, applications = 0, 0
local model = Animation.new({
    now = function() return time end,
    apply = function() applications = applications + 1 end,
})
local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.000001, tostring(actual) .. ' ~= ' .. tostring(expected))
end
local function arrow(index) return model.arrows[index] end

assert(model.opacity == 0 and arrow(1).scale == 1.5 and arrow(1).offset == 0)

-- A detected arrow shows at once at full opacity and 1.5 times its size, then grows to
-- twice its size while travelling outward over 0.2s.
assert(model:show(1, 'attack-1'))
near(arrow(1).opacity, 1); near(arrow(1).scale, 1.5); near(arrow(1).offset, 0)
-- A flash shows where it appears, fading out while growing over the same travel.
assert(model.flash.index == 1); near(model.flash.opacity, 1); near(model.flash.scale, 1)
time = 0.1; model:step()
near(model.opacity, 0.5); near(arrow(1).scale, 1.75); near(arrow(1).offset, 0.5)
near(model.flash.opacity, 0.5); near(model.flash.scale, 1.25)
time = 0.25; model:step()
near(arrow(1).opacity, 1); near(arrow(1).scale, 2); near(arrow(1).offset, 1)
near(model.flash.opacity, 0); near(model.flash.scale, 1.5)
assert(not model:has_jobs(), 'a delayed step catches up to the absolute deadline')
assert(not model:show(1, 'attack-1'), 'duplicate event identity must be ignored')

-- Another arrow puts the first out at once.
assert(model:show(2, 'attack-2'))
near(arrow(1).opacity, 0); near(arrow(1).scale, 1.5); near(arrow(1).offset, 0)
near(arrow(2).opacity, 1)

-- Critical: at once 2.5 times, held until resolved, with nothing left to
-- animate once its travel ends. The travel carries on.
time = 0.35; model:step()
assert(model:critical(2))
near(arrow(2).scale, 2.5); near(arrow(2).opacity, 1)
time = 0.4; model:step(); near(arrow(2).scale, 2.5); near(arrow(2).offset, 0.75)
time = 0.5; model:step(); near(arrow(2).scale, 2.5); near(arrow(2).offset, 1)
assert(not model:has_jobs(), 'a critical arrow needs no frames once still')

-- Resolved: the arrow goes at once and the idle cue stays.
assert(model:hide(false))
near(arrow(2).opacity, 0); near(arrow(2).scale, 1.5); near(arrow(2).offset, 0); near(model.opacity, 0.5)
assert(not model:has_jobs())

-- Combat end puts arrows out at once and fades the cue over one second.
time = 1.3
assert(model:show(3, 'attack-3'))
assert(model:critical(3))
assert(model:hide(true))
near(arrow(3).opacity, 0); near(arrow(3).scale, 1.5); near(model.flash.opacity, 0)
time = 1.8; model:step(); near(model.opacity, 0.25)
time = 2.3; model:step(); near(model.opacity, 0)
assert(not model:hide(false), 'ordinary hide must not reverse combat-end intent')
assert(not model:has_jobs())

-- Combat start fades the idle cue in over 0.2s, once, without an arrow.
assert(model:engage())
time = 2.4; model:step(); near(model.opacity, 0.25)
time = 2.55; model:step(); near(model.opacity, 0.5); near(arrow(3).opacity, 0)
assert(not model:engage(), 'an idle cue needs no second fade-in')
assert(model:show(4, 'attack-4'), 'a later valid attack may show after combat end')
time = 2.8; model:step()
near(arrow(4).opacity, 1); near(arrow(4).scale, 2); near(arrow(4).offset, 1)
assert(applications > 0)
print('PASS: arrow travel and flash, critical hold, resolve, combat end and start')
