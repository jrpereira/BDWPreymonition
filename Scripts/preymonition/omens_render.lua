-- The omens' widgets: the arrows and the unblockable skull, centred where the
-- Background template draws its shield (preymonition.placement). The game's
-- combat state comes from preymonition.combat.
local MC=require('mc')
local Placement=require('preymonition.placement')
local Drawn=require('preymonition.omens_drawn')
local Fancy=require('preymonition.omens_fancy')

local ARROWS={'TopArrow','BottomArrow','LeftArrow','RightArrow'}
-- The native lit arrow colour, which a shown arrow takes.
local LIT_COLOR={R=1,G=0.67,B=0.19,A=1}
-- A critical attack's arrow, in the game's red, applied the moment it goes critical.
local CRITICAL_COLOR={R=1,G=0.2,B=0,A=1}
-- Screen direction each arrow travels in, matching ARROWS. The game's LeftArrow
-- and RightArrow show on the opposite sides of the screen (seen 2026-10-18).
local OUTWARD={{X=0,Y=-1},{X=0,Y=1},{X=1,Y=0},{X=-1,Y=0}}
-- Distances run out from the cue's centre, as a share of the way to the screen
-- edge the arrow travels towards. Movement from Center is a range: an
-- arrow shows up with its back edge at the low share, and its tip, the edge
-- furthest along its travel, stops at the high share. An arrow whose tip already
-- reaches past the high share does not move.
-- A unit is UNIT of the screen along an axis: arrow sizes are in units of the height.
local UNIT=0.05
-- Sizes are in units of the screen height, the same for every arrow. Size
-- sets an arrow's starting and grown sizes on one scale: 0% is 1 unit, 100% is 10.
local SIZE={1,10}
-- The unblockable skull's size on the same units: 0% is 1 unit, 100% the full
-- screen height.
local SKULL_SIZE={1,1/UNIT}
-- Where each arrow travels on the screen: 1 vertical (height), 2 horizontal (width).
local AXIS={2,2,1,1}
-- The Perspective style lays the cue flat on a plane parallel to the ground,
-- through the character's waist, seen from a camera TILT degrees above it at
-- DISTANCE screen heights from the cue's centre. Up on the screen is away from
-- the camera; positions and shapes keep their flat sizes at the centre.
local PERSPECTIVE={tilt=20,distance=0.5}
-- On the ground plane an arrow travelling away nears the horizon without ever
-- reaching it: its travel ends where it has shrunk to FARTHEST of its size, unless
-- the screen edge comes first.
local FARTHEST=0.25
-- What apply last wrote to each arrow, by these keys in ui.applied.
local KEYS={}
for index=1,#ARROWS do
    KEYS[index]={opacity='opacity'..index,scale='scale'..index,translation='translation'..index}
end
local arrowSize,skullScale,fit,tipDistance,reach,shareOf,projector,groundMap,paintParts
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
local LISTS={'images'}
local function resolve(ui)
    local widgets={}
    for _,key in ipairs({'hud','layer','box','stack','shield','arrows'}) do
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

-- The skull, the game's sprite, shown at the cue's centre for an unblockable
-- attack; the centre is clear otherwise.
local SKULL='/Game/_Dawnwalker/UI/_Unified/Combat/Atlas/Frames/T_Combat_Icon_SkullRed.T_Combat_Icon_SkullRed'
local SKULL_COLOR,CLEAR={R=1,G=1,B=1,A=1},{R=1,G=1,B=1,A=0}
-- A buildup arrow's opacity by Buildup visibility: Hidden, Faint, Normal.
local BUILDUP_OPACITY={[0]=0,[1]=0.35,[2]=1}

-- A range setting as shares, 0 to 1: {low, high}. MCT gives it as {low, high} percent.
local function share(span,low,high)
    if type(span)=='table' and type(span[1])=='number' and type(span[2])=='number' then low,high=span[1],span[2] end
    local function clamp(value) return math.max(0,math.min(1,value/100)) end
    return {clamp(low),clamp(high)}
end

-- The cue settings: percentages of the current look, and choices.
local function config(settings)
    -- Style: 0 Off, 1 Solid, 2 Chevron, 3 Perspective (a Chevron
    -- lying on the ground plane), drawn by the cue; 4 Fancy, the mod's pictures.
    local style=settings.ParryStyle or 2
    -- Prioritize Perfection over Buildup: Buildup visibility 0 Hidden, 1 Faint,
    -- 2 Normal sets a buildup arrow's opacity.
    local perfection=settings.ParryPerfection==1
    return {
        buildupOpacity=perfection and (BUILDUP_OPACITY[settings.ParryBuildupVisibility or 0] or 0) or 1,
        -- Movement and Size are shares, 0 to 1: the movement is {appears,
        -- stops} of the way to the screen edge, the size {starting, grown}.
        move=share(settings.ParryMovement,40,60),
        size=share(settings.ParrySize,30,80),
        arrows=style~=0,shape=style==1 and 'solid' or 'chevron',perspective=style==3,fancy=style==4,
        -- The skull's {starting, grown} size as shares, 0 to 1.
        skull=share(settings.UnblockableSize,60,100),
    }
end

function M.build(hud,layer,screen,settings)
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    local visuals=config(settings)
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    generation=generation+1
    local suffix=nonce..'_'..generation
    -- SizeBox > Overlay with the centre image (the skull) under the arrows overlay.
    local box=construct('/Script/UMG.SizeBox',tree,'PreymonitionCue'..suffix)
    local stack=construct('/Script/UMG.Overlay',tree,'PreymonitionStack'..suffix)
    local shield=construct('/Script/UMG.Image',tree,'PreymonitionCentre'..suffix)
    local arrows=construct('/Script/UMG.Overlay',tree,'PreymonitionArrows'..suffix)
    -- Plain numbers: each arrow's turn, the flat shape's size, the units along
    -- each axis, and the ground plane's projection for Perspective.
    -- Fancy needs its pictures; without them the cue draws a Chevron.
    local normal,critical
    if visuals.fancy then
        normal,critical=Fancy.load(hud)
        if not normal then visuals.fancy=false end
    end
    local flat=visuals.fancy and {width=Fancy.SIZE.X,height=Fancy.SIZE.Y} or Drawn.layout(visuals.shape)
    local angle={}
    for index=1,#ARROWS do
        angle[index]=visuals.fancy and Fancy.angle(OUTWARD[index]) or Drawn.angle(OUTWARD[index])
    end
    local ui={angle=angle,shapeSize={X=flat.width,Y=flat.height},visuals=visuals,
        unit={screen.width*UNIT,screen.height*UNIT},applied={}}
    -- The box shares the Background shield's centre at its default size, at
    -- its Position vertically.
    local size,top=Placement.box(screen,settings.GeneralPosition or 1,Placement.SIZE)
    ui.box=size
    -- How far each arrow's screen edge is from the cue's centre, matching ARROWS.
    local middle=top+size/2
    ui.edge={middle,screen.height-middle,screen.width/2,screen.width/2}
    if visuals.perspective then
        ui.camera=screen.height*PERSPECTIVE.distance
        ui.project=projector(ui.camera)
    end
    -- Each arrow is centred at its own size; apply places and sizes it.
    -- An arrow the cue draws, turned for its direction, with its coloured parts
    -- kept per direction. On the ground plane its shape is drawn as it looks
    -- where it appears, already turned; apply then moves and scales it.
    local images,parts,growers={},{},{}
    local function makeArrow(index,name)
        local build=function(class,part) return construct(class,tree,part) end
        local arrow,_,coloured
        local map=ui.project and groundMap(ui,index)
        if visuals.fancy then
            arrow,coloured=Fancy.build(build,name,normal,critical)
            growers[index]={}
        else
            arrow,_,coloured,growers[index]=Drawn.build(build,name,visuals.shape,map)
        end
        if not map then arrow:SetRenderTransformAngle(angle[index]) end
        for _,entry in ipairs(coloured) do
            parts[index][#parts[index]+1]=entry
        end
        paintParts(ui,coloured,LIT_COLOR)
        local slot=arrows:AddChildToOverlay(arrow)
        slot:SetHorizontalAlignment(2)
        slot:SetVerticalAlignment(2)
        return arrow
    end
    for index,key in ipairs(ARROWS) do
        parts[index]={}
        images[index]=makeArrow(index,'Preymonition'..key..suffix)
    end
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
    -- An Image's default brush is solid white: clear until the skull shows.
    shield:SetColorAndOpacity(CLEAR)
    -- The skull sizes itself, drawn around its centre; the box and the arrows
    -- keep their size.
    shield:SetRenderTransformPivot({X=0.5,Y=0.5})
    -- Loaded now rather than at the first unblockable attack, mid-combat.
    M.find(SKULL)
    local slot=layer:AddChildToOverlay(box)
    -- Centred horizontally, at its Position vertically.
    slot:SetHorizontalAlignment(2)
    slot:SetVerticalAlignment(1)
    slot:SetPadding({Left=0,Top=top,Right=0,Bottom=0})

    local handles={hud=hold(hud,'hud'),layer=hold(layer,'layer'),box=hold(box,'box'),
        stack=hold(stack,'stack'),shield=hold(shield,'shield'),arrows=hold(arrows,'arrows'),
        images={},parts={},growers={}}
    for index,image in ipairs(images) do handles.images[index]=hold(image,ARROWS[index]) end
    -- A drawn arrow's parts, resolved only to recolour them.
    for index,list in ipairs(parts) do
        handles.parts[index]={}
        for at,entry in ipairs(list) do handles.parts[index][at]={hold(entry[1],'arrow part'),entry[2]} end
    end
    -- The widgets that grow, resolved only when their scale changes.
    for index,list in ipairs(growers) do
        handles.growers[index]={}
        for at,entry in ipairs(list) do handles.growers[index][at]={hold(entry[1],'arrow part'),entry[2]} end
    end
    ui.handles=handles
    return ui
end

-- Colours an arrow's parts, as {widget,role}: drawn parts take the colour,
-- Fancy shows its red picture for the critical colour and its yellow one otherwise.
function paintParts(ui,list,color)
    for _,entry in ipairs(list) do
        local value=ui.visuals.fancy and Fancy.color(entry[2],color==CRITICAL_COLOR)
            or Drawn.color(entry[2],color)
        entry[1]:SetColorAndOpacity(value)
    end
end

-- Colours one cue arrow, part by part.
local function paint(ui,index,color)
    local list={}
    for at,entry in ipairs(ui.handles.parts[index]) do
        list[at]={assert(MC.get(entry[1]),'Preymonition cue is no longer valid'),entry[2]}
    end
    paintParts(ui,list,color)
end

-- Readies one cue arrow for a new attack: back to the lit colour.
function M.arm(ui,index) paint(ui,index,LIT_COLOR) end

-- Turns one cue arrow critical red.
function M.critical(ui,index) paint(ui,index,CRITICAL_COLOR) end

-- Shows or clears the unblockable skull at the cue's centre. Returns the
-- sprite path, or nil when it cannot be found.
function M.skull(ui,shown)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    ui.skull=shown
    ui.applied.skullScale=nil
    if not shown then
        widgets.shield:SetColorAndOpacity(CLEAR)
        return SKULL
    end
    local sprite=M.find(SKULL)
    if not sprite then return nil end
    widgets.shield:SetRenderScale({X=skullScale(ui,0),Y=skullScale(ui,0)})
    widgets.shield:SetBrushFromAtlasInterface(sprite,false)
    widgets.shield:SetColorAndOpacity(SKULL_COLOR)
    return SKULL
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

-- An arrow's size for its grow (0 starting, 1 grown), from Size, in screen units.
function arrowSize(ui,grow)
    local size=ui.visuals.size
    local from=SIZE[1]+(SIZE[2]-SIZE[1])*size[1]
    local to=SIZE[1]+(SIZE[2]-SIZE[1])*size[2]
    return ui.unit[2]*(from+(to-from)*grow)
end
-- The render scale that gives the skull its size for its grow (0 starting, 1
-- grown), from Size: the shield image fills the cue's box.
function skullScale(ui,grow)
    local size=ui.visuals.skull
    local share=size[1]+(size[2]-size[1])*grow
    return ui.unit[2]*(SKULL_SIZE[1]+(SKULL_SIZE[2]-SKULL_SIZE[1])*share)/ui.box
end
-- The render scale that gives the drawn shape the arrow's size along its larger
-- side, and how far its tip then reaches from its centre: half its turned extent
-- along the arrow's axis.
function fit(ui,index,size)
    local shape=ui.shapeSize
    local scale=size/math.max(shape.X,shape.Y)
    local angle=math.rad(ui.angle[index] or 0)
    local cos,sin=math.abs(math.cos(angle)),math.abs(math.sin(angle))
    local extent=AXIS[index]==1 and cos*shape.X+sin*shape.Y or sin*shape.X+cos*shape.Y
    return scale,extent*scale/2
end
-- How far an arrow's tip is from the cue's centre at a share of its travel.
-- Movement from Center is measured in the space the arrow has: at 0% the
-- arrow, at its starting size, has its back edge on the centre; at 100% its
-- tip is at the screen edge (on the ground plane, the furthest it can show).
-- It appears with its tip at the low share and travels to the high one.
function tipDistance(ui,index,offset)
    local move=ui.visuals.move
    local _,tip=fit(ui,index,arrowSize(ui,0))
    -- Where the tip is at 0%, as a share of the way to the edge.
    local start=math.min(1,shareOf(ui,index,2*tip))
    local function at(share) return reach(ui,index,start+(1-start)*share) end
    local from,to=at(move[1]),at(move[2])
    return from+(to-from)*offset
end

-- How far out a share of an arrow's travel is, in flat units from the cue's
-- centre. 100% is the furthest the arrow can show: the screen edge, or on the
-- ground plane the edge or where a receding arrow ends (see FARTHEST). Shares
-- are of that distance on the screen, so on the ground plane a nearing arrow
-- covers less ground than a receding one for the same share.
function reach(ui,index,share)
    local edge=ui.edge[index]
    if not ui.project or OUTWARD[index].Y==0 then return share*edge end
    local camera,tilt=ui.camera,math.rad(PERSPECTIVE.tilt)
    local sin,cos=math.sin(tilt),math.cos(tilt)
    local away=OUTWARD[index].Y<0
    -- On the screen: the projection puts ground t out at t*sin*camera/(camera±t*cos).
    local limit=away and math.min(edge,(1-FARTHEST)*camera*sin/cos) or edge
    local screen=share*limit
    return screen*camera/(camera*sin+(away and -1 or 1)*screen*cos)
end

-- The share of the way out (as reach measures it) that a flat distance from
-- the cue's centre is: reach's inverse.
function shareOf(ui,index,flat)
    local edge=ui.edge[index]
    if not ui.project or OUTWARD[index].Y==0 then return flat/edge end
    local camera,tilt=ui.camera,math.rad(PERSPECTIVE.tilt)
    local sin,cos=math.sin(tilt),math.cos(tilt)
    local away=OUTWARD[index].Y<0
    local limit=away and math.min(edge,(1-FARTHEST)*camera*sin/cos) or edge
    local screen=flat*camera*sin/(camera+(away and 1 or -1)*flat*cos)
    return screen/limit
end

-- The ground plane's projection: a flat offset from the cue's centre (y down)
-- read as a point on the plane, up being away from the camera. Returns where it
-- shows and how much nearer things grow, 1 at the centre.
function projector(distance)
    local tilt=math.rad(PERSPECTIVE.tilt)
    local sin,cos=math.sin(tilt),math.cos(tilt)
    return function(x,y)
        local depth=-y
        local k=distance/math.max(distance*0.1,distance+depth*cos)
        return x*k,-depth*sin*k,k
    end
end
-- Extends an arrow's lines so the shape is extra design units wider, writing
-- only the parts whose scale changed.
local function grow(ui,index,extra)
    for at,entry in ipairs(ui.handles.growers[index]) do
        local x,y=Drawn.growScale(entry[2],extra)
        local key='grow'..index..'_'..at
        local last=ui.applied[key]
        if not (last and math.abs(last.X-x)<1e-6 and math.abs(last.Y-y)<1e-6) then
            local widget=assert(MC.get(entry[1]),'Preymonition cue is no longer valid')
            ui.applied[key]={X=x,Y=y}
            widget:SetRenderScale({X=x,Y=y})
        end
    end
end
-- Where an arrow's flat centre sits at a share of its travel, and its scale.
-- A drawn arrow keeps its starting scale and grows by extending its lines from
-- the tip; a Fancy picture scales as a whole. Either way the tip stays where
-- the travel puts it.
local function flatPlace(ui,index,offset,grow)
    local scale,tip=fit(ui,index,arrowSize(ui,ui.visuals.fancy and grow or 0))
    return tipDistance(ui,index,offset)-tip,scale
end
-- The map from the shape's design units to the arrow as it shows where it
-- appears, per unit of its scale there: turned, scaled and placed flat, then
-- projected, relative to the projected centre.
function groundMap(ui,index)
    local out,turn=OUTWARD[index],math.rad(ui.angle[index])
    local centre,scale=flatPlace(ui,index,0)
    local cx,cy=out.X*centre,out.Y*centre
    local px,py,k=ui.project(cx,cy)
    local cos,sin=math.cos(turn),math.sin(turn)
    return function(point)
        local x,y=point.X*cos-point.Y*sin,point.X*sin+point.Y*cos
        local sx,sy=ui.project(cx+x*scale,cy+y*scale)
        return {X=(sx-px)/(scale*k),Y=(sy-py)/(scale*k)}
    end
end

function M.apply(ui,state)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    local visuals=ui.visuals
    set(ui,widgets.box,'box','SetRenderOpacity',state.opacity)
    for index,arrow in ipairs(state.arrows) do
        local out=OUTWARD[index]
        local centre,scale=flatPlace(ui,index,arrow.offset,arrow.grow)
        -- How much wider than its starting shape it is, in design units; a
        -- hidden arrow keeps its lines until it shows again.
        if arrow.opacity>0 and not visuals.fancy then
            grow(ui,index,arrowSize(ui,arrow.grow)/scale-ui.shapeSize.X)
        end
        local x,y=out.X*centre,out.Y*centre
        -- On the ground plane the arrow shows where its flat place projects,
        -- nearer ones larger.
        if ui.project then
            local k
            x,y,k=ui.project(x,y)
            scale=scale*k
        end
        -- A buildup arrow shows at Buildup visibility.
        local opacity=visuals.arrows and arrow.opacity*(arrow.held and visuals.buildupOpacity or 1) or 0
        local widget,keys=widgets.images[index],KEYS[index]
        set(ui,widget,keys.opacity,'SetRenderOpacity',opacity)
        setPair(ui,widget,keys.scale,'SetRenderScale',scale,scale)
        setPair(ui,widget,keys.translation,'SetRenderTranslation',x,y)
    end
    -- The skull grows from its starting to its grown size.
    if ui.skull then
        local scale=skullScale(ui,state.skull.grow)
        setPair(ui,widgets.shield,'skullScale','SetRenderScale',scale,scale)
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
            transform.Translation.X,transform.Translation.Y,ui.unit[AXIS[index]],
            tostring(MC.call(widgets.box,'GetRenderOpacity')),M.describe(image))
    end)
    return ok and text or 'unreadable: '..tostring(text)
end

-- A live object in the cue's world, for calls that need a world context.
function M.context(ui)
    return assert(live(ui),'Preymonition cue is no longer valid').hud
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
        elseif key=='parts' or key=='growers' then
            for _,list in ipairs(handle) do
                for _,entry in ipairs(list) do MC.release(entry[1]) end
            end
        else
            MC.release(handle)
        end
    end
end

return M
