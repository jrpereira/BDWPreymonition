-- UE4SS/UMG adapter for Premonition. Normal animation work never scans objects.
local M = {}

local ARROWS = { 'TopArrow', 'BottomArrow', 'LeftArrow', 'RightArrow' }

function M.new(log, api)
    api = api or _G
    local adapter = { ui_generation = 0, defaults = {} }

    local function valid(object)
        if not object then return false end
        local ok, result = pcall(function() return object:IsValid() end)
        return ok and result == true
    end

    local function full_name(object)
        if not valid(object) then return nil end
        local ok, value = pcall(function() return object:GetFullName() end)
        if not ok or type(value) ~= 'string' then return nil end
        return value:match('^%S+ (.+)$') or value
    end

    local function same_object(left, right)
        if left == right then return true end
        local left_name, right_name = full_name(left), full_name(right)
        return left_name ~= nil and left_name == right_name
    end

    local function world(object)
        if not valid(object) then return nil end
        local ok, value = pcall(function() return object:GetWorld() end)
        if not ok or not valid(value) then return nil end
        return value
    end

    local function visible_chain(widget)
        local current, visited = widget, 0
        while valid(current) and visited < 32 do
            local ok_visible, shown = pcall(function() return current:IsVisible() end)
            if not ok_visible or not shown then return false end
            local ok_opacity, opacity = pcall(function() return current:GetRenderOpacity() end)
            if ok_opacity and type(opacity) == 'number' and opacity <= 0 then return false end
            local ok_parent, parent = pcall(function() return current:GetParent() end)
            if not ok_parent or not valid(parent) then break end
            current = parent
            visited = visited + 1
        end
        return true
    end

    local function find_all(class_name)
        local finder = assert(api.FindAllOf, 'FindAllOf unavailable')
        local ok, values = pcall(finder, class_name)
        if not ok or type(values) ~= 'table' then return {} end
        return values
    end

    local function static_find(path)
        local finder = assert(api.StaticFindObject, 'StaticFindObject unavailable')
        local ok, value = pcall(finder, path)
        return ok and value or nil
    end

    local function default_object(key, path)
        local cached = adapter.defaults[key]
        if valid(cached) then return cached end
        cached = static_find(path)
        if valid(cached) then adapter.defaults[key] = cached end
        return cached
    end

    local function selected_player(world_context)
        local gameplay = default_object('gameplay', '/Script/Engine.Default__GameplayStatics')
        if not valid(gameplay) then return nil end
        local ok, controller = pcall(function() return gameplay:GetPlayerController(world_context, 0) end)
        return ok and valid(controller) and controller or nil
    end

    local function select_hud(source)
        local source_world = world(source)
        local player = selected_player(source)
        local candidates, best_score = {}, -1
        for _, hud in ipairs(find_all('WBP_GameHUD_C')) do
            local root = valid(hud) and hud.WidgetTree and hud.WidgetTree.RootWidget or nil
            if valid(root) and visible_chain(root) then
                local hud_world = world(hud)
                if not source_world or (hud_world and same_object(source_world, hud_world)) then
                    local score = 0
                    local ok_owner, owner = pcall(function() return hud:GetOwningPlayer() end)
                    if player and ok_owner and same_object(owner, player) then score = 2 end
                    if score > best_score then candidates, best_score = { hud }, score
                    elseif score == best_score then candidates[#candidates + 1] = hud end
                end
            end
        end
        if #candidates == 1 then adapter.ambiguous_logged = false; return candidates[1] end
        if #candidates > 1 and not adapter.ambiguous_logged then
            adapter.ambiguous_logged = true
            log('Premonition skipped an ambiguous active HUD selection')
        end
        return nil
    end

    local function construct(class_path, outer, name)
        local class = static_find(class_path)
        assert(valid(class), 'Missing widget class: ' .. class_path)
        local object = assert(api.StaticConstructObject, 'StaticConstructObject unavailable')(
            class, outer, assert(api.FName, 'FName unavailable')(name), 0x40)
        assert(valid(object), 'Widget construction failed: ' .. name)
        object:SetVisibility(3)
        return object
    end

    local function layout_ui(ui)
        local layout = default_object('layout', '/Script/UMG.Default__WidgetLayoutLibrary')
        assert(valid(layout), 'WidgetLayoutLibrary unavailable')
        local scale = layout:GetViewportScale(ui.hud)
        local viewport = layout:GetViewportSize(ui.hud)
        assert(type(scale) == 'number' and scale > 0, 'Invalid viewport scale')
        local size = math.min(viewport.X, viewport.Y) * 0.2 / scale
        ui.box:SetWidthOverride(size)
        ui.box:SetHeightOverride(size)
        ui.slot:SetHorizontalAlignment(2)
        ui.slot:SetVerticalAlignment(3)
        ui.slot:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 32 / scale })
        ui.background:SetPadding({ Left = 18 / scale, Top = 18 / scale, Right = 18 / scale, Bottom = 18 / scale })
    end

    local function style_ui(ui, source)
        assert(valid(source.Reticle), 'Source shield is unavailable')
        ui.background:SetBrush(source.Reticle.Brush)
        local brush = ui.background.Background
        if brush and brush.OutlineSettings then brush.OutlineSettings.Width = 0 end
        if brush then brush.DrawAs = 3; ui.background:SetBrush(brush) end
        ui.background:SetBrushColor({ R = 1, G = 1, B = 1, A = 0.2 })
        for index, key in ipairs(ARROWS) do
            local original = source[key]
            assert(valid(original), 'Source arrow is unavailable: ' .. key)
            local image = ui.images[index]
            image:SetBrush(original.Brush)
            image:SetColorAndOpacity({ R = 0.165132, G = 0.016807, B = 0.016807, A = 1 })
            image:SetRenderTransform(original.RenderTransform)
            image:SetRenderTransformPivot({ X = 0.5, Y = 0.5 })
        end
    end

    function adapter.source_visible(source)
        return valid(source) and visible_chain(source)
    end

    function adapter.source_direction(source)
        local best, score = nil, 0.5
        for index, key in ipairs(ARROWS) do
            local image = source[key]
            if valid(image) and visible_chain(image) then
                local ok_opacity, opacity = pcall(function() return image:GetRenderOpacity() end)
                local color = image.ColorAndOpacity
                if ok_opacity and opacity > 0 and color then
                    local value = math.max(color.R or 0, color.G or 0, color.B or 0) * (color.A or 0)
                    if value > score then best, score = index, value end
                end
            end
        end
        return best
    end

    function adapter.resolve_source(path)
        local source = static_find(path)
        return valid(source) and source or nil
    end

    function adapter.valid_ui(ui)
        local ok, current = pcall(function()
            if not (ui and valid(ui.hud) and ui.hud.WidgetTree and valid(ui.hud.WidgetTree.RootWidget)
                and visible_chain(ui.hud.WidgetTree.RootWidget) and valid(ui.box)
                and valid(ui.background) and valid(ui.overlay)) then return false end
            for _, image in ipairs(ui.images or {}) do if not valid(image) then return false end end
            return #(ui.images or {}) == 4
        end)
        return ok and current == true
    end

    function adapter.destroy_ui(ui)
        if not ui then return end
        if valid(ui.box) then
            pcall(function() ui.box:SetRenderOpacity(0) end)
            pcall(function() ui.box:RemoveFromParent() end)
        end
    end

    function adapter.ensure_ui(source, current)
        if adapter.valid_ui(current) and same_object(world(source), world(current.hud)) then
            layout_ui(current)
            style_ui(current, source)
            return current, false
        end
        local hud = select_hud(source)
        if not hud then return nil, false end
        if current then adapter.destroy_ui(current) end
        adapter.ui_generation = adapter.ui_generation + 1
        local suffix = tostring(adapter.ui_generation)
        local ui = { hud = hud, images = {} }
        local ok, error_message = pcall(function()
            local tree = hud.WidgetTree
            assert(tree and valid(tree.RootWidget), 'Active HUD has no valid root widget')
            ui.box = construct('/Script/UMG.SizeBox', tree, 'PremonitionRuntime' .. suffix)
            ui.background = construct('/Script/UMG.Border', tree, 'PremonitionBackground' .. suffix)
            ui.overlay = construct('/Script/UMG.Overlay', tree, 'PremonitionArrows' .. suffix)
            for index, key in ipairs(ARROWS) do
                local image = construct('/Script/UMG.Image', tree, 'Premonition' .. key .. suffix)
                local slot = ui.overlay:AddChildToOverlay(image)
                slot:SetHorizontalAlignment(0)
                slot:SetVerticalAlignment(0)
                ui.images[index] = image
            end
            ui.background:SetHorizontalAlignment(0)
            ui.background:SetVerticalAlignment(0)
            ui.background:SetContent(ui.overlay)
            ui.box:SetContent(ui.background)
            ui.slot = tree.RootWidget:AddChildToOverlay(ui.box)
            layout_ui(ui)
            style_ui(ui, source)
            ui.box:SetRenderOpacity(0)
            hud:ForceLayoutPrepass()
        end)
        if not ok then
            adapter.destroy_ui(ui)
            error(error_message)
        end
        return ui, true
    end

    function adapter.apply(ui, state)
        assert(adapter.valid_ui(ui), 'Premonition UI is no longer valid')
        ui.box:SetRenderOpacity(state.opacity)
        for index, arrow in ipairs(state.arrows) do
            local image = ui.images[index]
            assert(valid(image), 'Premonition arrow is no longer valid')
            image:SetRenderOpacity(arrow.opacity)
            image:SetRenderScale({ X = arrow.scale, Y = arrow.scale })
        end
    end

    function adapter.now(ui)
        local clock = default_object('gameplay', '/Script/Engine.Default__GameplayStatics')
        assert(valid(clock), 'GameplayStatics unavailable')
        return clock:GetRealTimeSeconds(ui.hud)
    end

    local function matching_combat_state(context)
        local expected_world = world(context)
        if not expected_world then return nil end
        local answer
        for _, subsystem in ipairs(find_all('CombatSubsystem')) do
            if valid(subsystem) and same_object(world(subsystem), expected_world) then
                local ok, in_combat = pcall(function() return subsystem:GetIsInCombat() end)
                if ok then
                    if answer ~= nil and answer ~= in_combat then return nil end
                    answer = in_combat
                end
            end
        end
        return answer
    end

    function adapter.combat_state(source, ui)
        return matching_combat_state(source or (ui and ui.hud))
    end

    function adapter.combat_ended(component_path, ui)
        if not ui or not adapter.valid_ui(ui) then return false end
        local component = static_find(component_path)
        if not valid(component) or not same_object(world(component), world(ui.hud)) then return false end
        return matching_combat_state(ui.hud) == false
    end

    function adapter.defer(milliseconds, callback)
        return assert(api.ExecuteWithDelay, 'ExecuteWithDelay unavailable')(milliseconds, callback)
    end

    function adapter.game_thread(callback)
        return assert(api.ExecuteInGameThread, 'ExecuteInGameThread unavailable')(callback)
    end

    function adapter.register_hook(path, callback)
        local registrar = assert(api.RegisterHook, 'RegisterHook unavailable')
        local ok, pre, post = pcall(registrar, path, function(context)
            local copied, error_message = pcall(function()
                local object = context:get()
                local path_value = full_name(object)
                if path_value then callback(path_value) end
            end)
            if not copied then log('Premonition hook context failed: ' .. tostring(error_message)) end
        end)
        if not ok then error('Hook registration failed for ' .. path .. ': ' .. tostring(pre)) end
        return { path = path, pre = pre, post = post }
    end

    function adapter.unregister_hook(handle)
        return assert(api.UnregisterHook, 'UnregisterHook unavailable')(
            handle.path, handle.pre, handle.post)
    end

    function adapter.initial_sources()
        local paths = {}
        for _, source in ipairs(find_all('WBP_CombatTargetIndicator_C')) do
            if adapter.source_visible(source) and adapter.source_direction(source) then
                local path = full_name(source)
                if path then paths[#paths + 1] = path end
            end
        end
        return paths
    end

    return adapter
end

return M
