local Adapter = dofile('Scripts/ue_adapter.lua')

local function object(name, fields)
    local value = fields or {}
    value.valid = value.valid ~= false
    value.visible = value.visible ~= false
    value.opacity = value.opacity or 1
    function value:IsValid() return self.valid end
    function value:GetFullName() return 'MockClass ' .. name end
    function value:GetWorld() return self.world end
    function value:IsVisible() return self.visible end
    function value:GetRenderOpacity() return self.opacity end
    function value:GetParent() return self.parent end
    function value:SetVisibility() self.visible = true end
    function value:SetRenderOpacity(opacity) self.opacity = opacity end
    return value
end

local active_world = object('World.Active'); active_world.world = active_world
local stale_world = object('World.Stale'); stale_world.world = stale_world
local player = object('Player.Active', { world = active_world })

local function slot()
    return {
        SetHorizontalAlignment = function(self, value) self.horizontal = value end,
        SetVerticalAlignment = function(self, value) self.vertical = value end,
        SetPadding = function(self, value) self.padding = value end,
    }
end

local function widget(name, kind, world_value)
    local value = object(name, { world = world_value })
    value.kind = kind
    value.Background = { OutlineSettings = {}, DrawAs = 0 }
    function value:SetWidthOverride(width) self.width = width end
    function value:SetHeightOverride(height) self.height = height end
    function value:SetBrush(brush) self.Brush = brush; self.Background = brush end
    function value:SetBrushColor(color) self.BrushColor = color end
    function value:SetPadding(padding) self.padding = padding end
    function value:SetHorizontalAlignment(alignment) self.horizontal = alignment end
    function value:SetVerticalAlignment(alignment) self.vertical = alignment end
    function value:SetContent(child) self.content = child; child.parent = self end
    function value:AddChildToOverlay(child)
        child.parent = self
        child.Slot = slot()
        return child.Slot
    end
    function value:SetColorAndOpacity(color) self.ColorAndOpacity = color end
    function value:SetRenderTransform(transform) self.RenderTransform = transform end
    function value:SetRenderTransformPivot(pivot) self.pivot = pivot end
    function value:SetRenderScale(scale) self.scale = scale end
    function value:RemoveFromParent() self.removed = true; self.parent = nil end
    return value
end

local root = widget('HUD.Active.Root', 'Overlay', active_world)
local active_hud = object('HUD.Active', { world = active_world })
active_hud.WidgetTree = object('HUD.Active.Tree', { world = active_world, RootWidget = root })
function active_hud:GetOwningPlayer() return player end
function active_hud:ForceLayoutPrepass() self.prepassed = true end
local stale_root = widget('HUD.Stale.Root', 'Overlay', stale_world)
local stale_hud = object('HUD.Stale', { world = stale_world })
stale_hud.WidgetTree = object('HUD.Stale.Tree', { world = stale_world, RootWidget = stale_root })
function stale_hud:GetOwningPlayer() return object('Player.Stale', { world = stale_world }) end
function stale_hud:ForceLayoutPrepass() end

local source = object('Indicator.Active', { world = active_world })
source.Reticle = widget('Indicator.Reticle', 'Image', active_world)
source.Reticle.Brush = { OutlineSettings = {}, DrawAs = 0 }
source.Reticle.parent = source
for index, key in ipairs({ 'TopArrow', 'BottomArrow', 'LeftArrow', 'RightArrow' }) do
    local arrow = widget('Indicator.' .. key, 'Image', active_world)
    arrow.parent = source
    arrow.ColorAndOpacity = index == 4 and { R = 1, G = 0.6, B = 0.2, A = 1 }
        or { R = 0.16, G = 0.01, B = 0.01, A = 0.8 }
    arrow.RenderTransform = { Angle = ({ 0, 180, -90, 90 })[index] }
    arrow.Brush = { Resource = key }
    source[key] = arrow
end

local component = object('CombatComponent.Active', { world = active_world })
local stale_component = object('CombatComponent.Stale', { world = stale_world })
local active_combat = object('CombatSubsystem.Active', { world = active_world })
active_combat.in_combat = false
function active_combat:GetIsInCombat() return self.in_combat end
local stale_combat = object('CombatSubsystem.Stale', { world = stale_world })
stale_combat.in_combat = true
function stale_combat:GetIsInCombat() return self.in_combat end

local gameplay = object('Default__GameplayStatics')
function gameplay:GetPlayerController() return player end
function gameplay:GetRealTimeSeconds() return 12.5 end
local layout = object('Default__WidgetLayoutLibrary')
function layout:GetViewportScale() return 0.5 end
function layout:GetViewportSize() return { X = 1920, Y = 1080 } end

local paths = {
    ['/Script/Engine.Default__GameplayStatics'] = gameplay,
    ['/Script/UMG.Default__WidgetLayoutLibrary'] = layout,
    ['Indicator.Active'] = source,
    ['CombatComponent.Active'] = component,
    ['CombatComponent.Stale'] = stale_component,
}
for _, class_path in ipairs({ '/Script/UMG.SizeBox', '/Script/UMG.Border', '/Script/UMG.Overlay', '/Script/UMG.Image' }) do
    paths[class_path] = object(class_path, { kind = class_path:match('([^.]+)$') })
end
local hook_callback, unregistered, hud_scans, gameplay_lookups = nil, nil, 0, 0
local api = {
    FindAllOf = function(class_name)
        if class_name == 'WBP_GameHUD_C' then hud_scans = hud_scans + 1; return { stale_hud, active_hud } end
        if class_name == 'CombatSubsystem' then return { stale_combat, active_combat } end
        if class_name == 'WBP_CombatTargetIndicator_C' then return { source } end
        return {}
    end,
    StaticFindObject = function(path)
        if path == '/Script/Engine.Default__GameplayStatics' then gameplay_lookups = gameplay_lookups + 1 end
        return paths[path]
    end,
    StaticConstructObject = function(class, outer, name)
        return widget(tostring(name), class.kind, outer.world)
    end,
    FName = function(name) return name end,
    RegisterHook = function(_, callback) hook_callback = callback; return 10, 11 end,
    UnregisterHook = function(path, pre, post) unregistered = { path, pre, post } end,
    ExecuteWithDelay = function(_, callback) callback() end,
    ExecuteInGameThread = function(callback) callback() end,
}

local logs = {}
local adapter = Adapter.new(function(message) logs[#logs + 1] = message end, api)
assert(adapter.source_visible(source))
assert(adapter.source_direction(source) == 4, 'rendered highlighted arrow must determine direction')
assert(adapter.resolve_source('Indicator.Active') == source)
local ui, replaced = adapter.ensure_ui(source, nil)
assert(replaced and ui.hud == active_hud, 'HUD selection must stay in the source world')
assert(ui.box.width == 432 and ui.box.height == 432)
assert(ui.slot.padding.Bottom == 64 and ui.background.padding.Left == 36)
assert(ui.background.BrushColor.A == 0.2 and ui.images[4].ColorAndOpacity.R == 0.165132)
assert(adapter.valid_ui(ui) and active_hud.prepassed)
local reused, replaced_again = adapter.ensure_ui(source, ui)
assert(reused == ui and not replaced_again and hud_scans == 1,
    'a valid same-world HUD must be reused without another global HUD scan')
adapter.apply(ui, { opacity = 0.5, arrows = {
    { opacity = 0, scale = 0.5 }, { opacity = 0, scale = 0.5 },
    { opacity = 0, scale = 0.5 }, { opacity = 1, scale = 0.8 },
} })
assert(ui.box.opacity == 0.5 and ui.images[4].opacity == 1 and ui.images[4].scale.X == 0.8)
assert(adapter.now(ui) == 12.5)
assert(gameplay_lookups == 1, 'default GameplayStatics object must be cached across event and frame work')
assert(adapter.combat_state(source, ui) == false)
assert(adapter.combat_ended('CombatComponent.Active', ui))
assert(not adapter.combat_ended('CombatComponent.Stale', ui), 'stale-world combat events must be rejected')
local handle = adapter.register_hook('Hook.Path', function(path) assert(path == 'Indicator.Active') end)
hook_callback({ get = function() return source end })
adapter.unregister_hook(handle)
assert(unregistered[1] == 'Hook.Path' and unregistered[2] == 10 and unregistered[3] == 11)
local sources = adapter.initial_sources()
assert(#sources == 1 and sources[1] == 'Indicator.Active')
adapter.destroy_ui(ui)
assert(ui.box.removed and ui.box.opacity == 0)
print('PASS: active-world HUD selection, UMG layout/style, combat filtering, and hook ownership')
