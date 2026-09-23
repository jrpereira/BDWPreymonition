local Animation = dofile('Scripts/animation.lua')
local Events = dofile('Scripts/events.lua')
local Feature = dofile('Scripts/feature.lua')

local function fixture(fail_delay, fail_unregister)
    local time, delayed, callbacks, logs = 0, {}, {}, {}
    local source = { direction = 1, visible = true, combat = true }
    local ui = { valid = true, destroyed = false }
    local adapter = {}
    function adapter.defer(milliseconds, callback)
        if fail_delay then error('scheduler unavailable') end
        delayed[#delayed + 1] = { milliseconds = milliseconds, callback = callback }
    end
    function adapter.game_thread(callback) callback() end
    function adapter.register_hook(path, callback)
        callbacks[#callbacks + 1] = callback
        return { path = path }
    end
    function adapter.unregister_hook()
        if fail_unregister then error('simulated unregister failure') end
    end
    function adapter.initial_sources() return {} end
    function adapter.resolve_source(path) return path == 'source' and source or (path == 'component' and source or nil) end
    function adapter.source_visible(value) return value.visible end
    function adapter.source_direction(value) return value.direction end
    function adapter.combat_state(value) return value.combat end
    function adapter.combat_ended(path) return path == 'component' and source.combat == false end
    function adapter.ensure_ui(_, current) return ui, current ~= ui end
    function adapter.valid_ui(value) return value.valid end
    function adapter.destroy_ui(value) value.destroyed = true end
    function adapter.now() return time end
    function adapter.apply(_, state) ui.opacity = state.opacity end
    local feature = Feature.new(function(message) logs[#logs + 1] = message end,
        Animation, Events, adapter)
    local function run_next(at)
        assert(#delayed > 0, 'expected deferred callback')
        time = at or time
        table.remove(delayed, 1).callback()
    end
    return {
        feature = feature, callbacks = callbacks, delayed = delayed, source = source, ui = ui,
        logs = logs, run_next = run_next, set_time = function(value) time = value end,
    }
end

local f = fixture(false)
assert(f.feature:start())
assert(#f.callbacks == 3, 'all native hooks must register')
f.callbacks[1](nil) -- path values are supplied by the adapter in production
assert(#f.delayed == 0, 'invalid callback path is ignored')
f.feature:queue_event('show', 'source')
f.feature:queue_event('show', 'source')
assert(#f.delayed == 1, 'hook work must share one event scheduler')
f.run_next(0)
assert(f.feature.stats.shows == 1 and #f.delayed == 1)
f.run_next(0.8)
assert(not f.feature.model:has_jobs())

f.feature:queue_event('show', 'source')
f.run_next(1)
f.run_next(1.1)
assert(f.feature.stats.shows == 2, 'same direction with a new event identity must retrigger')
f.run_next(1.7)
f.feature:queue_event('clear', 'source')
f.feature:queue_event('clear', 'source')
f.run_next(2)
assert(f.feature.stats.clears == 1, 'duplicate clear notifications must coalesce')
f.run_next(2.3)

f.source.combat = false
f.feature:queue_event('combat_end', 'component')
f.run_next(3)
assert(f.feature.stats.combat_ends == 1)
f.feature:queue_event('show', 'source')
f.run_next(3.3)
f.run_next(3.3)
assert(f.feature.stats.shows == 2, 'stale post-combat detection must not reopen the HUD')

-- Invalidating the HUD cancels the single animation pump without retry loops.
f.source.combat = true
f.feature:queue_event('show', 'source')
f.run_next(4)
f.ui.valid = false
f.run_next(4.05)
assert(f.feature.ui == nil and #f.delayed == 0, 'destroyed HUD must cancel pending animation work')

-- Deferred callbacks become inert after stop.
f.feature:queue_event('show', 'source')
f.feature:stop()
while #f.delayed > 0 do f.run_next(5) end
assert(not f.feature.active and #f.feature.hooks == 0)

local failed = fixture(true)
failed.feature:start()
failed.feature:queue_event('show', 'source')
assert(failed.feature.last_error and failed.feature.last_error:match('scheduler unavailable'))
assert(not failed.feature.event_pending and #failed.feature.queue.items == 1)
failed.feature:stop()

local unsafe = fixture(false, true)
unsafe.feature:start()
local stopped, stop_error = pcall(function() unsafe.feature:stop() end)
assert(not stopped and tostring(stop_error):match('Hook removal failed'))
assert(not unsafe.feature.active and #unsafe.feature.hooks == 3,
    'failed hook handles must remain available for a later cleanup attempt')
local restarted, restart_error = pcall(function() unsafe.feature:start() end)
assert(not restarted and tostring(restart_error):match('pending removal'),
    'failed hook cleanup must block duplicate registration')
print('PASS: hook coalescing, stale-event rejection, HUD replacement, stop safety, and scheduler failure')
