-- The Background's widgets: the game's shield sprite in a box centred where
-- preymonition.placement puts it, which the Omens line up on.
-- preymonition.background decides what it shows.
local MC=require('mc')
local Placement=require('preymonition.placement')

local SHIELD='/Game/_Dawnwalker/UI/_Unified/Combat/Atlas/Frames/T_Combat_Icon_Shield.T_Combat_Icon_Shield'
-- Visibility: 1 In Combat shows the shield faint white throughout combat, 2
-- Defending a see-through yellow (the arrows' colour) while an attack is
-- shown, 3 Critical only once its parry window opens. Each turns it red while
-- the parry window is open; Critical pops it in red and grows it.
local CLEAR={R=1,G=1,B=1,A=0}
local IN_COMBAT={R=1,G=1,B=1,A=0.2}
local DEFENDING={R=1,G=0.67,B=0.19,A=0.4}
local CRITICAL={R=1,G=0.2,B=0,A=1}
-- Widget names stay unique across Lua reloads, like the omens'.
local generation=0
local nonce=string.format('%06x',math.random(0,0xffffff))
local M={}

local function construct(classPath,outer,name)
    local class=assert(StaticFindObject(classPath),'missing widget class: '..classPath)
    local object=StaticConstructObject(class,outer,FName(name),0x40)
    assert(MC.valid(object),'widget construction failed: '..name)
    object:SetVisibility(3)
    return object
end

local function hold(object,name)
    return assert(MC.hold(object),'background cannot keep '..name)
end

-- An asset, loading it when the game has not yet.
local function find(path)
    local object=StaticFindObject(path)
    if MC.valid(object) then return object end
    if type(rawget(_G,'LoadAsset'))=='function' then pcall(LoadAsset,path) end
    object=StaticFindObject(path)
    return MC.valid(object) and object or nil
end

-- The settings: Visibility (1 to 3, default Defending) and the shield's drawn
-- height as a share of the screen height (5% to 100%, default 50%).
local function config(settings)
    local visibility=tonumber(settings.Visibility) or 2
    if visibility<1 or visibility>3 then visibility=2 end
    local size=math.max(0.05,math.min(1,(tonumber(settings.Size) or 50)/100))
    return {visibility=visibility,size=size,position=settings.Position or 1}
end

-- The widgets as live wrappers for this call, or nil once any is gone.
local function live(ui)
    local widgets={}
    for _,key in ipairs({'hud','box','shield'}) do
        widgets[key]=MC.get(ui.handles[key])
        if not widgets[key] then return nil end
    end
    return widgets
end

function M.valid(ui)
    return ui~=nil and live(ui)~=nil
end

local function worldName(object)
    local world=MC.call(object,'GetWorld')
    local name=MC.valid(world) and MC.call(world,'GetFullName')
    return type(name)=='string' and name~='' and name or nil
end

-- Whether an object is in the same world as the background's HUD.
function M.sameWorld(ui,object)
    local hud=MC.get(ui.handles.hud)
    if not (hud and MC.valid(object)) then return false end
    local own=worldName(hud)
    return own~=nil and own==worldName(object)
end

-- A live object in the background's world, for calls that need a world context.
function M.context(ui)
    return assert(MC.get(ui.handles.hud),'background is no longer valid')
end

-- Gives the shield its sprite once the game has it. Returns whether it has.
function M.style(ui)
    if ui.sprite then return true end
    local widgets=assert(live(ui),'background is no longer valid')
    local sprite=find(SHIELD)
    if not sprite then return false end
    widgets.shield:SetBrushFromAtlasInterface(sprite,false)
    ui.sprite,ui.applied.color=true,nil
    return true
end

-- Builds the shield in the layer, hidden, and returns its handles.
function M.build(hud,layer,screen,settings)
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    local visuals=config(settings or {})
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    generation=generation+1
    local suffix=nonce..'_'..generation
    local box=construct('/Script/UMG.SizeBox',tree,'PreymonitionBackground'..suffix)
    local shield=construct('/Script/UMG.Image',tree,'PreymonitionShield'..suffix)
    -- The box is the cue box the Omens use; Size scales the shield in it,
    -- about its centre, which stays where Position puts a shield that size.
    local side,top=Placement.box(screen,visuals.position,visuals.size)
    visuals.scale=screen.height*visuals.size/side
    box:SetWidthOverride(side)
    box:SetHeightOverride(side)
    box:SetContent(shield)
    box:SetRenderOpacity(0)
    -- An Image's default brush is solid white: clear until it has the sprite.
    shield:SetColorAndOpacity(CLEAR)
    shield:SetRenderTransformPivot({X=0.5,Y=0.5})
    shield:SetRenderScale({X=visuals.scale,Y=visuals.scale})
    local slot=layer:AddChildToOverlay(box)
    slot:SetHorizontalAlignment(2)
    slot:SetVerticalAlignment(1)
    slot:SetPadding({Left=0,Top=top,Right=0,Bottom=0})
    local ui={visuals=visuals,applied={},
        handles={hud=hold(hud,'hud'),layer=hold(layer,'layer'),box=hold(box,'box'),shield=hold(shield,'shield')}}
    M.style(ui)
    return ui
end

-- Writes a value only when it differs from what was last written there.
local function set(ui,widget,key,setter,value)
    local last=ui.applied[key]
    if last==value then return end
    ui.applied[key]=value
    widget[setter](widget,value)
end

-- Applies an animation state (preymonition.omens_animation): its opacity fades
-- the shield in and out with combat, its arrows say whether an attack is shown,
-- and its shield whether that attack is critical and how far a Critical shield
-- has grown. hidden clears the shield, as while an unblockable skull shows.
function M.apply(ui,state,hidden)
    local widgets=assert(live(ui),'background is no longer valid')
    local visuals=ui.visuals
    set(ui,widgets.box,'opacity','SetRenderOpacity',state.opacity)
    local shown=false
    for _,arrow in ipairs(state.arrows) do shown=shown or arrow.opacity>0 end
    local critical=state.shield.critical
    local color=CLEAR
    if ui.sprite and not hidden then
        if critical then color=CRITICAL
        elseif visuals.visibility==1 then color=IN_COMBAT
        elseif visuals.visibility==2 and shown then color=DEFENDING end
    end
    set(ui,widgets.shield,'color','SetColorAndOpacity',color)
    local scale=(critical and visuals.visibility==3 and state.shield.scale or 1)*visuals.scale
    if ui.applied.scale~=scale then
        ui.applied.scale=scale
        widgets.shield:SetRenderScale({X=scale,Y=scale})
    end
end

-- Clears the background's widgets that still exist and drops every handle.
function M.destroy(ui)
    local box,layer=MC.get(ui.handles.box),MC.get(ui.handles.layer)
    if box then MC.call(box,'SetRenderOpacity',0) end
    if layer then MC.call(layer,'ClearChildren') end
    for _,handle in pairs(ui.handles) do MC.release(handle) end
end

return M
