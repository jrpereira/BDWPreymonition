-- Screen edge glows: builds them in a cue layer, lights and tints them. It
-- reads nothing from the game; preymonition.edges decides what they show.
local MC=require('mc')

-- Edge indices follow MCT's attack directions: top, bottom, left, right. The
-- game's left and right show on the opposite sides of the screen (seen
-- 2026-10-18), so left lights the right edge and right the left.
local EDGES=4
-- Nested bands per edge, each a little deeper and faint, so they add up to a
-- gradient fading inward; depth is a share of the shorter screen side.
local BANDS,DEPTH=6,0.08
local COLOR,CRITICAL={R=1,G=0.67,B=0.19,A=0.1},{R=1,G=0.2,B=0,A=0.1}
-- Widget names stay unique across Lua reloads, like the center cue's.
local generation=0
local nonce=string.format('%06x',math.random(0,0xffffff))
local M={EDGES=EDGES}

local function construct(classPath,outer,name)
    local class=assert(StaticFindObject(classPath),'missing widget class: '..classPath)
    local object=StaticConstructObject(class,outer,FName(name),0x40)
    assert(MC.valid(object),'widget construction failed: '..name)
    object:SetVisibility(3)
    return object
end

local function hold(object,name)
    return assert(MC.hold(object),'edges cannot keep '..name)
end

-- One edge: an overlay over the whole layer holding its bands, faded as a whole.
local function buildEdge(tree,layer,index,depth,suffix,bands)
    local edge=construct('/Script/UMG.Overlay',tree,'PreymonitionEdge'..index..suffix)
    edge:SetRenderOpacity(0)
    local slot=layer:AddChildToOverlay(edge)
    slot:SetHorizontalAlignment(0)
    slot:SetVerticalAlignment(0)
    local vertical=index<=2
    for band=1,BANDS do
        local box=construct('/Script/UMG.SizeBox',tree,'PreymonitionEdge'..index..'_'..band..suffix)
        local image=construct('/Script/UMG.Image',tree,'PreymonitionEdgeBand'..index..'_'..band..suffix)
        image:SetColorAndOpacity(COLOR)
        bands[#bands+1]=image
        box:SetContent(image)
        local thickness=depth*band/BANDS
        if vertical then box:SetHeightOverride(thickness) else box:SetWidthOverride(thickness) end
        local bandSlot=edge:AddChildToOverlay(box)
        -- 0 fills; 1 is top or left, 3 bottom or right.
        bandSlot:SetHorizontalAlignment(vertical and 0 or (index==3 and 3 or 1))
        bandSlot:SetVerticalAlignment(vertical and (index==1 and 1 or 3) or 0)
    end
    return edge
end

-- Builds the four edges in the layer, unlit, and returns their handles.
function M.build(hud,layer,screen)
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    generation=generation+1
    local suffix=nonce..'_'..generation
    local depth=math.min(screen.width,screen.height)*DEPTH
    local edges,bands={},{}
    for index=1,EDGES do edges[index]=buildEdge(tree,layer,index,depth,suffix,bands) end
    local handles={hud=hold(hud,'hud'),layer=hold(layer,'layer'),edges={},bands={}}
    for index,edge in ipairs(edges) do handles.edges[index]=hold(edge,'edge') end
    for index,band in ipairs(bands) do handles.bands[index]=hold(band,'edge band') end
    return {handles=handles,lit={},critical=false}
end

-- The edges as live wrappers for this call, or nil once any is gone.
local function live(ui)
    local widgets={hud=MC.get(ui.handles.hud),edges={},bands={}}
    if not widgets.hud then return nil end
    for _,list in ipairs({'edges','bands'}) do
        for index,handle in ipairs(ui.handles[list]) do
            widgets[list][index]=MC.get(handle)
            if not widgets[list][index] then return nil end
        end
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

-- Whether an object is in the same world as the edges' HUD.
function M.sameWorld(ui,object)
    local hud=MC.get(ui.handles.hud)
    if not (hud and MC.valid(object)) then return false end
    local own=worldName(hud)
    return own~=nil and own==worldName(object)
end

-- Lights the edges in lit (index -> true) and puts the others out; critical
-- tints every band red. Writes only what changed.
function M.show(ui,lit,critical)
    local widgets=assert(live(ui),'edges are no longer valid')
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
        for _,band in ipairs(widgets.bands) do band:SetColorAndOpacity(critical and CRITICAL or COLOR) end
    end
end

-- Clears the edges that still exist and drops every handle.
function M.destroy(ui)
    local layer=MC.get(ui.handles.layer)
    if layer then MC.call(layer,'ClearChildren') end
    for key,handle in pairs(ui.handles) do
        if key=='edges' or key=='bands' then
            for _,item in ipairs(handle) do MC.release(item) end
        else
            MC.release(handle)
        end
    end
end

return M
