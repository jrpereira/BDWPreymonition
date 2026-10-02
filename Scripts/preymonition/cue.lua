-- Shield cue widgets and reads of the game's combat target indicator.
local MC=require('mc')

local ARROWS={'TopArrow','BottomArrow','LeftArrow','RightArrow'}
local ARROW_COLOR={R=0.165132,G=0.016807,B=0.016807,A=1}
-- Native arrows at or below this colour strength are the inactive state.
local INACTIVE=0.5
local defaults={}
local generation=0
local M={}

local function default(path)
    local cached=defaults[path]
    if MC.valid(cached) then return cached end
    cached=StaticFindObject(path)
    if MC.valid(cached) then defaults[path]=cached; return cached end
end

local function world(object)
    local value=MC.call(object,'GetWorld')
    return MC.valid(value) and value or nil
end

local function visibleChain(widget)
    local current,visited=widget,0
    while MC.valid(current) and visited<32 do
        if MC.call(current,'IsVisible')~=true then return false end
        local opacity=MC.call(current,'GetRenderOpacity')
        if type(opacity)=='number' and opacity<=0 then return false end
        current=MC.parent(current)
        visited=visited+1
    end
    return true
end

local function construct(classPath,outer,name)
    local class=assert(StaticFindObject(classPath),'missing widget class: '..classPath)
    local object=StaticConstructObject(class,outer,FName(name),0x40)
    assert(MC.valid(object),'widget construction failed: '..name)
    object:SetVisibility(3)
    return object
end

local function combatState(context)
    local expected=world(context)
    if not expected then return nil end
    local ok,subsystems=pcall(FindAllOf,'CombatSubsystem')
    if not ok or type(subsystems)~='table' then return nil end
    local answer
    for _,subsystem in ipairs(subsystems) do
        if MC.same(world(subsystem),expected) then
            local inCombat=MC.call(subsystem,'GetIsInCombat')
            if inCombat~=nil then
                if answer~=nil and answer~=inCombat then return nil end
                answer=inCombat
            end
        end
    end
    return answer
end

function M.path(object)
    local name=MC.valid(object) and MC.call(object,'GetFullName')
    if type(name)~='string' then return nil end
    return name:match('^%S+ (.+)$') or name
end

function M.resolve(path)
    local object=StaticFindObject(path)
    return MC.valid(object) and object or nil
end

function M.visible(indicator)
    return MC.valid(indicator) and visibleChain(indicator)
end

-- Follow the rendered native arrows rather than the combat icon enum.
function M.direction(indicator)
    local best,score=nil,INACTIVE
    for index,key in ipairs(ARROWS) do
        local image=indicator[key]
        if MC.valid(image) and visibleChain(image) then
            local color=image.ColorAndOpacity
            if color then
                local value=math.max(color.R or 0,color.G or 0,color.B or 0)*(color.A or 0)
                if value>score then best,score=index,value end
            end
        end
    end
    return best
end

function M.visibleIndicators()
    local ok,indicators=pcall(FindAllOf,'WBP_CombatTargetIndicator_C')
    local paths={}
    if not ok or type(indicators)~='table' then return paths end
    for _,indicator in ipairs(indicators) do
        if M.visible(indicator) and M.direction(indicator) then
            paths[#paths+1]=M.path(indicator)
        end
    end
    return paths
end

function M.sameWorld(object,ui)
    return MC.same(world(object),world(ui.hud))
end

-- True or false only when every combat subsystem in the context's world agrees.
function M.combat(indicator)
    return combatState(indicator)
end

function M.combatEnded(componentPath,ui)
    local component=M.resolve(componentPath)
    return component~=nil and M.sameWorld(component,ui) and combatState(ui.hud)==false
end

function M.valid(ui)
    if not (ui and MC.valid(ui.hud) and MC.valid(ui.box) and MC.valid(ui.background)
        and MC.valid(ui.arrows)) then return false end
    for index=1,#ARROWS do
        if not MC.valid(ui.images[index]) then return false end
    end
    return true
end

function M.build(hud,layer,screen,settings)
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    generation=generation+1
    local suffix=tostring(generation)
    local ui={hud=hud,layer=layer,images={}}
    ui.box=construct('/Script/UMG.SizeBox',tree,'PreymonitionCue'..suffix)
    ui.background=construct('/Script/UMG.Border',tree,'PreymonitionShield'..suffix)
    ui.arrows=construct('/Script/UMG.Overlay',tree,'PreymonitionArrows'..suffix)
    for index,key in ipairs(ARROWS) do
        local image=construct('/Script/UMG.Image',tree,'Preymonition'..key..suffix)
        local slot=ui.arrows:AddChildToOverlay(image)
        slot:SetHorizontalAlignment(0)
        slot:SetVerticalAlignment(0)
        ui.images[index]=image
    end
    ui.background:SetHorizontalAlignment(0)
    ui.background:SetVerticalAlignment(0)
    ui.background:SetContent(ui.arrows)
    ui.box:SetContent(ui.background)

    local size=math.min(screen.width,screen.height)*(settings.CueS or 20)/100
    local inset=18/screen.scale
    ui.box:SetWidthOverride(size)
    ui.box:SetHeightOverride(size)
    ui.box:SetRenderOpacity(0)
    ui.background:SetPadding({Left=inset,Top=inset,Right=inset,Bottom=inset})
    local slot=layer:AddChildToOverlay(ui.box)
    slot:SetHorizontalAlignment(2)
    slot:SetVerticalAlignment(3)
    slot:SetPadding({Left=0,Top=0,Right=0,Bottom=32/screen.scale})
    return ui
end

-- Copy the live indicator's artwork so the cue matches the native shield.
function M.style(ui,indicator)
    assert(MC.valid(indicator.Reticle),'indicator shield unavailable')
    ui.background:SetBrush(indicator.Reticle.Brush)
    local brush=ui.background.Background
    if brush and brush.OutlineSettings then brush.OutlineSettings.Width=0 end
    if brush then brush.DrawAs=3; ui.background:SetBrush(brush) end
    ui.background:SetBrushColor({R=1,G=1,B=1,A=0.2})
    for index,key in ipairs(ARROWS) do
        local native=indicator[key]
        assert(MC.valid(native),'indicator arrow unavailable: '..key)
        local image=ui.images[index]
        image:SetBrush(native.Brush)
        image:SetColorAndOpacity(ARROW_COLOR)
        image:SetRenderTransform(native.RenderTransform)
        image:SetRenderTransformPivot({X=0.5,Y=0.5})
    end
end

function M.apply(ui,state)
    assert(M.valid(ui),'Preymonition cue is no longer valid')
    ui.box:SetRenderOpacity(state.opacity)
    for index,arrow in ipairs(state.arrows) do
        ui.images[index]:SetRenderOpacity(arrow.opacity)
        ui.images[index]:SetRenderScale({X=arrow.scale,Y=arrow.scale})
    end
end

function M.now(ui)
    local clock=assert(default('/Script/Engine.Default__GameplayStatics'),'GameplayStatics unavailable')
    return clock:GetRealTimeSeconds(ui.hud)
end

function M.destroy(ui)
    if MC.valid(ui.box) then MC.call(ui.box,'SetRenderOpacity',0) end
    if MC.valid(ui.layer) then MC.call(ui.layer,'ClearChildren') end
end

return M
