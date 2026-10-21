-- Arrows the cue draws itself, from solid images: a Solid triangle or a
-- Chevron, each a thin black outline around a thin inset in a dimmer shade of
-- the arrow's colour, around the arrow's colour. Shapes are laid out pointing up
-- in design units; the cue turns, sizes and places the whole arrow. An arrow
-- grows by extending its lines from the tip, keeping its outline and inset
-- thickness: see M.growScale.
local M={}

-- The tip's angle: wide, 135 degrees; HALF is each side's angle from the axis.
local TIP=135
local HALF=math.rad(TIP/2)
-- Design units: the outline, the inset inside it, and each shape's size.
local OUTLINE,INSET=3,4
-- Solid: the outline's base; the tip's angle sets its height.
local BASE=100
-- Chevron: each arm's length and thickness, at the inset's outer edge.
local ARM,THICKNESS=70,16
-- The inset is this share of the arrow's colour.
local DIM=0.55
local BLACK={R=0,G=0,B=0,A=1}

-- The render angle that lays a widget's width along a screen direction. Slate
-- turns a widget clockwise on screen for a positive angle (its FQuat2D takes x
-- towards y, and y runs down).
function M.turn(direction)
    return math.deg(math.atan(direction.Y,direction.X))
end
-- The turn that points an upward arrow in a screen direction.
function M.angle(direction)
    return (M.turn(direction)-M.turn({X=0,Y=-1}))%360
end

-- The colour a part takes for an arrow colour: outlines stay black.
function M.color(role,color)
    if role=='outline' then return BLACK end
    if role=='inset' then return {R=color.R*DIM,G=color.G*DIM,B=color.B*DIM,A=color.A} end
    return color
end

-- A rectangle with its width along axis: its centre, size, and the render angle.
local function rect(role,centre,axis,width,height)
    return {kind='rect',role=role,x=centre.X,y=centre.Y,width=width,height=height,axis=axis,angle=M.turn(axis)}
end
local function point(x,y) return {X=x,Y=y} end
local function add(a,b,scale) return point(a.X+b.X*scale,a.Y+b.Y*scale) end

-- The Solid triangle, its sides offset t inward from the outline's: the
-- outline's triangle shrunk about its incentre. Returns base and height, and how
-- far its base sits above the outline's.
local function triangle(t)
    local height=BASE/2/math.tan(HALF)
    local side=BASE/2/math.sin(HALF)
    local radius=(BASE*height/2)/((BASE+2*side)/2)
    local k=(radius-t)/radius
    return BASE*k,height*k,t
end

-- A triangle pointing up, base centred at x, base y, as two halves: each half is
-- a canvas clipping a large rectangle whose edge is that half's side. The
-- halves overlap by SEAM so no gap shows between them.
local SEAM=0.25
local function solid(role,x,bottom,base,height,parts)
    local top=bottom-height
    local slant=math.sqrt((base/2)^2+height^2)
    -- Large enough to cover a half however it is turned.
    local cover=2*(base+height)
    for _,side in ipairs({-1,1}) do
        local corner=point(x+side*base/2,bottom)
        -- Along the side from the base corner to the tip, and inward from it.
        local along=point(-side*base/2/slant,-height/slant)
        local inward=point(-side*height/slant,base/2/slant)
        local clip={x=side<0 and x-base/2 or x-SEAM,y=top,width=base/2+SEAM,height=height}
        local middle=add(corner,along,slant/2)
        local centre=add(middle,inward,cover/2)
        -- In the clip's own coordinates.
        local fill=rect(role,point(centre.X-clip.x,centre.Y-clip.y),along,cover,cover)
        -- A half grows about the tip, at its clip's top inner corner.
        local tipX=(x-clip.x)/clip.width
        parts[#parts+1]={kind='half',role=role,clip=clip,fill=fill,pivot={X=tipX,Y=0},grow={height=height}}
    end
end

-- The shape's parts, back to front, in design units with the box's top left at
-- 0,0, and the box's size.
function M.layout(shape)
    local parts={}
    if shape=='solid' then
        local _,height=triangle(0)
        for _,layer in ipairs({{'outline',0},{'inset',OUTLINE},{'front',OUTLINE+INSET}}) do
            local base,tall,lift=triangle(layer[2])
            solid(layer[1],BASE/2,height-lift,base,tall,parts)
        end
        -- Every layer's base drops by the same length as the outline widens.
        for _,part in ipairs(parts) do part.grow.per=height/BASE end
        return {width=BASE,height=height,parts=parts}
    end
    assert(shape=='chevron','unknown arrow shape: '..tostring(shape))
    -- Each arm runs from the tip (0,0) along its side and is THICKNESS deep
    -- inward. A layer offset t starts where its outer edge crosses the axis, so
    -- the two arms meet in a mitre.
    local sin,cos=math.sin(HALF),math.cos(HALF)
    local list={}
    for _,layer in ipairs({{'outline',-OUTLINE},{'inset',0},{'front',INSET}}) do
        local role,t=layer[1],layer[2]
        for _,side in ipairs({-1,1}) do
            local along=point(side*sin,cos)
            local inward=point(-side*cos,sin)
            local u0,u1,v0,v1=t*cos/sin,ARM-t,t,THICKNESS-t
            local centre=add(add(point(0,0),along,(u0+u1)/2),inward,(v0+v1)/2)
            list[#list+1]={role=role,centre=centre,along=along,inward=inward,width=u1-u0,height=v1-v0}
        end
    end
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    for _,r in ipairs(list) do
        for _,su in ipairs({-1,1}) do
            for _,sv in ipairs({-1,1}) do
                local corner=add(add(r.centre,r.along,su*r.width/2),r.inward,sv*r.height/2)
                minX,minY=math.min(minX,corner.X),math.min(minY,corner.Y)
                maxX,maxY=math.max(maxX,corner.X),math.max(maxY,corner.Y)
            end
        end
    end
    -- An arm grows from its tip end, the start of its width: every layer
    -- extends by the same length, so the shape widens by twice its sideways share.
    for _,r in ipairs(list) do
        local part=rect(r.role,point(r.centre.X-minX,r.centre.Y-minY),r.along,r.width,r.height)
        part.grow={length=r.width,per=1/(2*sin)}
        part.pivot={X=0,Y=0.5}
        parts[#parts+1]=part
    end
    return {width=maxX-minX,height=maxY-minY,parts=parts}
end

-- How a part's grown widget scales when the shape is extra design units wider:
-- an arm's length extends, a triangle's layer grows about its tip, all by the
-- same length, so outlines and insets keep their thickness. base is the part's
-- own scale when reshaped.
function M.growScale(part,extra)
    local grow,base=part.grow,part.scale or {X=1,Y=1}
    if grow.length then
        local stretch=(grow.length+extra*grow.per)/grow.length
        return base.X*stretch,base.Y
    end
    local stretch=(grow.height+extra*grow.per)/grow.height
    return stretch,stretch
end

-- The render transform that maps a widget's own width and height onto two
-- screen vectors, per unit of its size: Slate scales, then shears along x, then
-- turns. Returns the angle, the x shear angle, both in degrees, and the scale.
function M.skew(across,down)
    local angle=math.atan(across.Y,across.X)
    local cos,sin=math.cos(angle),math.sin(angle)
    local scaleX=math.sqrt(across.X^2+across.Y^2)
    -- The height vector turned back: x is shear times the y scale.
    local x,y=cos*down.X+sin*down.Y,-sin*down.X+cos*down.Y
    return math.deg(angle),math.deg(math.atan(x/y)),scaleX,y
end

-- The chevron's rectangles moved through map, a function from a point in the
-- shape's own design units (centred, pointing up) to where it should show,
-- relative to the arrow's centre. Each rectangle becomes the parallelogram its
-- moved centre and edges span. Returns a layout like M.layout's, centred on
-- the arrow's centre.
function M.reshape(layout,map)
    local parts,reach={},{X=0,Y=0}
    for _,part in ipairs(layout.parts) do
        assert(part.kind=='rect','only rectangles reshape')
        local centre=point(part.x-layout.width/2,part.y-layout.height/2)
        local across=part.axis
        local down=point(-across.Y,across.X)
        local function edge(direction,length)
            local a,b=map(add(centre,direction,length/2)),map(add(centre,direction,-length/2))
            return point((a.X-b.X)/length,(a.Y-b.Y)/length)
        end
        local middle=map(centre)
        local acrossNow,downNow=edge(across,part.width),edge(down,part.height)
        local angle,shear,scaleX,scaleY=M.skew(acrossNow,downNow)
        for _,su in ipairs({-1,1}) do
            for _,sv in ipairs({-1,1}) do
                local corner=add(add(middle,acrossNow,su*part.width/2),downNow,sv*part.height/2)
                reach.X,reach.Y=math.max(reach.X,math.abs(corner.X)),math.max(reach.Y,math.abs(corner.Y))
            end
        end
        parts[#parts+1]={kind='rect',role=part.role,x=middle.X,y=middle.Y,width=part.width,height=part.height,
            angle=angle,shear=shear,scale={X=scaleX,Y=scaleY},grow=part.grow,pivot=part.pivot}
    end
    -- A box centred on the arrow's centre, so it turns and scales about it.
    for _,part in ipairs(parts) do part.x,part.y=part.x+reach.X,part.y+reach.Y end
    return {width=2*reach.X,height=2*reach.Y,parts=parts}
end

-- Adds a solid image to a canvas, centred at a rectangle's centre, sized and
-- turned, and sheared and scaled when reshaped.
local function place(construct,canvas,name,part)
    local image=construct('/Script/UMG.Image',name)
    image:SetRenderTransformPivot(part.pivot or {X=0.5,Y=0.5})
    local slot=canvas:AddChildToCanvas(image)
    slot:SetAlignment({X=0.5,Y=0.5})
    slot:SetPosition({X=part.x,Y=part.y})
    slot:SetSize({X=part.width,Y=part.height})
    image:SetRenderTransformAngle(part.angle)
    if part.shear then
        image:SetRenderShear({X=part.shear,Y=0})
        image:SetRenderScale(part.scale)
    end
    return image
end

-- Builds a drawn arrow from construct(classPath,name): a SizeBox the shape's
-- size holding a canvas of solid images, moved through map when given (see
-- M.reshape). Returns the box, its size, its coloured images as {image,role},
-- and the widgets that grow as {widget,part} (see M.growScale).
function M.build(construct,name,shape,map)
    local layout=M.layout(shape)
    if map then layout=M.reshape(layout,map) end
    local box=construct('/Script/UMG.SizeBox',name)
    local canvas=construct('/Script/UMG.CanvasPanel',name..'Canvas')
    box:SetContent(canvas)
    box:SetWidthOverride(layout.width)
    box:SetHeightOverride(layout.height)
    box:SetRenderTransformPivot({X=0.5,Y=0.5})
    local images,growers={},{}
    for index,part in ipairs(layout.parts) do
        local image
        if part.kind=='rect' then
            image=place(construct,canvas,name..'Part'..index,part)
            growers[#growers+1]={image,part}
        else
            local clip=construct('/Script/UMG.CanvasPanel',name..'Clip'..index)
            clip:SetClipping(1)
            local slot=canvas:AddChildToCanvas(clip)
            slot:SetAlignment({X=0,Y=0})
            slot:SetPosition({X=part.clip.x,Y=part.clip.y})
            slot:SetSize({X=part.clip.width,Y=part.clip.height})
            clip:SetRenderTransformPivot(part.pivot)
            image=place(construct,clip,name..'Part'..index,part.fill)
            growers[#growers+1]={clip,part}
        end
        images[#images+1]={image,part.role}
    end
    return box,{X=layout.width,Y=layout.height},images,growers
end

return M
