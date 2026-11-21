-- Screen edge glows: builds them in a cue layer, lights and tints them. It
-- reads nothing from the game; preymonition.edges decides what they show.
local MC=require('mc')
local Widgets=require('preymonition.widgets')
local Images=require('preymonition.omens_images')

-- Edge indices follow MCT's attack directions: top, bottom, left, right. The
-- game's left and right show on the opposite sides of the screen (seen
-- 2026-10-18), so left lights the right edge and right the left.
local EDGES=4
-- Bands: nested boxes per edge, each a little deeper and faint, so they add up
-- to a gradient fading inward.
local BANDS=6
-- The glow's colours; its opacity comes from Intensity.
-- Critical is a deep red, as the arrows' glow.
local COLOR,CRITICAL={R=1,G=0.67,B=0.19},{R=0.72,G=0.06,B=0.02}
local M={EDGES=EDGES}

-- Gradient pictures, images/edge_<key>_v.png and _h.png, loaded once per file
-- and kept for every later build while the engine keeps them (preymonition.omens_images).
local function gradient(context,key)
    return Images.load(context,{v='edge_'..key..'_v.png',h='edge_'..key..'_h.png'})
end

local construct=Widgets.construct
local function hold(object,name) return Widgets.hold(object,'edges',name) end

local function tinted(color,alpha) return {R=color.R,G=color.G,B=color.B,A=alpha} end

-- A box of the given depth along edge index, holding a fresh image.
local function addBox(tree,edge,index,depth,name)
    local vertical=index<=2
    local box=construct('/Script/UMG.SizeBox',tree,'PreymonitionEdge'..name)
    local image=construct('/Script/UMG.Image',tree,'PreymonitionEdgeImage'..name)
    box:SetContent(image)
    if vertical then box:SetHeightOverride(depth) else box:SetWidthOverride(depth) end
    local slot=edge:AddChildToOverlay(box)
    -- 0 fills; 1 is top or left, 3 bottom or right.
    slot:SetHorizontalAlignment(vertical and 0 or (index==3 and 3 or 1))
    slot:SetVerticalAlignment(vertical and (index==1 and 1 or 3) or 0)
    return image
end

-- One edge: an overlay over the whole layer, faded as a whole, holding its
-- bands or its gradient picture.
local function buildEdge(tree,layer,index,look,suffix,images)
    local edge=construct('/Script/UMG.Overlay',tree,'PreymonitionEdge'..index..suffix)
    edge:SetRenderOpacity(0)
    local slot=layer:AddChildToOverlay(edge)
    slot:SetHorizontalAlignment(0)
    slot:SetVerticalAlignment(0)
    if look.textures then
        -- The pictures are opaque at the screen edge: _v at its top, _h at its
        -- left; the bottom and right edges show them mirrored.
        -- Its own name: the edge's overlay already holds PreymonitionEdge<index><suffix>,
        -- and the engine refuses a second object of another class under one name (crash).
        local image=addBox(tree,edge,index,look.depth,'Gradient'..index..suffix)
        image:SetBrushFromTexture(index<=2 and look.textures.v or look.textures.h,false)
        image:SetRenderTransformPivot({X=0.5,Y=0.5})
        image:SetRenderScale({X=index==3 and -1 or 1,Y=index==2 and -1 or 1})
        image:SetColorAndOpacity(look.color)
        images[#images+1]=image
    else
        for band=1,BANDS do
            local image=addBox(tree,edge,index,look.depth*band/BANDS,index..'_'..band..suffix)
            image:SetColorAndOpacity(look.color)
            images[#images+1]=image
        end
    end
    return edge
end

-- Each band's opacity for the rim, where all of them overlap, to reach intensity.
function M.bandAlpha(intensity)
    return 1-(1-intensity)^(1/BANDS)
end

-- Builds the four edges in the layer, unlit, and returns their handles.
-- options: gradient ('bands' or a picture key), thickness (share of the
-- shorter screen side), intensity (opacity at the screen edge, 0..1). A picture
-- that cannot load draws bands; ui.fallback says why.
function M.build(hud,layer,screen,options)
    options=options or {}
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    local suffix=Widgets.suffix()
    local intensity=options.intensity or 0.5
    local look={depth=math.min(screen.width,screen.height)*(options.thickness or 0.08)}
    local fallback
    if options.gradient and options.gradient~='bands' then
        local ok,textures,why=pcall(gradient,hud,options.gradient)
        if ok and textures then look.textures=textures
        elseif ok then fallback=tostring(why or 'not loaded')
        else fallback=tostring(textures) end
    end
    local alpha=look.textures and intensity or M.bandAlpha(intensity)
    local colors={normal=tinted(COLOR,alpha),critical=tinted(CRITICAL,alpha)}
    look.color=colors.normal
    local edges,images={},{}
    for index=1,EDGES do edges[index]=buildEdge(tree,layer,index,look,suffix,images) end
    local handles={hud=hold(hud,'hud'),layer=hold(layer,'layer')}
    -- The edges and their images, kept as built: they belong to the HUD's widget
    -- tree, and every request checks the HUD first (M.root). MCT detaches the edges
    -- before it clears the layer or the HUD is replaced.
    return {handles=handles,widgets={edges=edges,images=images},lit={},critical=false,colors=colors,
        gradient=look.textures and options.gradient or 'bands',fallback=fallback}
end

-- The edges' HUD, live for this call, or nil once it is gone: then their widgets
-- are never touched again. One lookup per request.
function M.root(ui)
    local hud=ui and ui.widgets and MC.get(ui.handles.hud)
    if not hud and ui then ui.widgets=nil end
    return hud
end

-- Lights the edges in lit (index -> true) and puts the others out; critical
-- tints every image red. Writes only what changed; the images are touched only
-- when the tint changes. Their HUD was found live in this call (M.root).
function M.show(ui,lit,critical)
    local widgets=assert(ui.widgets,'edges are no longer valid')
    for index,edge in ipairs(widgets.edges) do
        local on=lit[index]==true
        if (ui.lit[index]==true)~=on then
            ui.lit[index]=on
            edge:SetRenderOpacity(on and 1 or 0)
        end
    end
    critical=critical==true
    if ui.critical~=critical then
        ui.critical=critical
        local color=critical and ui.colors.critical or ui.colors.normal
        for _,image in ipairs(widgets.images) do image:SetColorAndOpacity(color) end
    end
end

-- Clears the edges that still exist and drops every handle.
function M.destroy(ui)
    local layer=MC.get(ui.handles.layer)
    if layer then MC.call(layer,'ClearChildren') end
    ui.widgets=nil
    for _,handle in pairs(ui.handles) do MC.release(handle) end
end

return M
