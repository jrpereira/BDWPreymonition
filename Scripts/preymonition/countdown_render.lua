-- The countdown's widgets: a time above a thin bar, built in a cue layer. It
-- reads nothing from the game but the clock, through preymonition.combat; preymonition.countdown decides what
-- they show.
local MC=require('mc')
local Combat=require('preymonition.combat')
local Widgets=require('preymonition.widgets')

-- Sizes at the default Size (10%), as shares of the screen height: the bar's
-- width and height, its outline, the text's line above it and the text's font size.
local WIDTH,HEIGHT,OUTLINE,LINE,FONT=0.2,0.015,0.002,0.035,0.02
-- Size, a percentage: SIZE_DEFAULT draws the sizes above. The bar grows linearly
-- to BAR_MAX times at SIZE_MAX; the text's line grows linearly to LINE_MAX of the
-- screen height at SIZE_MAX, keeping the font's share of it.
local SIZE_MIN,SIZE_MAX,SIZE_DEFAULT=5,100,10
local BAR_MAX,LINE_MAX=3,0.7
-- Position puts the bar's bottom this share of the screen height from the top,
-- at the default Size: Below and Above mirror each other around Middle.
local BOTTOMS={below=0.775,middle=0.55,above=0.325}
-- Yellow while counting down, red for the Perfect Opportunity window. The outline and the
-- remaining bar are see-through; the elapsed part is not drawn at all.
local COLORS={
    count={text={R=1,G=0.85,B=0.1,A=1},bar={R=1,G=0.85,B=0.1,A=0.5},outline={R=1,G=0.85,B=0.1,A=0.5}},
    now={text={R=1,G=0.2,B=0,A=1},bar={R=1,G=0.2,B=0,A=0.5},outline={R=1,G=0.2,B=0,A=0.5}},
}
local TEXT_LIBRARY='/Script/Engine.Default__KismetTextLibrary'
local construct=Widgets.construct
local function hold(object,name) return Widgets.hold(object,'countdown',name) end
local M={}

-- A Position setting as one of its keys: an unknown value is Middle, the default.
function M.position(key)
    return BOTTOMS[key] and key or 'middle'
end

-- A Size setting as a percentage within its range: anything else is the default.
function M.size(value)
    if type(value)~='number' or value~=value then return SIZE_DEFAULT end
    return math.max(SIZE_MIN,math.min(SIZE_MAX,value))
end

-- The countdown's measures for a Position and Size on a screen height tall, in
-- screen units: the bar's width, height and outline, the text's line and font
-- size, and the top of the box (the line above the bar).
--
-- Position is set at the default Size. Another Size keeps the box's vertical
-- centre where the default box has it for that Position, so it grows evenly up
-- and down, then moves it back inside the screen if it would cross the top or
-- bottom edge.
function M.layout(height,position,size)
    size=M.size(size)
    local t=(size-SIZE_DEFAULT)/(SIZE_MAX-SIZE_DEFAULT)
    local scale=1+(BAR_MAX-1)*t
    -- Below the default the straight line would shrink the text to nothing by 5%;
    -- there it shrinks with the bar instead.
    local line=math.max(LINE+(LINE_MAX-LINE)*t,LINE*scale)
    local bar=HEIGHT*scale
    local centre=BOTTOMS[M.position(position)]-(LINE+HEIGHT)/2
    local box=line+bar
    local top=math.max(0,math.min(centre-box/2,1-box))
    return {width=height*WIDTH*scale,bar=height*bar,outline=math.max(1,height*OUTLINE*scale),
        line=height*line,font=height*line*FONT/LINE,top=height*top}
end

-- Builds the countdown in the layer, hidden, and returns its handles.
function M.build(hud,layer,screen,position,size)
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    local suffix=Widgets.suffix()
    local layout=M.layout(screen.height,position,size)
    local width,bar,line,outline=layout.width,layout.bar,layout.line,layout.outline
    -- SizeBox > Overlay of the time, centred at the top, and the bar centred along
    -- the bottom. The box is at least the bar's width and widens to a wider time.
    local box=construct('/Script/UMG.SizeBox',tree,'PreymonitionCountdown'..suffix)
    local stack=construct('/Script/UMG.Overlay',tree,'PreymonitionCountdownStack'..suffix)
    local text=construct('/Script/UMG.TextBlock',tree,'PreymonitionCountdownText'..suffix)
    local barBox=construct('/Script/UMG.SizeBox',tree,'PreymonitionCountdownBar'..suffix)
    local barStack=construct('/Script/UMG.Overlay',tree,'PreymonitionCountdownBarStack'..suffix)
    local fill=construct('/Script/UMG.Image',tree,'PreymonitionCountdownFill'..suffix)
    box:SetMinDesiredWidth(width)
    box:SetHeightOverride(line+bar)
    box:SetContent(stack)
    box:SetRenderOpacity(0)
    -- The font keeps its face; only its size changes. When it cannot, the time keeps
    -- the engine's default size and fontFailed says why.
    local sized,why=pcall(function()
        local font=text.Font
        font.Size=math.floor(layout.font+0.5)
        text:SetFont(font)
    end)
    local fontFailed=not sized and tostring(why) or nil
    local textSlot=stack:AddChildToOverlay(text)
    textSlot:SetHorizontalAlignment(2)
    textSlot:SetVerticalAlignment(1)
    barBox:SetWidthOverride(width)
    barBox:SetHeightOverride(bar)
    barBox:SetContent(barStack)
    local barSlot=stack:AddChildToOverlay(barBox)
    barSlot:SetHorizontalAlignment(2)
    barSlot:SetVerticalAlignment(3)
    -- The remaining part fills inside the outline and shrinks towards the left.
    local fillSlot=barStack:AddChildToOverlay(fill)
    fillSlot:SetHorizontalAlignment(0)
    fillSlot:SetVerticalAlignment(0)
    fillSlot:SetPadding({Left=outline,Top=outline,Right=outline,Bottom=outline})
    fill:SetRenderTransformPivot({X=0,Y=0.5})
    -- The outline: a thin line along each side, top, bottom, left, right.
    local lines={}
    for index=1,4 do
        local lineBox=construct('/Script/UMG.SizeBox',tree,'PreymonitionCountdownEdge'..index..suffix)
        local image=construct('/Script/UMG.Image',tree,'PreymonitionCountdownLine'..index..suffix)
        lineBox:SetContent(image)
        local horizontal=index<=2
        if horizontal then lineBox:SetHeightOverride(outline) else lineBox:SetWidthOverride(outline) end
        local slot=barStack:AddChildToOverlay(lineBox)
        -- 0 fills; 1 is top or left, 3 bottom or right.
        slot:SetHorizontalAlignment(horizontal and 0 or (index==3 and 1 or 3))
        slot:SetVerticalAlignment(horizontal and (index==1 and 1 or 3) or 0)
        lines[index]=image
    end
    local slot=layer:AddChildToOverlay(box)
    slot:SetHorizontalAlignment(2)
    slot:SetVerticalAlignment(1)
    slot:SetPadding({Left=0,Top=layout.top,Right=0,Bottom=0})
    local handles={hud=hold(hud,'hud'),layer=hold(layer,'layer'),box=hold(box,'box')}
    -- The widgets drawn in, kept as built: they belong to the HUD's widget tree, and
    -- every frame and request checks the HUD first (M.root). MCT detaches the
    -- countdown before it clears the layer or the HUD is replaced.
    local widgets={box=box,text=text,fill=fill,lines=lines}
    return {handles=handles,widgets=widgets,applied={},fontFailed=fontFailed}
end

-- The countdown's HUD, live for this call, or nil once it is gone: then its widgets
-- are never touched again. One lookup per frame or request.
function M.root(ui)
    local hud=ui and ui.widgets and MC.get(ui.handles.hud)
    if not hud and ui then ui.widgets=nil end
    return hud
end

function M.valid(ui)
    return M.root(ui)~=nil
end

-- A live object in the countdown's world, for calls that need a world context.
function M.context(ui)
    return assert(M.root(ui),'countdown is no longer valid')
end

-- Game time in seconds from hud, the countdown's live HUD: the clock an attack's
-- hit window is in; real: real time, running while the game is paused.
function M.now(hud,real)
    if real then return Combat.now(hud) end
    return Combat.gameTime(hud)
end

-- Shows a view: nil hides the countdown; otherwise {text, fraction 0 to 1,
-- now true for the Perfect Opportunity window}. Writes only what changed. Its HUD
-- was found live in this call (M.root).
function M.show(ui,view)
    local widgets=assert(ui.widgets,'countdown is no longer valid')
    local applied=ui.applied
    local opacity=view and 1 or 0
    if applied.opacity~=opacity then
        applied.opacity=opacity
        widgets.box:SetRenderOpacity(opacity)
    end
    if not view then return end
    local phase=view.now and 'now' or 'count'
    if applied.phase~=phase then
        applied.phase=phase
        local colors=COLORS[phase]
        widgets.text:SetColorAndOpacity({SpecifiedColor=colors.text,ColorUseRule=0})
        widgets.fill:SetColorAndOpacity(colors.bar)
        for _,image in ipairs(widgets.lines) do image:SetColorAndOpacity(colors.outline) end
    end
    if applied.text~=view.text then
        applied.text=view.text
        local library=assert(Combat.default(TEXT_LIBRARY),'KismetTextLibrary unavailable')
        widgets.text:SetText(library:Conv_StringToText(view.text))
    end
    if applied.fraction~=view.fraction then
        applied.fraction=view.fraction
        widgets.fill:SetRenderScale({X=view.fraction,Y=1})
    end
end

-- Clears the countdown's widgets that still exist and drops every handle.
function M.destroy(ui)
    local box,layer=MC.get(ui.handles.box),MC.get(ui.handles.layer)
    if box then MC.call(box,'SetRenderOpacity',0) end
    if layer then MC.call(layer,'ClearChildren') end
    ui.widgets=nil
    for _,handle in pairs(ui.handles) do MC.release(handle) end
end

return M
