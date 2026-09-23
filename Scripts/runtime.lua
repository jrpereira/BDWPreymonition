-- Own Premonition's event hooks, HUD widgets, and settings lifecycle.
return function(log, scripts, api)
    assert(type(scripts) == 'string', 'Scripts path is required')
    local Animation = dofile(scripts .. '/animation.lua')
    local Events = dofile(scripts .. '/events.lua')
    local Feature = dofile(scripts .. '/feature.lua')
    local Adapter = dofile(scripts .. '/ue_adapter.lua')
    local feature = Feature.new(log, Animation, Events, Adapter.new(log, api))
    local runtime = { settings = nil, revision = 0, feature = feature }

    function runtime:apply(settings)
        local previous = self.settings
        if previous and previous.Enabled == settings.Enabled and previous.Debug == settings.Debug then
            return false
        end
        if not previous or previous.Enabled ~= settings.Enabled then
            if settings.Enabled == 1 then
                local ok, error_message = pcall(function() feature:start() end)
                if not ok then log(tostring(error_message)) end
            else
                feature:stop()
            end
        end
        self.settings = { Enabled = settings.Enabled, Debug = settings.Debug }
        self.revision = self.revision + 1
        if settings.Debug == 1 then
            log('Settings applied; Enabled=' .. settings.Enabled ..
                '; shows=' .. feature.stats.shows .. '; events=' .. feature.stats.events)
        end
        return true
    end

    function runtime:stop()
        feature:stop()
    end

    return runtime
end
