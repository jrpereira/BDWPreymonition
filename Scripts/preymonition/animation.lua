-- Pure animation timeline for the Preymonition cue.
local M = {}

-- An attack's arrow: shown at full opacity and its REST size, it grows to
-- GROWN while travelling outward over the animation's duration: TRAVEL seconds
-- unless the cue sets its own. It ends at the size a critical arrow has, so
-- turning critical only turns it red.
local REST, GROWN, TRAVEL = 1.5, 2.5, 0.2
-- A critical arrow takes this size at once, if its travel has not reached it,
-- and holds it until the attack resolves.
local CRITICAL = GROWN
-- The flash where an arrow appears fades out while growing to FLASH_GROWN,
-- over the arrow's travel.
local FLASH_GROWN = 1.5
-- A shield revealed by a critical attack, when the cue asks for growth, and the
-- unblockable skull grow to SHIELD_GROWN times their size over the same duration.
local SHIELD_GROWN = 2
-- The trail's arrows follow the same travel, each LAG of the duration behind the
-- one before.
local TRAIL, LAG = 2, 0.2

local function clamp(value)
    return math.max(0, math.min(1, value))
end

function M.new(env)
    assert(type(env) == 'table' and type(env.now) == 'function' and type(env.apply) == 'function',
        'Animation requires now and apply callbacks')
    local state = {
        opacity = 0, arrows = {}, tracks = {}, last = nil, ended = false,
        -- index names the arrow the flash belongs to; nil before the first.
        flash = { opacity = 0, scale = 1, index = nil },
        -- Seconds each attack's animation takes; setDuration changes it.
        duration = TRAVEL,
        -- critical while the shown attack is critical; scale is the revealed
        -- shield's growth.
        shield = { critical = false, scale = 1 },
        -- The unblockable skull's growth while it shows.
        skull = { scale = 1 },
        finished_keys = {}, finished_jobs = {},
    }
    -- offset is the share of the arrow's outward travel, 0 at rest to 1; trail
    -- holds the trailing arrows' offsets, nearest first.
    for index = 1, 4 do
        state.arrows[index] = { opacity = 0, scale = REST, offset = 0, trail = {} }
        for ghost = 1, TRAIL do state.arrows[index].trail[ghost] = 0 end
    end

    local function track(key, object, field, phases, after)
        state.tracks[key] = { object = object, field = field, phases = phases, after = after }
    end

    local function phase(from, target, start, duration)
        return { from = from, target = target, start = start, duration = duration }
    end

    -- Puts an arrow out at once, back at rest.
    local function vanish(index)
        local arrow = state.arrows[index]
        for _, field in ipairs({ 'opacity', 'scale', 'offset' }) do state.tracks[field .. index] = nil end
        arrow.opacity, arrow.scale, arrow.offset = 0, REST, 0
        for ghost = 1, TRAIL do
            state.tracks['trail' .. index .. '_' .. ghost] = nil
            arrow.trail[ghost] = 0
        end
    end

    -- The attack is over or replaced: the shield calms at once.
    local function calm()
        state.tracks.shieldScale = nil
        state.shield.critical, state.shield.scale = false, 1
    end

    -- Sets the animation's duration in seconds, from the next attack on.
    function state:setDuration(seconds)
        assert(type(seconds) == 'number' and seconds > 0, 'Invalid animation duration')
        self.duration = seconds
    end

    function state:has_jobs()
        return next(self.tracks) ~= nil
    end

    function state:cancel()
        self.tracks = {}
    end

    -- Advances every track to now and applies the result; quiet leaves applying
    -- to the caller, as a verb does once it has changed the state.
    function state:step(quiet)
        local timestamp = env.now()
        -- Verbs time their new tracks from the step they just took.
        self.time = timestamp
        local completed = 0
        for key, job in pairs(self.tracks) do
            local last = job.phases[#job.phases]
            local value = job.object[job.field]
            local done = timestamp >= last.start + last.duration - 1e-9
            for _, current in ipairs(job.phases) do
                if timestamp < current.start then break end
                if current.duration <= 0 or timestamp >= current.start + current.duration then
                    value = current.target
                else
                    local alpha = clamp((timestamp - current.start) / current.duration)
                    value = current.from + (current.target - current.from) * alpha
                    break
                end
            end
            job.object[job.field] = value
            if done then
                completed = completed + 1
                self.finished_keys[completed] = key
                self.finished_jobs[completed] = job
            end
        end
        for index = 1, completed do
            local key, job = self.finished_keys[index], self.finished_jobs[index]
            self.finished_keys[index], self.finished_jobs[index] = nil, nil
            if self.tracks[key] == job then
                self.tracks[key] = nil
                if job.after then job.after() end
            end
        end
        if not quiet then env.apply(self) end
        return self:has_jobs()
    end

    -- An attack: its arrow shows at once at full opacity and size, then grows
    -- and travels outward. Any other arrow goes at once.
    function state:show(index, identity)
        assert(self.arrows[index], 'Invalid arrow index')
        if self.last == identity then return false end
        self:step(true)
        local timestamp = self.time
        self.last = identity
        self.ended = false

        local container = self.tracks.container
        if self.opacity < 0.5 or (container and container.phases[#container.phases].target < 0.5) then
            track('container', self, 'opacity', { phase(self.opacity, 0.5, timestamp, 0.1) })
        end
        for current = 1, #self.arrows do vanish(current) end
        calm()
        local selected = self.arrows[index]
        selected.opacity = 1
        local flash = self.flash
        flash.index, flash.opacity, flash.scale = index, 1, 1
        track('flashOpacity', flash, 'opacity', { phase(1, 0, timestamp, self.duration) })
        track('flashScale', flash, 'scale', { phase(1, FLASH_GROWN, timestamp, self.duration) })
        track('scale' .. index, selected, 'scale', { phase(REST, GROWN, timestamp, self.duration) })
        track('offset' .. index, selected, 'offset', { phase(0, 1, timestamp, self.duration) })
        for ghost = 1, TRAIL do
            track('trail' .. index .. '_' .. ghost, selected.trail, ghost,
                { phase(0, 1, timestamp + self.duration * LAG * ghost, self.duration) })
        end
        env.apply(self)
        return true
    end

    -- The attack went critical: the arrow jumps to its critical size and holds
    -- it until the attack resolves. Its travel carries on if unfinished.
    function state:critical(index)
        local arrow = assert(self.arrows[index], 'Invalid arrow index')
        self:step(true)
        self.tracks['opacity' .. index] = nil
        self.tracks['scale' .. index] = nil
        arrow.opacity, arrow.scale = 1, CRITICAL
        if not self.shield.critical then
            self.shield.critical = true
            if env.grow then
                track('shieldScale', self.shield, 'scale', { phase(1, SHIELD_GROWN, self.time, self.duration) })
            end
        end
        env.apply(self)
        return true
    end

    -- Combat started: fade the idle cue in without lighting an arrow.
    function state:engage()
        self:step(true)
        self.ended = false
        local container = self.tracks.container
        if self.opacity >= 0.5 and not (container and container.phases[#container.phases].target < 0.5) then
            env.apply(self)
            return false
        end
        track('container', self, 'opacity', { phase(self.opacity, 0.5, self.time, 0.2) })
        env.apply(self)
        return true
    end

    -- An unblockable attack: the skull grows to twice its size like a revealed
    -- shield; when it passes, it is back at its size for next time.
    function state:unblockable(shown)
        self:step(true)
        self.tracks.skullScale = nil
        self.skull.scale = 1
        if shown then
            track('skullScale', self.skull, 'scale', { phase(1, SHIELD_GROWN, self.time, self.duration) })
        end
        env.apply(self)
        return true
    end

    -- The attack resolved: every arrow goes at once and the idle cue stays. At
    -- combat end the cue itself also fades out over a second.
    function state:hide(combat_end)
        if not combat_end and self.ended then return false end
        self:step(true)
        self.last = nil
        for index = 1, #self.arrows do vanish(index) end
        calm()
        if combat_end then
            self.ended = true
            self.tracks.flashOpacity, self.tracks.flashScale = nil, nil
            self.flash.opacity = 0
            track('container', self, 'opacity', { phase(self.opacity, 0, self.time, 1) })
        end
        env.apply(self)
        return true
    end

    return state
end

return M
