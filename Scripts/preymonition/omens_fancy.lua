-- An arrow (every Style but Off: Solid, Chevron, Fancy and any other): one picture
-- from the mod's images folder, omen_<style>.png, holding two layers side by side, each an
-- arrow pointing right on a transparent background: the glow on the left half and the
-- white core on the right. The glow is drawn tinted,
-- yellow or red in the Perfect Opportunity window, and the core on top, untinted. Each half
-- is laid out like Fancy's art (ART and TIP below). The game loads the picture as a texture
-- when the cue attaches.
local Images=require('preymonition.omens_images')
local M={}

function M.file(style) return 'omen_'..style..'.png' end
-- One half's size in pixels, and where its arrow is (alpha above 8): its back column and
-- its tip, the tip's right edge and middle row. The arms reach the full height; the rest
-- is transparent margin.
local ART={width=887,height=1774}
local TIP={back=259,x=687,y=866.5}
-- The arrow box: the arrow's span, the full height, in design units with the height
-- UNITS. Slate shrinks a centred box larger than the arrows'
-- panel, so it must stay this small (the panel is about 400 at 1080p).
local UNITS=100
local K=UNITS/ART.height
M.SIZE={X=(TIP.x-TIP.back)*K,Y=UNITS}
-- The glow's tint by state (the core stays white).
M.NORMAL={R=1,G=0.75,B=0.10,A=1}
-- A deep red, so the glow reads deep rather than orange.
M.CRITICAL={R=0.72,G=0.06,B=0.02,A=1}

-- Where a half goes in the box, in design units: its tip on the box's right edge, at
-- mid-height, on the arrow's axis; and its size.
function M.placement()
    return {X=M.SIZE.X-TIP.x*K,Y=M.SIZE.Y/2-TIP.y*K},{X=ART.width*K,Y=ART.height*K}
end

-- Loads a style's picture as a texture, context being any live object in the player's
-- world. Returns the texture and the folder, or nil and why.
function M.load(context,style)
    local textures,where=Images.load(context,{picture=M.file(style)})
    if not textures then return nil,where end
    return textures.picture,where
end

-- The turn that points the right-pointing picture in a screen direction.
function M.angle(direction)
    return math.deg(math.atan(direction.Y,direction.X))%360
end

-- Builds one painted arrow from construct(classPath,name): a SizeBox the arrow's span,
-- holding a canvas with the two layers placed by M.placement, the glow under the core.
-- Each layer is a box one half in size that clips the picture, drawn at its full width
-- and shifted to show its half. Returns the box and its layers as {image,role}.
function M.build(construct,name,texture)
    local box=construct('/Script/UMG.SizeBox',name)
    local canvas=construct('/Script/UMG.CanvasPanel',name..'Canvas')
    box:SetContent(canvas)
    box:SetWidthOverride(M.SIZE.X)
    box:SetHeightOverride(M.SIZE.Y)
    box:SetRenderTransformPivot({X=0.5,Y=0.5})
    local position,size=M.placement()
    local images={}
    for half,role in ipairs({'glow','core'}) do
        local clip=construct('/Script/UMG.CanvasPanel',name..role)
        clip:SetClipping(1)
        local slot=canvas:AddChildToCanvas(clip)
        slot:SetAlignment({X=0,Y=0})
        slot:SetPosition(position)
        slot:SetSize(size)
        local image=construct('/Script/UMG.Image',name..role..'Picture')
        -- Without a picture (Off, or one that did not load) the arrow stays hidden.
        if texture then image:SetBrushFromTexture(texture,false) end
        local inner=clip:AddChildToCanvas(image)
        inner:SetAlignment({X=0,Y=0})
        inner:SetPosition({X=-(half-1)*size.X,Y=0})
        inner:SetSize({X=2*size.X,Y=size.Y})
        images[#images+1]={image,role}
    end
    return box,images
end

-- The colour a layer takes: the glow yellow, or red while the arrow is critical; the core
-- white.
function M.color(role,critical)
    if role=='core' then return {R=1,G=1,B=1,A=1} end
    return critical and M.CRITICAL or M.NORMAL
end

return M
