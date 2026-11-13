-- Pure animation timeline for the Preymonition cue.
local M = {}

-- An attack's arrow: shown at full opacity, its grow goes from 0 (its starting
-- size) to 1 (its grown size) while it travels outward over the animation's
-- duration: TRAVEL seconds unless the cue sets its own. The cue turns grow into a
-- size. It ends at the size a critical arrow has, so turning critical only turns it red.
local TRAVEL = 0.2
-- A critical arrow takes its grown size at once, if its travel has not reached
-- it, and holds it until the attack resolves.
local CRITICAL = 1
-- A shield revealed by a critical attack, when the cue asks for growth, grows to
-- SHIELD_GROWN times its size over the same duration. The unblockable skull's grow
-- goes from 0 (its starting size) to 1 (its grown size); the cue turns it into a size.
local SHIELD_GROWN = 2

local function clamp(value)
    return math.max(0, math.min(1, value))
end

function M.new(env)
    assert(type(env) == 'table' and type(env.now) == 'function' and type(env.apply) == 'function',
        'Animation requires now and apply callbacks')
    local state = {
        opacity = 0, arrows = {}, tracks = {}, last = nil, ended = false,
        -- Seconds each attack's animation takes; setDuration changes it.
        duration = TRAVEL,
        -- critical while the shown attack is critical; scale is the revealed
        -- shield's growth.
        shield = { critical = false, scale = 1 },
        -- The unblockable skull's growth while it shows, 0 to 1.
        skull = { grow = 0 },
        finished_keys = {}, finished_jobs = {},
    }
    -- offset is the share of the arrow's outward travel, 0 at rest to 1.
    for index = 1, 4 do
        state.arrows[index] = { opacity = 0, grow = 0, offset = 0 }
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
        for _, field in ipairs({ 'grow', 'offset' }) do state.tracks[field .. index] = nil end
        arrow.opacity, arrow.grow, arrow.offset, arrow.held = 0, 0, 0, nil
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

    -- The shown attack turned critical: the shield follows, growing when the cue asks.
    local function criticalShield(self)
        if self.shield.critical then return end
        self.shield.critical = true
        if env.grow then
            track('shieldScale', self.shield, 'scale', { phase(1, SHIELD_GROWN, self.time, self.duration) })
        end
    end

    -- Starts an arrow's growth and travel from rest, now.
    local function travel(self, index)
        local selected = self.arrows[index]
        selected.grow, selected.offset = 0, 0
        track('grow' .. index, selected, 'grow', { phase(0, 1, self.time, self.duration) })
        track('offset' .. index, selected, 'offset', { phase(0, 1, self.time, self.duration) })
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
                track(field .. index, selected, field, { phase(from, target, self.time, self.duration * (target - from)) })
            end
        end
    end

    -- An attack: its arrow shows at once at full opacity and size, then grows
    -- and travels outward. Any other arrow goes at once. mode 'held' shows the
    -- attack's buildup (the shield follows it) until reveal: its arrow grows and
    -- travels buildup of its way (both size and movement), or stays at rest
    -- without it; 'critical' shows an attack first seen critical, its arrow
    -- travelling from rest and the shield critical with it.
    function state:show(index, identity, mode, buildup)
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
        if mode == 'held' then
            selected.held = true
            selected.grow, selected.offset = 0, 0
            if buildup and buildup > 0 then carry(self, index, buildup) end
        else
            travel(self, index)
        end
        if mode == 'critical' then criticalShield(self) end
        env.apply(self)
        return true
    end

    -- A held arrow's attack went critical: the arrow carries its growth and
    -- travel on from where its buildup left them to the end, and the shield
    -- turns critical. False when it was not held.
    function state:reveal(index)
        local arrow = assert(self.arrows[index], 'Invalid arrow index')
        if not arrow.held then return false end
        self:step(true)
        arrow.held = nil
        carry(self, index, 1)
        criticalShield(self)
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
        criticalShield(self)
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

    -- An unblockable attack: the skull grows from its starting to its grown size;
    -- when it passes, it is back at its starting size for next time.
    function state:unblockable(shown)
        self:step(true)
        self.tracks.skullGrow = nil
        self.skull.grow = 0
        if shown then
            track('skullGrow', self.skull, 'grow', { phase(0, 1, self.time, self.duration) })
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
            track('container', self, 'opacity', { phase(self.opacity, 0, self.time, 1) })
        end
        env.apply(self)
        return true
    end

    return state
end

return M
