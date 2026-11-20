local Animation = dofile('Preymonition/Scripts/preymonition/omens_animation.lua')
local time, applications = 0, 0
local model = Animation.new({
    now = function() return time end,
    apply = function() applications = applications + 1 end,
})
local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.000001, tostring(actual) .. ' ~= ' .. tostring(expected))
end
local function arrow(index) return model.arrows[index] end

assert(model.opacity == 0 and arrow(1).grow == 0 and arrow(1).offset == 0)

-- A detected arrow shows at once at full opacity at its starting size, then grows to
-- its grown size, the critical size, while travelling outward over 0.2s.
assert(model:show(1))
near(arrow(1).opacity, 1); near(arrow(1).grow, 0); near(arrow(1).offset, 0)
time = 0.1; model:step()
near(model.opacity, 1); near(arrow(1).grow, 0.5); near(arrow(1).offset, 0.5)
time = 0.25; model:step()
near(arrow(1).opacity, 1); near(arrow(1).grow, 1); near(arrow(1).offset, 1)
time = 0.3
assert(not model:has_jobs(), 'a delayed step catches up to the absolute deadline')

-- Another arrow puts the first out at once.
assert(model:show(2))
near(arrow(1).opacity, 0); near(arrow(1).grow, 0); near(arrow(1).offset, 0)
near(arrow(2).opacity, 1)

-- Critical: at once its grown size, held until resolved, with nothing left to
-- animate once its travel ends. The travel carries on.
time = 0.4; model:step()
assert(model:critical(2))
near(arrow(2).grow, 1); near(arrow(2).opacity, 1)
time = 0.45; model:step(); near(arrow(2).grow, 1); near(arrow(2).offset, 0.75)
time = 0.5; model:step(); near(arrow(2).grow, 1); near(arrow(2).offset, 1)
time = 0.6; model:step()
assert(not model:has_jobs(), 'a critical arrow needs no frames once still')

-- Resolved: the arrow goes at once and the idle cue stays.
assert(model:hide(false))
near(arrow(2).opacity, 0); near(arrow(2).grow, 0); near(arrow(2).offset, 0); near(model.opacity, 1)
assert(not model:has_jobs())

-- Combat end puts arrows and the cue out at once: nothing shows in it to fade.
time = 1.3
assert(model:show(3))
assert(model:critical(3))
assert(model:hide(true))
near(arrow(3).opacity, 0); near(arrow(3).grow, 0); near(model.opacity, 0)
assert(not model:hide(false), 'ordinary hide must not reverse combat-end intent')
assert(not model:has_jobs(), 'combat end needs no frames')

-- Combat start shows the idle cue at once, without an arrow.
time = 2.3
assert(model:engage())
near(model.opacity, 1); near(arrow(3).opacity, 0)
assert(not model:has_jobs(), 'combat start needs no frames')
assert(not model:engage(), 'an idle cue is already showing')
assert(model:show(4), 'a later valid attack may show after combat end')
time = 2.8; model:step()
near(arrow(4).opacity, 1); near(arrow(4).grow, 1); near(arrow(4).offset, 1)
assert(applications > 0)
local grown = Animation.new({ now = function() return time end, apply = function() end })
-- A held attack counts as shown but its arrow waits at rest; reveal starts its
-- travel and growth.
time = 3.4; assert(grown:show(1, 'held'))
assert(grown.arrows[1].held and grown.arrows[1].opacity == 1 and not grown.tracks.grow1,
    'a held arrow waits at rest')
time = 3.45; assert(grown:reveal(1) and not grown.arrows[1].held, 'reveal starts it')
time = 3.55; grown:step(); near(grown.arrows[1].grow, 0.5)
assert(not grown:reveal(1), 'only a held arrow is revealed')
-- A held arrow given a share grows and travels that share of its way, at a whole
-- animation's pace; reveal carries it on from there to the end at that pace.
time = 3.46; assert(grown:show(2, 'held', 0.3))
time = 3.49; grown:step(); near(grown.arrows[2].grow, 0.15); near(grown.arrows[2].offset, 0.15)
time = 3.6; grown:step(); near(grown.arrows[2].grow, 0.3); near(grown.arrows[2].offset, 0.3)
assert(grown:reveal(2)); near(grown.arrows[2].grow, 0.3); near(grown.arrows[2].offset, 0.3)
time = 3.67; grown:step(); near(grown.arrows[2].grow, 0.65); near(grown.arrows[2].offset, 0.65)
time = 3.74; grown:step(); near(grown.arrows[2].grow, 1); near(grown.arrows[2].offset, 1)
-- A held arrow given the whole way has nothing left to carry on.
time = 3.8; assert(grown:show(4, 'held', 1))
time = 4; grown:step(); assert(grown:reveal(4) and not grown.tracks.grow4 and not grown.tracks.offset4)
near(grown.arrows[4].offset, 1)
-- An attack first seen critical starts its whole show then: the arrow
-- travels and grows from its start.
time = 3.5; grown:show(3, 'critical')
assert(grown.arrows[3].grow == 0 and grown.arrows[3].offset == 0, 'critical from its start')
time = 3.6; grown:step(); near(grown.arrows[3].grow, 0.5)
time = 3.7; grown:step(); near(grown.arrows[3].offset, 1)
-- The unblockable skull grows from its starting to its grown size over 0.2s;
-- passing resets it.
time = 4; grown:unblockable(true); near(grown.skull.grow, 0)
time = 4.1; grown:step(); near(grown.skull.grow, 0.5)
time = 4.3; grown:step(); near(grown.skull.grow, 1)
grown:unblockable(false); near(grown.skull.grow, 0)
assert(not grown.tracks.skullGrow, 'a passed skull needs no frames')
-- The cue sets the duration: the next attack travels over it.
local timed = Animation.new({ now = function() return time end, apply = function() end })
timed:setDuration(0.126)
time = 5; timed:show(1)
time = 5.063; timed:step(); near(timed.arrows[1].offset, 0.5)
time = 5.126; timed:step(); near(timed.arrows[1].offset, 1)
print('PASS: arrow travel, critical hold, resolve, combat end and start, held and critical shows, growing skull, set duration')
