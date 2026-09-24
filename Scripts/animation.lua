-- Pure animation timeline for the Preymonition HUD.
local M = {}

local function clamp(value)
    return math.max(0, math.min(1, value))
end

function M.new(env)
    assert(type(env) == 'table' and type(env.now) == 'function' and type(env.apply) == 'function',
        'Animation requires now and apply callbacks')
    local state = {
        opacity = 0, arrows = {}, tracks = {}, last = nil, ended = false,
        finished_keys = {}, finished_jobs = {},
    }
    for index = 1, 4 do state.arrows[index] = { opacity = 0, scale = 0.5 } end

    local function track(key, object, field, phases, after)
        state.tracks[key] = { object = object, field = field, phases = phases, after = after }
    end

    local function phase(from, target, start, duration)
        return { from = from, target = target, start = start, duration = duration }
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

        for current, arrow in ipairs(self.arrows) do
            self.tracks['opacity' .. current] = nil
            self.tracks['scale' .. current] = nil
            if current ~= index and (arrow.opacity > 0 or arrow.scale ~= 0.5) then
                track('opacity' .. current, arrow, 'opacity', { phase(arrow.opacity, 0, timestamp, 0.1) })
                track('scale' .. current, arrow, 'scale', { phase(arrow.scale, 0.5, timestamp, 0.1) })
            end
        end

        local selected = self.arrows[index]
        local restart = selected.opacity > 0 or selected.scale ~= 0.5
        if restart then
            track('opacity' .. index, selected, 'opacity', {
                phase(selected.opacity, 0, timestamp, 0.1),
                phase(0, 1, timestamp + 0.1, 0.3),
            })
            track('scale' .. index, selected, 'scale', {
                phase(selected.scale, 0.5, timestamp, 0.1),
                phase(0.5, 1, timestamp + 0.1, 0.3),
                phase(1, 0.8, timestamp + 0.4, 0.2),
            })
        else
            selected.opacity = 0
            selected.scale = 0.5
            track('opacity' .. index, selected, 'opacity', {
                phase(0, 1, timestamp, 0.3),
            })
            track('scale' .. index, selected, 'scale', {
                phase(0.5, 1, timestamp, 0.3),
                phase(1, 0.8, timestamp + 0.3, 0.2),
            })
        end
        env.apply(self)
        return true
    end

    function state:hide(combat_end)
        if not combat_end and self.ended then return false end
        self:step()
        local timestamp = env.now()
        self.last = nil
        if combat_end then
            self.ended = true
            self.tracks = {}
        end
        track('container', self, 'opacity', {
            phase(self.opacity, combat_end and 0 or 0.5, timestamp, 0.2),
        }, combat_end and function()
            for _, arrow in ipairs(self.arrows) do
                arrow.opacity = 0
                arrow.scale = 0.5
            end
            env.apply(self)
        end or nil)
        return true
    end

    return state
end

return M
