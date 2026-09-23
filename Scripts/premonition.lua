local INDICATOR_CLASS =
    '/Game/_Dawnwalker/UI/_Unified/Combat/WBP_CombatTargetIndicator.WBP_CombatTargetIndicator_C'

local template = {
    collection = 'Premonition',
    name = 'Premonition attacks',
    version = '0.1.0',
    description = 'Directional warning for incoming enemy attacks',
    category = 'npc.attacks',
    settings = { enabled = false },
    subscribe = {
        {
            path = INDICATOR_CLASS,
            events = { 'created' },
            contexts = { 'combat' },
        },
    },
}
local DIRECTIONS = {
    { source = 'TopArrow', name = 'TopArrow', angle = 0 },
    { source = 'BottomArrow', name = 'BottomArrow', angle = 180 },
    { source = 'LeftArrow', name = 'LeftArrow', angle = -90 },
    { source = 'RightArrow', name = 'RightArrow', angle = 90 },
}

local DESTROY_ORDER = {
    'TopArrow',
    'BottomArrow',
    'LeftArrow',
    'RightArrow',
    'PremonitionAnimatedArrows',
    'PremonitionAnimatedBackground',
    'Premonition',
}

local function highlighted(service, source)
    local selected, score = nil, 0.5
    for _, direction in ipairs(DIRECTIONS) do
        local image = source[direction.source]
        if service:valid(image) and service:visible(image) and image:GetRenderOpacity() > 0 then
            local color = image.ColorAndOpacity
            local value = math.max(color.R or 0, color.G or 0, color.B or 0) * (color.A or 0)
            if value > score then selected, score = direction.source, value end
        end
    end
    return selected
end

local function transition_attack(service, state, source)
    if state.detached or not service:valid(source) then return end
    local selected = highlighted(service, source)
    if not selected then return end

    local background = state.PremonitionAnimatedBackground
    if service:valid(source.Reticle) then
        background:SetBrush(source.Reticle.Brush)
        local brush = background.Background
        brush.OutlineSettings.Width = 0
        brush.DrawAs = 3
        background:SetBrush(brush)
        background:SetBrushColor({ R = 1, G = 1, B = 1, A = 0.20 })
    end

    service:transition(state.Premonition, 'RenderOpacity', 0.5, 0.10)
    for _, direction in ipairs(DIRECTIONS) do
        local image = state.arrows[direction.source]
        local native = source[direction.source]
        if service:valid(native) then image:SetBrush(native.Brush) end
        service:cancelTransitions(image)
        if direction.source == selected then
            image:SetRenderOpacity(0)
            image:SetRenderScale({ X = 0.5, Y = 0.5 })
            service:transition(image, 'RenderOpacity', 1, 0.30)
            service:transition(image, 'RenderScale', { X = 1, Y = 1 }, 0.30, function()
                if not state.detached and service:valid(image) then
                    service:transition(image, 'RenderScale', { X = 0.8, Y = 0.8 }, 0.20)
                end
            end)
        else
            service:transition(image, 'RenderOpacity', 0, 0.10)
            service:transition(image, 'RenderScale', { X = 0.5, Y = 0.5 }, 0.10)
        end
    end
end

function template:attach(service, hud, configuration, previous)
    if previous and service:valid(previous.Premonition) then return previous end
    if previous then self:detach(service, previous, 'reattach') end

    local tree = hud and hud.WidgetTree or nil
    local parent = tree and tree.RootWidget or nil
    if not service:valid(hud) or not tree or not parent then return nil, 'not_ready' end
    if not service:isA(parent, '/Script/UMG.Overlay') then return nil, 'not_ready' end

    local state = { arrows = {}, links = {}, hud = hud, detached = false }
    local function create(class, name)
        local widget = assert(service:createWidget(class, tree, name), 'could not create ' .. name)
        state.links[name] = widget
        return widget
    end

    local ok, error_message = pcall(function()
        local box = create('/Script/UMG.SizeBox', 'Premonition')
        local background = create('/Script/UMG.Border', 'PremonitionAnimatedBackground')
        local arrows = create('/Script/UMG.Overlay', 'PremonitionAnimatedArrows')
        state.Premonition = box
        state.PremonitionAnimatedBackground = background
        state.PremonitionAnimatedArrows = arrows

        local viewport = service:viewportSize(hud)
        local viewport_scale = service:viewportScale(hud)
        local size = math.min(viewport.X, viewport.Y) * 0.20 / viewport_scale
        box:SetWidthOverride(size)
        box:SetHeightOverride(size)
        box:SetRenderOpacity(0)

        background:SetBrush(service:nativeBrush(
            '/Game/_Dawnwalker/UI/_Unified/Combat/Atlas/Frames/' ..
            'T_Combat_Icon_Shield.T_Combat_Icon_Shield'))
        local brush = background.Background
        brush.OutlineSettings.Width = 0
        brush.DrawAs = 3
        background:SetBrush(brush)
        background:SetBrushColor({ R = 1, G = 1, B = 1, A = 0.20 })
        background:SetPadding({
            Left = 18 / viewport_scale,
            Top = 18 / viewport_scale,
            Right = 18 / viewport_scale,
            Bottom = 18 / viewport_scale,
        })
        background:SetHorizontalAlignment(0)
        background:SetVerticalAlignment(0)

        local arrow_brush = service:nativeBrush(
            '/Game/_Dawnwalker/UI/_Unified/Combat/Atlas/Frames/' ..
            'T_Combat_Icon_Arrow_White_Glow.T_Combat_Icon_Arrow_White_Glow')
        for _, direction in ipairs(DIRECTIONS) do
            local image = create('/Script/UMG.Image', direction.name)
            image:SetBrush(arrow_brush)
            image:SetColorAndOpacity({ R = 0.165132, G = 0.016807, B = 0.016807, A = 1 })
            image:SetRenderTransformPivot({ X = 0.5, Y = 0.5 })
            image:SetRenderTransformAngle(direction.angle)
            image:SetRenderOpacity(0)
            image:SetRenderScale({ X = 0.5, Y = 0.5 })
            local slot = arrows:AddChildToOverlay(image)
            slot:SetHorizontalAlignment(2)
            slot:SetVerticalAlignment(2)
            state.arrows[direction.source] = image
        end

        background:SetContent(arrows)
        box:SetContent(background)
        local slot = parent:AddChildToOverlay(box)
        slot:SetHorizontalAlignment(2)
        slot:SetVerticalAlignment(3)
        slot:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 32 / viewport_scale })
        hud:ForceLayoutPrepass()

    end)
    if not ok then
        self:detach(service, state, 'attach_failed')
        error(error_message)
    end
    return state
end

function template:render(service, state, indicator, eventName)
    if eventName ~= 'created' or not state or state.detached or not service:valid(indicator) then
        return 'ignored'
    end
    transition_attack(service, state, indicator)
    return 'applied'
end

function template:detach(service, state, _)
    if not state then return true end
    state.detached = true


    if state.Premonition then
        service:cancelTransitions(state.Premonition)
        for _, image in pairs(state.arrows or {}) do service:cancelTransitions(image) end
        if service:valid(state.Premonition) then
            state.Premonition:SetRenderOpacity(0)
            state.Premonition:RemoveFromParent()
        end
    end

    for _, name in ipairs(DESTROY_ORDER) do
        local widget = state.links and state.links[name]
        if widget then service:destroyWidget(widget) end
        if state.links then state.links[name] = nil end
    end

    state.arrows = {}
    state.links = {}
    state.Premonition = nil
    state.PremonitionAnimatedBackground = nil
    state.PremonitionAnimatedArrows = nil
    state.hud = nil
    return true
end

return template
