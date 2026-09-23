-- Lifecycle controller. Engine-specific widget and hook operations live in ue_adapter.lua.
local M = {}

function M.new(log, Animation, Events, adapter)
    local feature = {
        active = false,
        generation = 0,
        animation_token = 0,
        event_token = 0,
        event_pending = false,
        hooks = {},
        queue = Events.new(16),
        stats = { events = 0, shows = 0, clears = 0, combat_ends = 0, frames = 0 },
    }

    local function fail(self, error_message)
        self.last_error = tostring(error_message)
        self.event_pending = false
        self.animation_token = self.animation_token + 1
        if self.model then self.model:cancel() end
        log(self.last_error)
    end

    function feature:_reset_ui()
        self.animation_token = self.animation_token + 1
        if self.model then self.model:cancel() end
        if self.ui then pcall(adapter.destroy_ui, self.ui) end
        self.ui, self.model, self.source = nil, nil, nil
    end

    function feature:_pump()
        if not self.active or not self.model or not self.model:has_jobs() then return end
        local token = self.animation_token + 1
        self.animation_token = token
        local ok, error_message = pcall(adapter.defer, 16, function()
            if not self.active or self.animation_token ~= token then return end
            local queued, why = pcall(adapter.game_thread, function()
                if not self.active or self.animation_token ~= token then return end
                local checked, current = pcall(adapter.valid_ui, self.ui)
                if not self.ui or not checked or not current then
                    self:_reset_ui()
                    return
                end
                local stepped, more = pcall(function()
                    self.stats.frames = self.stats.frames + 1
                    return self.model:step()
                end)
                if not stepped then fail(self, more); return end
                if more then self:_pump() end
            end)
            if not queued then fail(self, why) end
        end)
        if not ok then fail(self, error_message) end
    end

    function feature:_ensure_model(source)
        local ui, replaced = adapter.ensure_ui(source, self.ui)
        if not ui then return false end
        if replaced or ui ~= self.ui or not self.model then
            self:_reset_ui()
            self.ui = ui
            self.model = Animation.new({
                now = function() return adapter.now(self.ui) end,
                apply = function(state) adapter.apply(self.ui, state) end,
            })
            self.model:step()
        else
            self.ui = ui
        end
        return true
    end

    function feature:_show(event)
        local source = adapter.resolve_source(event.path)
        if not source or not adapter.source_visible(source) then return end
        local direction = adapter.source_direction(source)
        if not direction then return end
        local combat = adapter.combat_state(source, self.ui)
        if combat == false or (self.ended and combat ~= true) then return end
        if not self:_ensure_model(source) then return end
        self.ended = false
        self.source = event.path
        if self.model:show(direction, event.path .. ':' .. event.sequence) then
            self.stats.shows = self.stats.shows + 1
            self:_pump()
        end
    end

    function feature:_clear(event)
        if self.model and self.source == event.path then
            self.source = nil
            self.stats.clears = self.stats.clears + 1
            self.model:hide(false)
            self:_pump()
        end
    end

    function feature:_combat_end(event)
        if self.model and adapter.combat_ended(event.path, self.ui) then
            self.ended = true
            self.source = nil
            self.stats.combat_ends = self.stats.combat_ends + 1
            self.model:hide(true)
            self:_pump()
        end
    end

    function feature:_drain()
        for _, event in ipairs(self.queue:drain()) do
            if not self.active then return end
            local ok, error_message = pcall(function()
                if event.kind == 'show' then self:_show(event)
                elseif event.kind == 'clear' then self:_clear(event)
                elseif event.kind == 'combat_end' then self:_combat_end(event)
                else error('Unknown event kind: ' .. tostring(event.kind)) end
            end)
            if not ok then fail(self, error_message) end
        end
    end

    function feature:_schedule_events()
        if self.event_pending or not self.active then return end
        self.event_pending = true
        local token = self.event_token + 1
        self.event_token = token
        local ok, error_message = pcall(adapter.defer, 1, function()
            if not self.active or self.event_token ~= token then return end
            local queued, why = pcall(adapter.game_thread, function()
                if not self.active or self.event_token ~= token then return end
                self.event_pending = false
                self:_drain()
                if #self.queue.items > 0 then self:_schedule_events() end
            end)
            if not queued then fail(self, why) end
        end)
        if not ok then fail(self, error_message) end
    end

    function feature:queue_event(kind, path)
        if not self.active or not path then return end
        self.stats.events = self.stats.events + 1
        self.queue:push(kind, path)
        self:_schedule_events()
    end

    function feature:start()
        if self.active then return false end
        assert(#self.hooks == 0, 'Cannot start with hook registrations pending removal')
        self.active = true
        self.generation = self.generation + 1
        self.ended = false
        self.last_error = nil
        local specs = {
            { '/Script/DogwoodUI.CombatTargetIndicatorBase:UpdateIconTypeToMatchObservedStubState', 'show' },
            { '/Script/DogwoodUI.CombatTargetIndicatorBase:NotifyIndicatorCleared', 'clear' },
            { '/Script/DogwoodCombat.PlayerCombatComponent:OnCombatEnded', 'combat_end' },
        }
        local ok, error_message = pcall(function()
            for _, spec in ipairs(specs) do
                self.hooks[#self.hooks + 1] = adapter.register_hook(spec[1], function(path)
                    self:queue_event(spec[2], path)
                end)
            end
            for _, path in ipairs(adapter.initial_sources()) do self:queue_event('show', path) end
        end)
        if not ok then
            local stopped, stop_error = pcall(function() self:stop() end)
            local suffix = stopped and '' or '; cleanup failed: ' .. tostring(stop_error)
            error('Premonition startup failed: ' .. tostring(error_message) .. suffix)
        end
        return true
    end

    function feature:stop()
        local was_active = self.active
        self.active = false
        self.generation = self.generation + 1
        self.event_token = self.event_token + 1
        self.animation_token = self.animation_token + 1
        self.event_pending = false
        self.queue:clear()
        local remaining, failures = {}, {}
        for _, handle in ipairs(self.hooks) do
            local ok, error_message = pcall(adapter.unregister_hook, handle)
            if not ok then
                remaining[#remaining + 1] = handle
                failures[#failures + 1] = tostring(error_message)
            end
        end
        self.hooks = remaining
        self:_reset_ui()
        self.ended = false
        if #failures > 0 then
            error('Hook removal failed: ' .. table.concat(failures, '; '))
        end
        return was_active
    end

    return feature
end

return M
