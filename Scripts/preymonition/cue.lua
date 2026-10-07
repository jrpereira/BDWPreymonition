-- Shield cue widgets and reads of the game's combat target indicator.
local MC=require('mc')

local ARROWS={'TopArrow','BottomArrow','LeftArrow','RightArrow'}
-- The native lit arrow colour; a shown arrow copies the live one when it can.
local LIT_COLOR={R=1,G=0.67,B=0.19,A=1}
-- A critical attack's arrow, in the game's red, applied the moment it goes critical.
local CRITICAL_COLOR={R=1,G=0.2,B=0,A=1}
-- Screen direction each arrow travels in, matching ARROWS.
local OUTWARD={{X=0,Y=-1},{X=0,Y=1},{X=-1,Y=0},{X=1,Y=0}}
-- Where each arrow shows up and where its travel ends, in arrow image sizes
-- along its axis out from the native rest; the bottom arrow stays closer.
local DISTANCE={{1,3},{0.5,2},{1,3},{1,3}}
-- The game's attack flash, shown behind an arrow where it appears.
local FLASH_PATH='/Game/_Dawnwalker/UI/_Unified/Combat/Textures/T_Mask_AttackIndicator_Flash.T_Mask_AttackIndicator_Flash'
-- Native arrows at or below this colour strength are the inactive state.
local INACTIVE=0.5
local generation=0
local M={ARROWS=ARROWS}

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

function M.path(object)
    local name=MC.valid(object) and MC.call(object,'GetFullName')
    if type(name)~='string' then return nil end
    return name:match('^%S+ (.+)$') or name
end

function M.resolve(path)
    local object=StaticFindObject(path)
    return MC.valid(object) and object or nil
end

function M.visible(widget)
    return MC.valid(widget) and visibleChain(widget)
end

-- Visibility, opacity and colour of a widget, for the log.
function M.describe(widget)
    local ok,text=pcall(function()
        local color=widget.ColorAndOpacity or {}
        local _,resource=pcall(function() return M.path(widget.Brush.ResourceObject) end)
        local _,tint=pcall(function()
            local value=widget.Brush.TintColor.SpecifiedColor
            return string.format('%.2f %.2f %.2f %.2f',value.R,value.G,value.B,value.A)
        end)
        return string.format('visible %s, opacity %s, colour %.2f %.2f %.2f %.2f, brush %s tint %s',
            tostring(MC.call(widget,'IsVisible')),tostring(MC.call(widget,'GetRenderOpacity')),
            color.R or -1,color.G or -1,color.B or -1,color.A or -1,tostring(resource),tostring(tint))
    end)
    return ok and text or 'unreadable: '..tostring(text)
end

local function strength(image)
    local color=image.ColorAndOpacity
    if not color then return 0 end
    return math.max(color.R or 0,color.G or 0,color.B or 0)*(color.A or 0)
end

-- A native arrow the game currently shows as attacking: visible and brightly coloured.
function M.lit(image)
    return MC.valid(image) and visibleChain(image) and strength(image)>INACTIVE
end

-- The direction an indicator arrow image stands for, by its widget name.
function M.arrowIndex(image)
    local fname=MC.valid(image) and MC.call(image,'GetFName')
    local name=fname and MC.call(fname,'ToString')
    for index,key in ipairs(ARROWS) do
        if key==name then return index end
    end
end

-- The combat target indicator whose WidgetTree holds an arrow image.
function M.indicatorOf(image)
    local tree=MC.valid(image) and MC.call(image,'GetOuter')
    local indicator=MC.valid(tree) and MC.call(tree,'GetOuter')
    local name=MC.valid(indicator) and MC.call(indicator,'GetFullName')
    if type(name)=='string' and name:find('CombatTargetIndicator',1,true) then return indicator end
end

-- The cue's widgets as live wrappers for this call, or nil once any is gone.
-- The cue keeps them only as weak handles: a kept wrapper reads freed memory
-- after its HUD is collected, as on a level load.
local function live(ui)
    if not ui then return nil end
    local widgets={images={}}
    for _,key in ipairs({'hud','layer','box','stack','shield','arrows','flash'}) do
        widgets[key]=MC.get(ui.handles[key])
        if not widgets[key] then return nil end
    end
    for index=1,#ARROWS do
        widgets.images[index]=MC.get(ui.handles.images[index])
        if not widgets.images[index] then return nil end
    end
    return widgets
end

function M.sameWorld(object,ui)
    local widgets=live(ui)
    return widgets~=nil and MC.same(world(object),world(widgets.hud))
end

function M.valid(ui)
    return live(ui)~=nil
end

local function hold(object,name)
    return assert(MC.hold(object),'cue cannot keep '..name)
end

-- The game's sprites for the cue's centre: the shield, shown faintly or kept
-- clear by setting, and the skull shown for an unblockable attack.
local FRAMES='/Game/_Dawnwalker/UI/_Unified/Combat/Atlas/Frames/'
local SPRITES={
    shield=FRAMES..'T_Combat_Icon_Shield.T_Combat_Icon_Shield',
    skull=FRAMES..'T_Combat_Icon_SkullRed.T_Combat_Icon_SkullRed',
}
local SHIELD_SHOWN,SHIELD_HIDDEN={R=1,G=1,B=1,A=0.2},{R=1,G=1,B=1,A=0}
local SKULL_COLOR={R=1,G=1,B=1,A=1}

-- The Visuals settings: percentages of the current look, and switches.
local function config(settings)
    local function percent(key) return (settings[key] or 100)/100 end
    return {
        shieldColor=settings.BackgroundShield==1 and SHIELD_SHOWN or SHIELD_HIDDEN,
        move=percent('ArrowsMove'),scale=percent('ArrowsSize'),glow=settings.ArrowsGlow~=0,
        skull=percent('UnblockableSize'),
    }
end

-- A sprite, loading it when the game has not yet.
local function findSprite(path)
    local sprite=M.resolve(path)
    if sprite then return sprite end
    if type(rawget(_G,'LoadAsset'))=='function' then pcall(LoadAsset,path) end
    return M.resolve(path)
end

-- Gives the shield image a centre sprite in a colour. Returns its path, or nil
-- while it cannot be found; the shield keeps its current look until then.
local function applySprite(shield,name,color)
    local path=SPRITES[name]
    local sprite=findSprite(path)
    if not sprite then return nil end
    shield:SetBrushFromAtlasInterface(sprite,false)
    shield:SetColorAndOpacity(color)
    return path
end

function M.build(hud,layer,screen,settings)
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    local visuals=config(settings)
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    generation=generation+1
    local suffix=tostring(generation)
    -- SizeBox > Overlay with the shield image under the arrows overlay.
    local box=construct('/Script/UMG.SizeBox',tree,'PreymonitionCue'..suffix)
    local stack=construct('/Script/UMG.Overlay',tree,'PreymonitionStack'..suffix)
    local shield=construct('/Script/UMG.Image',tree,'PreymonitionShield'..suffix)
    local arrows=construct('/Script/UMG.Overlay',tree,'PreymonitionArrows'..suffix)
    -- The flash goes in first, so it draws behind the arrows.
    local flash=construct('/Script/UMG.Image',tree,'PreymonitionFlash'..suffix)
    local flashSlot=arrows:AddChildToOverlay(flash)
    flashSlot:SetHorizontalAlignment(0)
    flashSlot:SetVerticalAlignment(0)
    flash:SetRenderOpacity(0)
    flash:SetRenderTransformPivot({X=0.5,Y=0.5})
    local texture=findSprite(FLASH_PATH)
    if texture then
        flash:SetBrushFromTexture(texture,false)
        flash:SetColorAndOpacity(LIT_COLOR)
    else
        -- An Image's default brush is solid white: keep it clear without the texture.
        flash:SetColorAndOpacity({R=1,G=1,B=1,A=0})
    end
    local images={}
    for index,key in ipairs(ARROWS) do
        local image=construct('/Script/UMG.Image',tree,'Preymonition'..key..suffix)
        local slot=arrows:AddChildToOverlay(image)
        slot:SetHorizontalAlignment(0)
        slot:SetVerticalAlignment(0)
        images[index]=image
    end
    local size=math.min(screen.width,screen.height)*(settings.CueS or 20)/100
    local inset=18/screen.scale
    local shieldSlot=stack:AddChildToOverlay(shield)
    shieldSlot:SetHorizontalAlignment(0)
    shieldSlot:SetVerticalAlignment(0)
    local arrowsSlot=stack:AddChildToOverlay(arrows)
    arrowsSlot:SetHorizontalAlignment(0)
    arrowsSlot:SetVerticalAlignment(0)
    arrowsSlot:SetPadding({Left=inset,Top=inset,Right=inset,Bottom=inset})
    box:SetContent(stack)
    box:SetWidthOverride(size)
    box:SetHeightOverride(size)
    box:SetRenderOpacity(0)
    -- An Image's default brush is solid white: clear until it has the sprite.
    shield:SetColorAndOpacity({R=1,G=1,B=1,A=0})
    local sprite=applySprite(shield,'shield',visuals.shieldColor)
    local slot=layer:AddChildToOverlay(box)
    -- Centred horizontally, its top on the screen's vertical middle.
    slot:SetHorizontalAlignment(2)
    slot:SetVerticalAlignment(1)
    slot:SetPadding({Left=0,Top=screen.height/2,Right=0,Bottom=0})

    local handles={hud=hold(hud,'hud'),layer=hold(layer,'layer'),box=hold(box,'box'),
        stack=hold(stack,'stack'),shield=hold(shield,'shield'),arrows=hold(arrows,'arrows'),
        flash=hold(flash,'flash'),images={}}
    for index,image in ipairs(images) do handles.images[index]=hold(image,ARROWS[index]) end
    -- Plain numbers, kept per arrow: rest translation, image size along its
    -- axis and the native rotation, which the flash copies.
    local base,size,angle={},{},{}
    for index=1,#ARROWS do base[index],size[index],angle[index]={X=0,Y=0},0,0 end
    return {handles=handles,base=base,size=size,angle=angle,sprite=sprite,visuals=visuals,
        flash=texture and FLASH_PATH or nil}
end

-- Copy the live indicator's arrow artwork. The cue keeps its own shield: the
-- indicator's centre icon changes with the attack's state.
-- With only, just that arrow is restyled, so other arrows keep their brush.
function M.style(ui,indicator,only)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    for index,key in ipairs(ARROWS) do
        if only==nil or only==index then
            local native=indicator[key]
            assert(MC.valid(native),'indicator arrow unavailable: '..key)
            local image=widgets.images[index]
            image:SetBrush(native.Brush)
            local color=native.ColorAndOpacity
            image:SetColorAndOpacity(only and strength(native)>INACTIVE
                and {R=color.R,G=color.G,B=color.B,A=color.A} or LIT_COLOR)
            image:SetRenderTransform(native.RenderTransform)
            image:SetRenderTransformPivot({X=0.5,Y=0.5})
            -- Distances count out from the native rest in arrow image sizes.
            local ok,base,size=pcall(function()
                local translation=native.RenderTransform.Translation
                local imageSize=native.Brush.ImageSize
                return {X=translation.X,Y=translation.Y},
                    OUTWARD[index].X~=0 and imageSize.X or imageSize.Y
            end)
            ui.base[index]=ok and base or {X=0,Y=0}
            ui.size[index]=ok and size or 0
            local okAngle,angle=pcall(function() return native.RenderTransform.Angle end)
            ui.angle[index]=okAngle and type(angle)=='number' and angle or 0
        end
    end
end

-- Turns one cue arrow critical red.
function M.critical(ui,index)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    widgets.images[index]:SetColorAndOpacity(CRITICAL_COLOR)
end

-- Retries the shield sprite for a cue built before it could be found. Returns
-- its path, or nil while it still cannot be found.
function M.styleShield(ui)
    if ui.sprite then return ui.sprite end
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    ui.sprite=applySprite(widgets.shield,'shield',ui.visuals.shieldColor)
    return ui.sprite
end

-- Swaps the cue's centre between the shield and the unblockable skull.
-- Returns the sprite path, or nil when it cannot be found.
function M.centre(ui,name)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    local skull=name=='skull'
    local scale=skull and ui.visuals.skull or 1
    widgets.shield:SetRenderScale({X=scale,Y=scale})
    return applySprite(widgets.shield,name,skull and SKULL_COLOR or ui.visuals.shieldColor)
end

function M.apply(ui,state)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    local visuals=ui.visuals
    widgets.box:SetRenderOpacity(state.opacity)
    for index,arrow in ipairs(state.arrows) do
        local image,base,out=widgets.images[index],ui.base[index],OUTWARD[index]
        local from,to=DISTANCE[index][1],DISTANCE[index][2]
        local distance=ui.size[index]*(from+(to-from)*arrow.offset)*visuals.move
        local scale=arrow.scale*visuals.scale
        image:SetRenderOpacity(arrow.opacity)
        image:SetRenderScale({X=scale,Y=scale})
        image:SetRenderTranslation({X=base.X+out.X*distance,Y=base.Y+out.Y*distance})
    end
    -- The flash sits where its arrow appears, turned like it; off, it stays clear.
    local flash,index=state.flash,state.flash.index
    if not visuals.glow then return end
    widgets.flash:SetRenderOpacity(flash.opacity)
    if index then
        if ui.flashIndex~=index then
            ui.flashIndex=index
            widgets.flash:SetRenderTransformAngle(ui.angle[index])
        end
        local base,out=ui.base[index],OUTWARD[index]
        local distance=ui.size[index]*DISTANCE[index][1]*visuals.move
        local scale=flash.scale*visuals.scale
        widgets.flash:SetRenderScale({X=scale,Y=scale})
        widgets.flash:SetRenderTranslation({X=base.X+out.X*distance,Y=base.Y+out.Y*distance})
    end
end

-- What one cue arrow currently renders with, read back for the log.
function M.describeArrow(ui,index)
    local widgets=live(ui)
    if not widgets then return 'cue gone' end
    local image=widgets.images[index]
    local ok,text=pcall(function()
        local transform=image.RenderTransform
        return string.format('opacity %s, scale %.2f, at %.1f,%.1f (image %.1f), cue opacity %s, %s',
            tostring(MC.call(image,'GetRenderOpacity')),transform.Scale.X,
            transform.Translation.X,transform.Translation.Y,ui.size[index],
            tostring(MC.call(widgets.box,'GetRenderOpacity')),M.describe(image))
    end)
    return ok and text or 'unreadable: '..tostring(text)
end

-- A live object in the cue's world, for calls that need a world context.
function M.context(ui)
    return assert(live(ui),'Preymonition cue is no longer valid').hud
end

function M.now(ui)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    local clock=assert(M.resolve('/Script/Engine.Default__GameplayStatics'),'GameplayStatics unavailable')
    return clock:GetRealTimeSeconds(widgets.hud)
end

-- Clears the cue's widgets that still exist and drops every handle.
function M.destroy(ui)
    local handles=ui.handles
    local box,layer=MC.get(handles.box),MC.get(handles.layer)
    if box then MC.call(box,'SetRenderOpacity',0) end
    if layer then MC.call(layer,'ClearChildren') end
    for key,handle in pairs(handles) do
        if key=='images' then
            for _,image in ipairs(handle) do MC.release(image) end
        else
            MC.release(handle)
        end
    end
end

return M
