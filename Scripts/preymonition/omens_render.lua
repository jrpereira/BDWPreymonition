-- The omens' widgets: the arrows, centred at their Position
-- (preymonition.placement), and the unblockable
-- indicator at the screen's centre.
local MC=require('mc')
local Widgets=require('preymonition.widgets')
local Placement=require('preymonition.placement')
local Fancy=require('preymonition.omens_fancy')
local Images=require('preymonition.omens_images')

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
-- The unblockable indicator shows at half the cue's opacity.
local SKULL_OPACITY=0.5
-- The screen axis each arrow travels along, an index into ui.unit: 1 horizontal
-- (width), 2 vertical (height).
local AXIS={2,2,1,1}
-- What apply last wrote to each arrow, by these keys in ui.applied.
local KEYS={}
for index=1,#ARROWS do
    KEYS[index]={opacity='opacity'..index,scale='scale'..index,translation='translation'..index}
end
local arrowSize,skullScale,fit,tipDistance,paintParts
local construct=Widgets.construct
local function hold(object,name) return Widgets.hold(object,'cue',name) end
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

function M.path(object)
    local name=MC.valid(object) and MC.call(object,'GetFullName')
    if type(name)~='string' then return nil end
    return name:match('^%S+ (.+)$') or name
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
local function resolve(ui)
    local widgets={images={}}
    for _,key in ipairs({'hud','layer','box','stack','skull','arrows'}) do
        widgets[key]=MC.get(ui.handles[key])
        if not widgets[key] then return nil end
    end
    for index,handle in ipairs(ui.handles.images) do
        widgets.images[index]=MC.get(handle)
        if not widgets.images[index] then return nil end
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

-- Whether object is in the cue's world. The cue's own world name is read once
-- per pass.
function M.sameWorld(object,ui)
    local widgets=live(ui)
    if not widgets then return false end
    local own=depth>0 and ui.pass==current and ui.world
    if not own then
        own=Widgets.worldName(widgets.hud)
        if depth>0 then ui.world=own end
    end
    return own~=nil and own==Widgets.worldName(object)
end

function M.valid(ui)
    return live(ui)~=nil
end

-- The unblockable indicator at the screen's centre, by Style: the mod's picture
-- images/unblockable_<key>.png, in its own colours, listed by the menu from the
-- folder (Scripts/choices/unblockable_style.lua). Off shows nothing; the centre is
-- clear between unblockable attacks. A picture whose file is gone fails to load and
-- shows nothing.
local function unblockablePicture(key)
    key=key or 'fiend'
    if type(key)~='string' or key=='off' or not key:match('^[%w_]+$') then return nil end
    return 'unblockable_'..key:lower()..'.png'
end
local SHOWN,CLEAR={R=1,G=1,B=1,A=1},{R=1,G=1,B=1,A=0}
-- The arrows by Style: Off draws none, and any other Style names one of the mod's
-- pictures, omen_<style>.png (Solid, Chevron and Fancy ship; none show when it does not
-- load). A Style that is not a key is Chevron, the default.
local function styleOf(key)
    if key=='off' then return key,{arrows=false} end
    if type(key)=='string' and key:match('^[%w_]+$') and not tonumber(key) then
        return key,{arrows=true}
    end
    return 'chevron',{arrows=true}
end
-- The parry arrow's two phases, from Attack Incoming (the yellow arrow, before the
-- Perfect Opportunity window) and Perfect Opportunity (how the red arrow takes over):
--   opacity  the yellow arrow's opacity, by Attack Incoming: Normal, Faint, Off
--   travel   the share of its growth and travel the yellow arrow makes, by Perfect
--            Opportunity: End runs its course, Halfway 50%, Start none
--   held     the yellow arrow is held back and the red carries its growth and travel
--            on to the end: unless Attack Incoming is Normal and Perfect Opportunity
--            End (then the yellow runs its course and the red jumps to its full size),
--            or Perfect Opportunity is Off
--   red      whether the Perfect Opportunity window turns the arrow red; Off keeps it
--            yellow until the attack resolves
-- An unknown value of either is the default: Normal, End.
local OPACITY={normal=1,faint=0.35,off=0}
local TRAVEL={['end']=1,halfway=0.5,start=0,off=1}

-- The phases for the settings' Attack Incoming and Perfect Opportunity.
function M.phases(settings)
    local incoming=OPACITY[settings.ParryIncoming] and settings.ParryIncoming or 'normal'
    local perfect=TRAVEL[settings.ParryPerfect] and settings.ParryPerfect or 'end'
    local red=perfect~='off'
    return {held=red and not (incoming=='normal' and perfect=='end'),opacity=OPACITY[incoming],
        travel=TRAVEL[perfect],red=red}
end

-- A range setting as shares, 0 to 1: {low, high}. MCT gives it as {low, high} percent.
local function share(span,low,high)
    if type(span)=='table' and type(span[1])=='number' and type(span[2])=='number' then low,high=span[1],span[2] end
    local function clamp(value) return math.max(0,math.min(1,value/100)) end
    return {clamp(low),clamp(high)}
end

-- The cue settings: percentages of the current look, and choices.
local function config(settings)
    local key,style=styleOf(settings.ParryStyle)
    local phases=M.phases(settings)
    return {
        yellowOpacity=phases.opacity,
        red=phases.red,
        position=Placement.position(settings.ParryPosition),
        -- Movement and Size are shares, 0 to 1: the movement is {appears,
        -- stops} of the way to the screen edge, the size {starting, grown}.
        move=share(settings.ParryMovement,40,60),
        size=share(settings.ParrySize,30,80),
        -- Opacity is a share too: {appears, travelled}, the arrow's own opacity
        -- as it appears and once its travel ends.
        opacity=share(settings.ParryOpacity,50,70),
        style=key,arrows=style.arrows,
        -- The unblockable indicator's Style and its {starting, grown} size as
        -- shares, 0 to 1.
        unblockable=unblockablePicture(settings.UnblockableStyle),
        skull=share(settings.UnblockableSize,60,100),
    }
end

function M.build(hud,layer,screen,settings)
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    local visuals=config(settings)
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    local suffix=Widgets.suffix()
    -- SizeBox > Overlay with the arrows overlay, at the arrows' Position, and a
    -- SizeBox of the same size at the screen's centre with the unblockable image.
    local box=construct('/Script/UMG.SizeBox',tree,'PreymonitionCue'..suffix)
    local stack=construct('/Script/UMG.Overlay',tree,'PreymonitionStack'..suffix)
    local centre=construct('/Script/UMG.SizeBox',tree,'PreymonitionUnblockable'..suffix)
    local skull=construct('/Script/UMG.Image',tree,'PreymonitionCentre'..suffix)
    local arrows=construct('/Script/UMG.Overlay',tree,'PreymonitionArrows'..suffix)
    -- Plain numbers: each arrow's turn, the shape's size and the units along
    -- each axis.
    -- The Style's picture; without it no arrows show (visuals.missing says why).
    local picture
    if visuals.arrows then
        local why
        picture,why=Fancy.load(hud,visuals.style)
        if not picture then visuals.arrows,visuals.missing=false,tostring(why or 'not loaded') end
    end
    local flat={width=Fancy.SIZE.X,height=Fancy.SIZE.Y}
    local angle={}
    for index=1,#ARROWS do angle[index]=Fancy.angle(OUTWARD[index]) end
    local ui={angle=angle,shapeSize={X=flat.width,Y=flat.height},visuals=visuals,
        unit={screen.width*UNIT,screen.height*UNIT},applied={}}
    -- The box is centred where preymonition.placement puts a cue area of its
    -- default size, at the arrows' Position vertically.
    local size,top=Placement.box(screen,visuals.position,Placement.SIZE)
    ui.box=size
    -- How far each arrow may travel from the cue's centre, matching ARROWS. Up and down
    -- travel alike, as far as the nearer of the top and bottom screen edges, so an arrow
    -- from behind moves as much as one from ahead at any Position.
    local middle=top+size/2
    local vertical=math.min(middle,screen.height-middle)
    ui.edge={vertical,vertical,screen.width/2,screen.width/2}
    -- Each arrow is centred at its own size; apply places and sizes it.
    -- An arrow the cue draws, turned for its direction, with its coloured parts
    -- kept per direction; apply moves and scales it.
    local images,parts={},{}
    local function makeArrow(index,name)
        local build=function(class,part) return construct(class,tree,part) end
        local arrow,coloured=Fancy.build(build,name,picture)
        arrow:SetRenderTransformAngle(angle[index])
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
    local arrowsSlot=stack:AddChildToOverlay(arrows)
    arrowsSlot:SetHorizontalAlignment(0)
    arrowsSlot:SetVerticalAlignment(0)
    arrowsSlot:SetPadding({Left=inset,Top=inset,Right=inset,Bottom=inset})
    box:SetContent(stack)
    box:SetWidthOverride(size)
    box:SetHeightOverride(size)
    box:SetRenderOpacity(0)
    centre:SetContent(skull)
    centre:SetWidthOverride(size)
    centre:SetHeightOverride(size)
    centre:SetRenderOpacity(0)
    -- An Image's default brush is solid white: clear until the indicator shows.
    skull:SetColorAndOpacity(CLEAR)
    -- The indicator sizes itself, drawn around its centre; its box keeps its size.
    skull:SetRenderTransformPivot({X=0.5,Y=0.5})
    -- Only the chosen picture loads, now rather than at the first unblockable
    -- attack, mid-combat; the image holds it from here on.
    if visuals.unblockable then
        local textures,why=Images.load(hud,{visuals.unblockable})
        if textures then
            skull:SetBrushFromTexture(textures[1],false)
            ui.picture=true
        else
            ui.pictureMissing=why
        end
    end
    local slot=layer:AddChildToOverlay(box)
    -- Centred horizontally, at its Position vertically.
    slot:SetHorizontalAlignment(2)
    slot:SetVerticalAlignment(1)
    slot:SetPadding({Left=0,Top=top,Right=0,Bottom=0})
    local centreSlot=layer:AddChildToOverlay(centre)
    centreSlot:SetHorizontalAlignment(2)
    centreSlot:SetVerticalAlignment(2)

    local handles={hud=hold(hud,'hud'),layer=hold(layer,'layer'),box=hold(box,'box'),
        stack=hold(stack,'stack'),centre=hold(centre,'centre'),skull=hold(skull,'skull'),arrows=hold(arrows,'arrows'),
        images={},parts={}}
    for index,image in ipairs(images) do handles.images[index]=hold(image,ARROWS[index]) end
    -- An arrow's layers, resolved only to recolour them.
    for index,list in ipairs(parts) do
        handles.parts[index]={}
        for at,entry in ipairs(list) do handles.parts[index][at]={hold(entry[1],'arrow part'),entry[2]} end
    end
    ui.handles=handles
    return ui
end

-- Colours an arrow's layers, as {widget,role}: the glow red for the critical colour and
-- yellow otherwise, the core white.
function paintParts(ui,list,color)
    for _,entry in ipairs(list) do
        entry[1]:SetColorAndOpacity(Fancy.color(entry[2],color==CRITICAL_COLOR))
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

-- Shows or clears the unblockable indicator at the screen's centre, its
-- picture already on the image. Returns the picture's file, true for Style
-- Off, or nil and why when the picture did not load.
function M.skull(ui,shown)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    local file=ui.visuals.unblockable
    ui.skull=shown and file~=nil and ui.picture==true
    ui.applied.skullScale,ui.applied.centre=nil,nil
    if not file then return true end
    if not ui.picture then return nil,ui.pictureMissing end
    if not shown then
        widgets.skull:SetColorAndOpacity(CLEAR)
        return file
    end
    widgets.skull:SetRenderScale({X=skullScale(ui,0),Y=skullScale(ui,0)})
    widgets.skull:SetColorAndOpacity(SHOWN)
    return file
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
-- The render scale that gives the unblockable indicator its size for its grow
-- (0 starting, 1 grown), from Size: the image fills its box, the cue's size.
function skullScale(ui,grow)
    local size=ui.visuals.skull
    local share=size[1]+(size[2]-size[1])*grow
    return ui.unit[2]*(SKULL_SIZE[1]+(SKULL_SIZE[2]-SKULL_SIZE[1])*share)/ui.box
end
-- The render scale that gives the picture the arrow's size along its larger
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
-- tip is at the screen edge.
-- It appears with its tip at the low share and travels to the high one.
function tipDistance(ui,index,offset)
    local move,edge=ui.visuals.move,ui.edge[index]
    local _,tip=fit(ui,index,arrowSize(ui,0))
    -- Where the tip is at 0%, as a share of the way to the edge.
    local start=math.min(1,2*tip/edge)
    local function at(share) return edge*(start+(1-start)*share) end
    local from,to=at(move[1]),at(move[2])
    return from+(to-from)*offset
end

-- Where an arrow's centre sits at a share of its travel, and its scale: the picture
-- scales as a whole, its tip staying where the travel puts it.
local function place(ui,index,offset,grow)
    local scale,tip=fit(ui,index,arrowSize(ui,grow))
    return tipDistance(ui,index,offset)-tip,scale
end
function M.apply(ui,state)
    local widgets=assert(live(ui),'Preymonition cue is no longer valid')
    local visuals=ui.visuals
    set(ui,widgets.box,'box','SetRenderOpacity',state.opacity)
    -- The centre box fades with the cue, at half its opacity, written only while it
    -- shows something. Resolved only then, keeping the per-frame cost of the arrows
    -- alone.
    if ui.skull then
        local centre=assert(MC.get(ui.handles.centre),'Preymonition cue is no longer valid')
        set(ui,centre,'centre','SetRenderOpacity',state.opacity*SKULL_OPACITY)
    end
    for index,arrow in ipairs(state.arrows) do
        local out=OUTWARD[index]
        local centre,scale=place(ui,index,arrow.offset,arrow.grow)
        local x,y=out.X*centre,out.Y*centre
        -- An arrow's opacity runs over its travel from Opacity's low end, as it
        -- appears, to its high end, where it stops. A yellow arrow also takes Attack
        -- Incoming's opacity: a held one until the Perfect Opportunity window opens,
        -- and every one without red.
        local yellow=arrow.held or not visuals.red
        local fade=visuals.opacity[1]+(visuals.opacity[2]-visuals.opacity[1])*arrow.offset
        local opacity=visuals.arrows and arrow.opacity*fade*(yellow and visuals.yellowOpacity or 1) or 0
        local widget,keys=widgets.images[index],KEYS[index]
        set(ui,widget,keys.opacity,'SetRenderOpacity',opacity)
        setPair(ui,widget,keys.scale,'SetRenderScale',scale,scale)
        setPair(ui,widget,keys.translation,'SetRenderTranslation',x,y)
    end
    -- The skull grows from its starting to its grown size.
    if ui.skull then
        local scale=skullScale(ui,state.skull.grow)
        setPair(ui,widgets.skull,'skullScale','SetRenderScale',scale,scale)
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
    local box,centre,layer=MC.get(handles.box),MC.get(handles.centre),MC.get(handles.layer)
    if box then MC.call(box,'SetRenderOpacity',0) end
    if centre then MC.call(centre,'SetRenderOpacity',0) end
    if layer then MC.call(layer,'ClearChildren') end
    for key,handle in pairs(handles) do
        if key=='images' then
            for _,image in ipairs(handle) do MC.release(image) end
        elseif key=='parts' then
            for _,list in ipairs(handle) do
                for _,entry in ipairs(list) do MC.release(entry[1]) end
            end
        else
            MC.release(handle)
        end
    end
end

return M
