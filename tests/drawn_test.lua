package.path='Preymonition/Scripts/?.lua;'..package.path
local Drawn=require('preymonition.drawn')
local function near(a,b) return math.abs(a-b)<1e-6 end

-- Turns: a positive angle turns a widget clockwise on screen, so an upward
-- arrow turns 90 to point right and 270 to point left.
for _,case in ipairs({{0,-1,0},{0,1,180},{1,0,90},{-1,0,270}}) do
    assert(near(Drawn.angle({X=case[1],Y=case[2]}),case[3]),'up, down, right, left')
end
-- A rectangle's angle lays its width along its axis: clockwise on screen,
-- where y runs down.
local function laid(part)
    local angle=math.rad(part.angle)
    return near(math.cos(angle),part.axis.X) and near(math.sin(angle),part.axis.Y)
end

-- Solid: three nested triangles with a 135 degree tip, outline first, each
-- drawn as two clipped halves.
local solid=Drawn.layout('solid')
local height=50/math.tan(math.rad(67.5))
assert(solid.width==100 and near(solid.height,height),'the outline fills the box: base 100, a 135 degree tip')
assert(#solid.parts==6,'three layers of two halves')
local roles={}
for index,part in ipairs(solid.parts) do
    roles[index]=part.role
    assert(part.kind=='half' and laid(part.fill),'each half fills from its side')
    -- Each side slopes 22.5 degrees from the base: the tip is 135 degrees.
    assert(near(math.abs(part.fill.axis.Y/part.fill.axis.X),math.tan(math.rad(22.5))),'a 135 degree tip')
end
assert(table.concat(roles,' ')=='outline outline inset inset front front','back to front')
-- A layer's triangle, from its left half: base corner, tip and base.
local function triangleOf(left,right)
    local base=(left.clip.width+right.clip.width-0.5)
    return {left=left.clip.x,bottom=left.clip.y+left.clip.height,tip=left.clip.y,base=base,x=left.clip.x+base/2}
end
local outline=triangleOf(solid.parts[1],solid.parts[2])
local inset=triangleOf(solid.parts[3],solid.parts[4])
local front=triangleOf(solid.parts[5],solid.parts[6])
assert(near(outline.left,0) and near(outline.bottom,height) and near(outline.tip,0) and near(outline.base,100),
    'the outline is the whole box')
for _,layer in ipairs({inset,front}) do
    assert(near(layer.x,50) and near(layer.bottom-layer.tip,layer.base/2/math.tan(math.rad(67.5))),
        'each layer is centred with the same tip')
end
-- Each layer sits a uniform distance inside the one around it: its base that
-- far up, and its base corner that far from the outer slanted side.
local function gap(outer,inner)
    local bottom=outer.bottom-inner.bottom
    -- The outer left side's line, through its base corner and tip, as a*x+b*y=c.
    local a,b=outer.bottom-outer.tip,outer.base/2
    local c=a*outer.left+b*outer.bottom
    -- The inner corner's distance from that line, measured inward.
    local side=(a*inner.left+b*inner.bottom-c)/math.sqrt(a*a+b*b)
    return bottom,side
end
local bottom,side=gap(outline,inset)
assert(near(bottom,3) and near(side,3),'a thin outline, 3 all round')
bottom,side=gap(inset,front)
assert(near(bottom,4) and near(side,4),'a thin inset, 4 all round')

-- Chevron: two arms meeting at a 135 degree tip, each an outline, an inset and a front.
local chevron=Drawn.layout('chevron')
assert(#chevron.parts==6,'two arms in three layers')
roles={}
for index,part in ipairs(chevron.parts) do
    roles[index]=part.role
    assert(part.kind=='rect' and laid(part),'each arm is laid along its side')
    -- Each arm runs 67.5 degrees from the axis.
    assert(near(math.abs(part.axis.X),math.sin(math.rad(67.5))) and near(part.axis.Y,math.cos(math.rad(67.5))),'a 135 degree tip')
end
assert(table.concat(roles,' ')=='outline outline inset inset front front','back to front')
-- Every corner lies in the box, which the outline touches on every side; the
-- tip, the topmost point, is centred.
local minX,minY,maxX,maxY,tipX=math.huge,math.huge,-math.huge,-math.huge,nil
for _,part in ipairs(chevron.parts) do
    local across={X=-part.axis.Y,Y=part.axis.X}
    for _,a in ipairs({-1,1}) do
        for _,b in ipairs({-1,1}) do
            local x=part.x+a*part.width/2*part.axis.X+b*part.height/2*across.X
            local y=part.y+a*part.width/2*part.axis.Y+b*part.height/2*across.Y
            if y<minY-1e-9 then tipX=x end
            minX,minY,maxX,maxY=math.min(minX,x),math.min(minY,y),math.max(maxX,x),math.max(maxY,y)
        end
    end
end
assert(near(minX,0) and near(minY,0) and near(maxX,chevron.width) and near(maxY,chevron.height),'the box bounds the shape')
assert(near(tipX,chevron.width/2),'the tip is centred')

-- Skew: the angle, x shear and scale that map a widget's width and height onto
-- two vectors, as Slate applies them: scale, then shear along x, then turn.
local function apply(angle,shear,sx,sy,p)
    local x,y=p.X*sx,p.Y*sy
    x=x+y*math.tan(math.rad(shear))
    local c,s=math.cos(math.rad(angle)),math.sin(math.rad(angle))
    return {X=x*c-y*s,Y=x*s+y*c}
end
for _,case in ipairs({{{X=1,Y=0},{X=0,Y=1}},{{X=0.5,Y=0.3},{X=-0.2,Y=0.9}},{{X=-0.7,Y=0.4},{X=-0.1,Y=-1.2}}}) do
    local angle,shear,sx,sy=Drawn.skew(case[1],case[2])
    local a,b=apply(angle,shear,sx,sy,{X=1,Y=0}),apply(angle,shear,sx,sy,{X=0,Y=1})
    assert(near(a.X,case[1].X) and near(a.Y,case[1].Y) and near(b.X,case[2].X) and near(b.Y,case[2].Y),
        'skew reproduces both edges')
end
-- Reshaping through no change keeps each rectangle, now centred on the arrow.
local same=Drawn.reshape(chevron,function(p) return p end)
assert(near(same.width,chevron.width) and #same.parts==6,'the same box')
for index,part in ipairs(same.parts) do
    local before=chevron.parts[index]
    assert(near(part.x,before.x) and near(part.shear,0) and near(part.scale.X,1) and near(part.scale.Y,1)
        and near(math.cos(math.rad(part.angle-before.angle)),1),'the same rectangles')
end
-- A squash to half height, as a ground plane seen from 30 degrees above, turns
-- the arms flatter: shorter across, still meeting at the tip.
local squashed=Drawn.reshape(chevron,function(p) return {X=p.X,Y=p.Y/2} end)
assert(near(squashed.height,same.height/2) and near(squashed.width,same.width),'half as high, as wide')

-- Growing: the shape widens by extending its lines, keeping their thickness.
-- A chevron arm stretches its length from the tip; widening by e takes each arm
-- e/2 further out sideways, so its length grows by e/(2 sin 67.5).
local e=20
for _,part in ipairs(chevron.parts) do
    local x,y=Drawn.growScale(part,e)
    assert(part.pivot.X==0 and near(y,1) and near(x*part.width-part.width,e/(2*math.sin(math.rad(67.5)))),
        'every arm extends by the same length, as thick as before')
end
-- A triangle's layers grow about their tips: every base drops by the same
-- length, so the outline and inset stay as thick, and the outline widens by e.
local drops={}
for index,part in ipairs(solid.parts) do
    local x,y=Drawn.growScale(part,e)
    assert(near(x,y),'a layer grows evenly')
    drops[index]=part.clip.height*(y-1)
end
assert(near(solid.parts[1].clip.height*(1+e/100),solid.parts[1].clip.height+drops[1]),'the outline widens by e')
for index=2,#drops do assert(near(drops[index],drops[1]),'every base drops alike') end

-- Colours: outlines black, insets a dimmer shade, fronts the arrow colour.
local lit={R=1,G=0.67,B=0.19,A=1}
local dim=Drawn.color('inset',lit)
assert(Drawn.color('outline',lit).R==0 and Drawn.color('front',lit)==lit,'outline black, front as given')
assert(near(dim.R,0.55) and near(dim.G,0.67*0.55) and dim.A==1,'the inset is dimmer, as opaque')

print('PASS: drawn arrows have a 135 degree tip, nest their outline, inset and front, and colour them')
