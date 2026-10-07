-- Pure animation timeline for the Preymonition cue.
local M = {}

-- An attack's arrow: shown at full opacity and its REST size, it grows to
-- GROWN while travelling outward over TRAVEL seconds.
local REST, GROWN, TRAVEL = 1.5, 2, 0.2
-- A critical arrow jumps to this size and holds it until the attack resolves.
local CRITICAL = 2.5
-- The flash where an arrow appears fades out while growing to FLASH_GROWN,
-- over the arrow's travel.
local FLASH_GROWN = 1.5

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
        finished_keys = {}, finished_jobs = {},
    }
    -- offset is the share of the arrow's outward travel, 0 at rest to 1.
    for index = 1, 4 do state.arrows[index] = { opacity = 0, scale = REST, offset = 0 } end

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
    end

    function state:has_jobs()
        return next(self.tracks) ~= nil
    end

    function state:cancel()
        self.tracks = {}
    end

    function state:step()
        local timestamp = env.now()
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
        env.apply(self)
        return self:has_jobs()
    end

    -- An attack: its arrow shows at once at full opacity and size, then grows
    -- and travels outward. Any other arrow goes at once.
    function state:show(index, identity)
        assert(self.arrows[index], 'Invalid arrow index')
        if self.last == identity then return false end
        self:step()
        local timestamp = env.now()
        self.last = identity
        self.ended = false

        local container = self.tracks.container
        if self.opacity < 0.5 or (container and container.phases[#container.phases].target < 0.5) then
            track('container', self, 'opacity', { phase(self.opacity, 0.5, timestamp, 0.1) })
        end
        for current = 1, #self.arrows do vanish(current) end
        local selected = self.arrows[index]
        selected.opacity = 1
        local flash = self.flash
        flash.index, flash.opacity, flash.scale = index, 1, 1
        track('flashOpacity', flash, 'opacity', { phase(1, 0, timestamp, TRAVEL) })
        track('flashScale', flash, 'scale', { phase(1, FLASH_GROWN, timestamp, TRAVEL) })
        track('scale' .. index, selected, 'scale', { phase(REST, GROWN, timestamp, TRAVEL) })
        track('offset' .. index, selected, 'offset', { phase(0, 1, timestamp, TRAVEL) })
        env.apply(self)
        return true
    end

    -- The attack went critical: the arrow jumps to its critical size and holds
    -- it until the attack resolves. Its travel carries on if unfinished.
    function state:critical(index)
        local arrow = assert(self.arrows[index], 'Invalid arrow index')
        self:step()
        self.tracks['opacity' .. index] = nil
        self.tracks['scale' .. index] = nil
        arrow.opacity, arrow.scale = 1, CRITICAL
        env.apply(self)
        return true
    end

    -- Combat started: fade the idle cue in without lighting an arrow.
    function state:engage()
        self:step()
        self.ended = false
        local container = self.tracks.container
        if self.opacity >= 0.5 and not (container and container.phases[#container.phases].target < 0.5) then
            return false
        end
        track('container', self, 'opacity', { phase(self.opacity, 0.5, env.now(), 0.2) })
        env.apply(self)
        return true
    end

    -- The attack resolved: every arrow goes at once and the idle cue stays. At
    -- combat end the cue itself also fades out over a second.
    function state:hide(combat_end)
        if not combat_end and self.ended then return false end
        self:step()
        self.last = nil
        for index = 1, #self.arrows do vanish(index) end
        if combat_end then
            self.ended = true
            self.tracks.flashOpacity, self.tracks.flashScale = nil, nil
            self.flash.opacity = 0
            track('container', self, 'opacity', { phase(self.opacity, 0, env.now(), 1) })
        end
        env.apply(self)
        return true
    end

    return state
end

return M
