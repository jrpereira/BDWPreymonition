-- Pure animation timeline for the Preymonition cue.
local M = {}

-- An attack's arrow: shown (opacity 1), its grow goes from 0 (its starting size)
-- to 1 (its grown size) while it travels outward over the animation's duration:
-- TRAVEL seconds unless the cue sets its own. The cue turns grow into a size and
-- the travel into the arrow's own opacity (its Opacity range). It ends at the size
-- a critical arrow has, so turning critical only turns it red.
--
-- opacity is the cue's: 0 out of combat, 1 in combat (the idle cue). The cue's
-- arrows take it as it is, so an arrow shows at its own opacity alone.
local TRAVEL = 0.2
-- A critical arrow takes its grown size at once, if its travel has not reached
-- it, and holds it until the attack resolves.
local CRITICAL = 1
-- The unblockable skull's grow goes from 0 (its starting size) to 1 (its grown
-- size); the cue turns it into a size.

local function clamp(value)
    return math.max(0, math.min(1, value))
end

function M.new(env)
    assert(type(env) == 'table' and type(env.now) == 'function' and type(env.apply) == 'function',
        'Animation requires now and apply callbacks')
    local state = {
        opacity = 0, arrows = {}, tracks = {}, ended = false,
        -- Seconds each attack's animation takes; setDuration changes it.
        duration = TRAVEL,
        -- The unblockable skull's growth while it shows, 0 to 1.
        skull = { grow = 0 },
    }
    -- offset is the share of the arrow's outward travel, 0 at rest to 1.
    for index = 1, 4 do
        state.arrows[index] = { opacity = 0, grow = 0, offset = 0 }
    end

    -- A track takes object[field] from from to target over duration seconds from
    -- start, then ends.
    local function track(key, object, field, from, target, start, duration)
        state.tracks[key] = { object = object, field = field, from = from, target = target,
            start = start, duration = duration }
    end

    -- Puts an arrow out at once, back at rest.
    local function vanish(index)
        local arrow = state.arrows[index]
        for _, field in ipairs({ 'grow', 'offset' }) do state.tracks[field .. index] = nil end
        arrow.opacity, arrow.grow, arrow.offset, arrow.held = 0, 0, 0, nil
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
        for key, job in pairs(self.tracks) do
            if timestamp >= job.start + job.duration - 1e-9 then
                job.object[job.field] = job.target
                -- Clearing a field during pairs is allowed.
                self.tracks[key] = nil
            else
                local alpha = clamp((timestamp - job.start) / job.duration)
                job.object[job.field] = job.from + (job.target - job.from) * alpha
            end
        end
        if not quiet then env.apply(self) end
        return self:has_jobs()
    end

    -- Starts an arrow's growth and travel from rest, now.
    local function travel(self, index)
        local selected = self.arrows[index]
        selected.grow, selected.offset = 0, 0
        track('grow' .. index, selected, 'grow', 0, 1, self.time, self.duration)
        track('offset' .. index, selected, 'offset', 0, 1, self.time, self.duration)
    end

    -- Carries an arrow's growth and travel on from where they are to target,
    -- at the pace of a whole animation: a share of the way takes that share of
    -- the duration.
    local function carry(self, index, target)
        local selected = self.arrows[index]
        for _, field in ipairs({ 'grow', 'offset' }) do
            local from = selected[field]
            self.tracks[field .. index] = nil
            if from < target then
                track(field .. index, selected, field, from, target, self.time, self.duration * (target - from))
            end
        end
    end

    -- An attack: its arrow shows at once at its starting size, then grows and
    -- travels outward. Any other arrow goes at once. mode 'held' holds the
    -- attack's yellow arrow back until reveal: it grows and travels share of
    -- its way (both size and movement), or stays at rest without it; 'critical' shows an attack first seen critical, its arrow
    -- travelling from rest.
    function state:show(index, mode, share)
        assert(self.arrows[index], 'Invalid arrow index')
        self:step(true)
        self.ended = false

        local container = self.tracks.container
        if self.opacity < 1 or (container and container.target < 1) then
            track('container', self, 'opacity', self.opacity, 1, self.time, 0.1)
        end
        for current = 1, #self.arrows do vanish(current) end
        local selected = self.arrows[index]
        selected.opacity = 1
        if mode == 'held' then
            selected.held = true
            selected.grow, selected.offset = 0, 0
            if share and share > 0 then carry(self, index, share) end
        else
            travel(self, index)
        end
        env.apply(self)
        return true
    end

    -- A held arrow's attack went critical: the arrow carries its growth and
    -- travel on from where its held share left them to the end. False when it
    -- was not held.
    function state:reveal(index)
        local arrow = assert(self.arrows[index], 'Invalid arrow index')
        if not arrow.held then return false end
        self:step(true)
        arrow.held = nil
        carry(self, index, 1)
        env.apply(self)
        return true
    end

    -- The attack went critical: the arrow jumps to its critical size and holds
    -- it until the attack resolves. Its travel carries on if unfinished.
    function state:critical(index)
        local arrow = assert(self.arrows[index], 'Invalid arrow index')
        self:step(true)
        self.tracks['grow' .. index] = nil
        arrow.opacity, arrow.grow = 1, CRITICAL
        env.apply(self)
        return true
    end

    -- Combat started: the idle cue shows at once, without lighting an arrow.
    -- Nothing in it shows until an attack, so a fade would change nothing on
    -- screen. False when it already showed.
    function state:engage()
        self:step(true)
        self.ended = false
        self.tracks.container = nil
        local changed = self.opacity ~= 1
        self.opacity = 1
        env.apply(self)
        return changed
    end

    -- An unblockable attack: the skull grows from its starting to its grown size;
    -- when it passes, it is back at its starting size for next time.
    function state:unblockable(shown)
        self:step(true)
        self.tracks.skullGrow = nil
        self.skull.grow = 0
        if shown then
            track('skullGrow', self.skull, 'grow', 0, 1, self.time, self.duration)
        end
        env.apply(self)
        return true
    end

    -- The attack resolved: every arrow goes at once and the idle cue stays. At
    -- combat end the cue itself also goes at once: with its arrows out and the
    -- skull cleared, a fade would change nothing on screen.
    function state:hide(combat_end)
        if not combat_end and self.ended then return false end
        self:step(true)
        for index = 1, #self.arrows do vanish(index) end
        if combat_end then
            self.ended = true
            self.tracks.container = nil
            self.opacity = 0
        end
        env.apply(self)
        return true
    end

    return state
end

return M
