-- Shield cue widgets, and the few reads of the game it needs.
local MC=require('mc')

local ARROWS={'TopArrow','BottomArrow','LeftArrow','RightArrow'}
-- The native lit arrow colour, which a shown arrow takes.
local LIT_COLOR={R=1,G=0.67,B=0.19,A=1}
-- A critical attack's arrow, in the game's red, applied the moment it goes critical.
local CRITICAL_COLOR={R=1,G=0.2,B=0,A=1}
-- Screen direction each arrow travels in, matching ARROWS.
local OUTWARD={{X=0,Y=-1},{X=0,Y=1},{X=-1,Y=0},{X=1,Y=0}}
-- Where each arrow shows up and where its travel ends, in movement units out
-- from the native rest; the bottom arrow moves half as far. A unit is UNIT of the
-- shorter screen side.
local DISTANCE={{1,3},{0.5,1.5},{1,3},{1,3}}
local UNIT=0.05
-- What apply last wrote to each arrow, by these keys in ui.applied.
-- Per direction: the arrow's keys, then each trailing arrow's.
local KEYS={}
for index=1,#ARROWS do
    KEYS[index]={}
    for image=0,2 do
        local tag=index..'_'..image
        KEYS[index][image+1]={opacity='opacity'..tag,scale='scale'..tag,translation='translation'..tag}
    end
end
local arrowImages
local GAMEPLAY_STATICS='/Script/Engine.Default__GameplayStatics'
-- The game's attack flash, shown behind an arrow where it appears.
local FLASH_PATH='/Game/_Dawnwalker/UI/_Unified/Combat/Textures/T_Mask_AttackIndicator_Flash.T_Mask_AttackIndicator_Flash'
-- Widget names stay unique across Lua reloads: generation restarts with the
-- Lua state, while a HUD that survives the reload still holds the old names.
local generation=0
local nonce=string.format('%06x',math.random(0,0xffffff))
local M={ARROWS=ARROWS}

-- A pass is one entry from the game: an attack event or an animation frame. Within it each cue's widgets resolve once; the wrappers are
-- never read once the pass is over.
local depth,current=0,0
local function close(...) depth=0 return ... end
-- Runs callback in a pass, protected; returns pcall's results.
function M.pass(callback,...)
    if depth>0 then return pcall(callback,...) end
    depth,current=1,current+1
    return close(pcall(callback,...))
end

local function world(object)
    local value=MC.call(object,'GetWorld')
    return MC.valid(value) and value or nil
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

-- An asset, loading it when the game has not yet.
function M.find(path)
    local object=M.resolve(path)
    if object then return object end
    if type(rawget(_G,'LoadAsset'))=='function' then pcall(LoadAsset,path) end
    return M.resolve(path)
end

-- A class default object, kept between calls: the engine never frees one.
local defaults={}
function M.default(path)
    local object=defaults[path]
    if object and MC.valid(object) then return object end
    object=M.resolve(path)
    defaults[path]=object
    return object
end

-- Where an indicator's attack comes from: the owner of the latest queued
-- attack's instigator, a combat component. Nil when the queue names none.
function M.attacker(indicator)
    local queue=indicator.AttackQueue
    local count=queue and MC.call(queue,'GetArrayNum') or 0
    for index=count,1,-1 do
        local component=queue[index].Instigator
        local actor=MC.valid(component) and MC.call(component,'GetOwner')
        if actor and MC.valid(actor) then return actor end
    end
end

-- The current difficulty's parry window multiplier on this platform, or nil
-- when the game's combat subsystem cannot be read. The world subsystem lookup
-- needs no object scan; context is any live object in the player's world.
local SUBSYSTEMS='/Script/Engine.Default__SubsystemBlueprintLibrary'
local COMBAT='/Script/DogwoodCombat.CombatSubsystem'
local PLATFORM='Windows'
function M.parryWindow(context)
    local library,class=M.default(SUBSYSTEMS),M.default(COMBAT)
    if not (library and class) then return nil end
    local subsystem=MC.call(library,'GetWorldSubsystem',context,class)
    if not MC.valid(subsystem) then return nil end
    local level=subsystem.ActionDifficultyLevel
    local found
    subsystem.DifficultyConfig.ActionDifficulties:ForEach(function(key,value)
        if key:get()~=level then return end
        value:get().ParryWindowMultipliers:ForEach(function(name,multiplier)
            if name:get():ToString()==PLATFORM then found=multiplier:get() end
        end)
    end)
    return type(found)=='number' and found>0 and found or nil
end

-- Visibility, opacity and colour of a widget, for the log.
function M.describe(widget)
    local ok,text=pcall(function()
        local color=widget.ColorAndOpacity or {}
        local _,resource=pcall(function() return M.path(widget.Brush.ResourceObject) end)
        return string.format('visible %s, opacity %s, colour %.2f %.2f %.2f %.2f, brush %s',
            tostring(MC.call(widget,'IsVisible')),tostring(MC.call(widget,'GetRenderOpacity')),
            color.R or -1,color.G or -1,color.B or -1,color.A or -1,tostring(resource))
    end)
    return ok and text or 'unreadable: '..tostring(text)
end

-- The cue's widgets as live wrappers for this call, or nil once any is gone.
-- The cue keeps them only as weak handles: a kept wrapper reads freed memory
-- after its HUD is collected, as on a level load.
local LISTS={'images','ghosts'}
local function resolve(ui)
    local widgets={}
    for _,key in ipairs({'hud','layer','box','stack','shield','arrows','flash'}) do
        widgets[key]=MC.get(ui.handles[key])
        if not widgets[key] then return nil end
    end
    for _,list in ipairs(LISTS) do
        widgets[list]={}
        for index,handle in ipairs(ui.handles[list]) do
            widgets[list][index]=MC.get(handle)
            if not widgets[list][index] then return nil end
        end
    end
    return widgets
end

local function live(ui)
    if not ui then return nil end
    if depth>0 and ui.pass==current then return ui.widgets end
    local widgets=resolve(ui)
    if depth>0 then ui.pass,ui.widgets,ui.world=current,widgets,nil end
    return widgets
end

local function worldName(object)
    local value=world(object)
    local name=value and MC.call(value,'GetFullName')
    return type(name)=='string' and name~='' and name or nil
end

function M.sameWorld(object,ui)
    local widgets=live(ui)
    if not widgets then return false end
    local own=depth>0 and ui.pass==current and ui.world
    if not own then
        own=worldName(widgets.hud)
        if depth>0 then ui.world=own end
    end
    return own~=nil and own==worldName(object)
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
-- The game turns its indicator's shield red when an attack goes critical.
local SHIELD_CRITICAL={R=1,G=0.2,B=0,A=1}
local SKULL_COLOR={R=1,G=1,B=1,A=1}

-- The trailing arrows of the Fade effect: how much of the main arrow's
-- opacity each keeps, nearest first.
local GHOSTS={0.5,0.25}
-- The cue box, and the shield at Scale 0%, as a share of the shorter screen side.
local SHIELD_SHARE=0.4
-- Position keeps the shield this share of the screen height from the
-- bottom (Below) or top (Above) edge; Middle centres it.
local SHIELD_MARGIN=0.1

-- The shield's vertical centre for a Position, given its drawn size.
local function shieldCentre(position,height,size)
    if position==1 then return height/2 end
    if position==2 then return height*SHIELD_MARGIN+size/2 end
    return height*(1-SHIELD_MARGIN)-size/2
end

-- The cue settings: percentages of the current look, and choices.
local function config(settings)
    local function percent(key) return (settings[key] or 100)/100 end
    local style,trail=settings.ParryStyle or 1,settings.ParryTrail or 1
    -- Display Shield: 0 Off never shows it, 1 In Combat shows it faintly, 2
    -- Defending shows it faintly while an attack is shown, 3 Opportunity reveals
    -- it only for a critical attack. Each turns it red while the attack is critical.
    local watermark=settings.GeneralShield or 0
    return {
        shieldColor=watermark==1 and SHIELD_SHOWN or SHIELD_HIDDEN,
        watermark=watermark,
        move=percent('ParryMovement'),scale=percent('ParrySize'),
        arrows=style~=0,glowStyle=style==2,glow=trail==1,ghosts=trail==2,
        skull=percent('UnblockableSize'),
        -- Scale adds to the shield's size: 0% leaves it unchanged.
        shieldScale=(100+(settings.GeneralScale or 0))/100,
    }
end

-- Gives the shield image a centre sprite in a colour. Returns its path, or nil
-- while it cannot be found; the shield keeps its current look until then.
local function applySprite(shield,name,color)
    local path=SPRITES[name]
    local sprite=M.find(path)
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
    local suffix=nonce..'_'..generation
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
    local texture=M.find(FLASH_PATH)
    if texture then
        flash:SetBrushFromTexture(texture,false)
        flash:SetColorAndOpacity(LIT_COLOR)
    else
        -- An Image's default brush is solid white: keep it clear without the texture.
        flash:SetColorAndOpacity({R=1,G=1,B=1,A=0})
    end
    local images,ghosts={},{}
    for index,key in ipairs(ARROWS) do
        local image=construct('/Script/UMG.Image',tree,'Preymonition'..key..suffix)
        local slot=arrows:AddChildToOverlay(image)
        slot:SetHorizontalAlignment(0)
        slot:SetVerticalAlignment(0)
        images[index]=image
    end
    -- The Fade trail's arrows, two per direction, nearest first.
    if visuals.ghosts then
        for index,key in ipairs(ARROWS) do
            for ghost=1,#GHOSTS do
                local image=construct('/Script/UMG.Image',tree,'Preymonition'..key..'Trail'..ghost..suffix)
                image:SetRenderOpacity(0)
                local slot=arrows:AddChildToOverlay(image)
                slot:SetHorizontalAlignment(0)
                slot:SetVerticalAlignment(0)
                ghosts[(index-1)*#GHOSTS+ghost]=image
            end
        end
    end
    local size=math.min(screen.width,screen.height)*SHIELD_SHARE
    -- Slate units, like the box size: the inset keeps its share of the cue at any DPI.
    local inset=18
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
    -- Scale resizes only the shield, drawn around its centre; the box and the
    -- arrows keep their size.
    shield:SetRenderTransformPivot({X=0.5,Y=0.5})
    shield:SetRenderScale({X=visuals.shieldScale,Y=visuals.shieldScale})
    local sprite=applySprite(shield,'shield',visuals.shieldColor)
    -- Loaded now rather than at the first unblockable attack, mid-combat.
    M.find(SPRITES.skull)
    local slot=layer:AddChildToOverlay(box)
    -- Centred horizontally, at its Position vertically.
    slot:SetHorizontalAlignment(2)
    slot:SetVerticalAlignment(1)
    -- The box shares the shield's centre.
    local centre=shieldCentre(settings.GeneralPosition or 1,screen.height,size*visuals.shieldScale)
    local top=math.max(0,centre-size/2)
    slot:SetPadding({Left=0,Top=top,Right=0,Bottom=0})

    local handles={hud=hold(hud,'hud'),layer=hold(layer,'layer'),box=hold(box,'box'),
        stack=hold(stack,'stack'),shield=hold(shield,'shield'),arrows=hold(arrows,'arrows'),
        flash=hold(flash,'flash'),images={},ghosts={}}
    for index,image in ipairs(images) do handles.images[index]=hold(image,ARROWS[index]) end
    for index,image in ipairs(ghosts) do handles.ghosts[index]=hold(image,'trail') end
    -- Plain numbers, kept per arrow: rest translation and the native rotation,
    -- which the flash copies; and the movement unit.
    local base,angle={},{}
    for index=1,#ARROWS do base[index],angle[index]={X=0,Y=0},0 end
    local ui={handles=handles,base=base,angle=angle,sprite=sprite,visuals=visuals,
        unit=math.min(screen.width,screen.height)*UNIT,
        flash=texture and FLASH_PATH or nil,applied={}}
    M.artwork(ui)
    return ui
end

-- A direction's arrow image followed by its trail's, when the cue has one.
function arrowImages(ui,widgets,index)
    local list={widgets.images[index]}
    if ui.visuals.ghosts then
        for ghost=1,#GHOSTS do list[#list+1]=widgets.ghosts[(index-1)*#GHOSTS+ghost] end
    end
    return list
end

-- The indicator blueprint's own arrows, as designed: the cue takes their
-- artwork and rest transform when it attaches, never from a live indicator.
local INDICATOR_CLASS='/Game/_Dawnwalker/UI/_Unified/Combat/WBP_CombatTargetIndicator.WBP_CombatTargetIndicator_C'
local DESIGNED=INDICATOR_CLASS..':WidgetTree.'

-- Gives the cue's arrows the indicator's artwork: its arrow brush, or the
-- game's attack flash for the Glow style, in the lit colour, and each arrow's
-- designed rest and rotation. Returns whether the artwork was found; a cue
-- built before the indicator loads tries again when combat starts.
function M.artwork(ui)
    if ui.artwork then return true end
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    M.find(INDICATOR_CLASS)
    local designed={}
    for index,key in ipairs(ARROWS) do
        designed[index]=M.resolve(DESIGNED..key)
        if not designed[index] then return false end
    end
    -- The Glow style draws the game's attack flash in place of the arrow.
    local glow=ui.visuals.glowStyle and M.find(FLASH_PATH)
    for index,native in ipairs(designed) do
        for _,image in ipairs(arrowImages(ui,widgets,index)) do
            if glow then image:SetBrushFromTexture(glow,false) else image:SetBrush(native.Brush) end
            image:SetColorAndOpacity(LIT_COLOR)
            image:SetRenderTransform(native.RenderTransform)
            image:SetRenderTransformPivot({X=0.5,Y=0.5})
        end
        -- Distances count out from the designed rest.
        local ok,base=pcall(function()
            local translation=native.RenderTransform.Translation
            return {X=translation.X,Y=translation.Y}
        end)
        ui.base[index]=ok and base or {X=0,Y=0}
        local okAngle,angle=pcall(function() return native.RenderTransform.Angle end)
        ui.angle[index]=okAngle and type(angle)=='number' and angle or 0
        -- The transform replaced what apply last wrote to this arrow.
        for _,keys in ipairs(KEYS[index]) do
            ui.applied[keys.scale],ui.applied[keys.translation]=nil,nil
        end
    end
    ui.flashIndex=nil
    ui.artwork=true
    return true
end

-- Readies one cue arrow, and its trail, for a new attack: back to the lit colour.
function M.arm(ui,index)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    for _,image in ipairs(arrowImages(ui,widgets,index)) do image:SetColorAndOpacity(LIT_COLOR) end
end

-- Turns one cue arrow, and its trail, critical red.
function M.critical(ui,index)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    for _,image in ipairs(arrowImages(ui,widgets,index)) do image:SetColorAndOpacity(CRITICAL_COLOR) end
end

-- Retries the shield sprite for a cue built before it could be found. Returns
-- its path, or nil while it still cannot be found.
function M.styleShield(ui)
    if ui.sprite then return ui.sprite end
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    ui.sprite=applySprite(widgets.shield,'shield',ui.visuals.shieldColor)
    ui.applied.shieldColor=nil
    return ui.sprite
end

-- Swaps the cue's centre between the shield and the unblockable skull.
-- Returns the sprite path, or nil when it cannot be found.
function M.centre(ui,name)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    local skull=name=='skull'
    -- The skull hides the shield; apply leaves the centre alone meanwhile and
    -- restyles the shield after it.
    ui.skull=skull
    ui.applied.shieldColor,ui.applied.shieldScale=nil,nil
    local scale=skull and ui.visuals.skull or ui.visuals.shieldScale
    widgets.shield:SetRenderScale({X=scale,Y=scale})
    return applySprite(widgets.shield,name,skull and SKULL_COLOR or ui.visuals.shieldColor)
end

-- Writes a value only when it differs from what the cue last wrote there.
local function set(ui,widget,key,setter,value)
    if ui.applied[key]==value then return end
    ui.applied[key]=value
    widget[setter](widget,value)
end
local function setPair(ui,widget,key,setter,x,y)
    local last=ui.applied[key]
    if last and last.X==x and last.Y==y then return end
    local value={X=x,Y=y}
    ui.applied[key]=value
    widget[setter](widget,value)
end

function M.apply(ui,state)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    local visuals=ui.visuals
    set(ui,widgets.box,'box','SetRenderOpacity',state.opacity)
    local lit=0
    for index,arrow in ipairs(state.arrows) do
        local base,out=ui.base[index],OUTWARD[index]
        local from,to=DISTANCE[index][1],DISTANCE[index][2]
        local scale=arrow.scale*visuals.scale
        local opacity=visuals.arrows and arrow.opacity or 0
        for image,widget in ipairs(arrowImages(ui,widgets,index)) do
            local keys=KEYS[index][image]
            -- The trail follows the arrow's path, each one a step behind and fainter.
            local offset=image==1 and arrow.offset or arrow.trail[image-1]
            local distance=ui.unit*(from+(to-from)*offset)*visuals.move
            set(ui,widget,keys.opacity,'SetRenderOpacity',opacity*(image==1 and 1 or GHOSTS[image-1]))
            setPair(ui,widget,keys.scale,'SetRenderScale',scale,scale)
            setPair(ui,widget,keys.translation,'SetRenderTranslation',base.X+out.X*distance,base.Y+out.Y*distance)
        end
        lit=math.max(lit,arrow.opacity)
    end
    -- A critical attack turns the shield red: In Combat and Defending turn it
    -- red, Opportunity pops it in red and grows it; Off keeps it clear.
    -- Defending shows it faintly while an attack is shown.
    local shield=state.shield
    local critical=shield.critical and visuals.watermark~=0
    if ui.sprite and not ui.skull then
        local color=critical and SHIELD_CRITICAL
            or (visuals.watermark==2 and lit>0 and SHIELD_SHOWN) or visuals.shieldColor
        set(ui,widgets.shield,'shieldColor','SetColorAndOpacity',color)
        local scale=(critical and visuals.watermark==3 and shield.scale or 1)*visuals.shieldScale
        setPair(ui,widgets.shield,'shieldScale','SetRenderScale',scale,scale)
    elseif ui.skull then
        -- The skull grows from its set size to twice that.
        local scale=visuals.skull*state.skull.scale
        setPair(ui,widgets.shield,'shieldScale','SetRenderScale',scale,scale)
    end
    -- The flash sits where its arrow appears, turned like it; off, or without
    -- arrows, it stays clear.
    if not (visuals.glow and visuals.arrows) then return end
    local flash,index=state.flash,state.flash.index
    set(ui,widgets.flash,'flash','SetRenderOpacity',flash.opacity)
    if index then
        if ui.flashIndex~=index then
            ui.flashIndex=index
            widgets.flash:SetRenderTransformAngle(ui.angle[index])
        end
        local base,out=ui.base[index],OUTWARD[index]
        local distance=ui.unit*DISTANCE[index][1]*visuals.move
        local scale=flash.scale*visuals.scale
        setPair(ui,widgets.flash,'flashScale','SetRenderScale',scale,scale)
        setPair(ui,widgets.flash,'flashTranslation','SetRenderTranslation',
            base.X+out.X*distance,base.Y+out.Y*distance)
    end
end

-- What one cue arrow currently renders with, read back for the log.
function M.describeArrow(ui,index)
    local widgets=live(ui)
    if not widgets then return 'cue gone' end
    local image=widgets.images[index]
    local ok,text=pcall(function()
        local transform=image.RenderTransform
        return string.format('opacity %s, scale %.2f, at %.1f,%.1f (unit %.1f), cue opacity %s, %s',
            tostring(MC.call(image,'GetRenderOpacity')),transform.Scale.X,
            transform.Translation.X,transform.Translation.Y,ui.unit,
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
    local clock=assert(M.default(GAMEPLAY_STATICS),'GameplayStatics unavailable')
    return clock:GetRealTimeSeconds(widgets.hud)
end

-- Clears the cue's widgets that still exist and drops every handle.
function M.destroy(ui)
    local handles=ui.handles
    local box,layer=MC.get(handles.box),MC.get(handles.layer)
    if box then MC.call(box,'SetRenderOpacity',0) end
    if layer then MC.call(layer,'ClearChildren') end
    for key,handle in pairs(handles) do
        if key=='images' or key=='ghosts' then
            for _,image in ipairs(handle) do MC.release(image) end
        else
            MC.release(handle)
        end
    end
end

return M
