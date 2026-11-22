-- The countdown's widgets: a time above a thin bar, or either alone, built in a cue layer. It
-- reads nothing from the game but the clock, through preymonition.combat; preymonition.countdown decides what
-- they show.
local MC=require('mc')
local Combat=require('preymonition.combat')
local Widgets=require('preymonition.widgets')
local Cue=require('preymonition.omens_render')

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
-- Style: the time above the bar (full), the bar alone or the time alone.
local STYLES={full=true,bar=true,label=true}
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

-- A Style setting as one of its keys: an unknown value is Full, the default.
function M.style(key)
    return STYLES[key] and key or 'full'
end

-- An Opacity setting as {appears, at the window}, shares 0 to 1; anything that is
-- not a range is the default, 50% to 70% (the Omens' arrows read theirs alike).
function M.opacity(span)
    return Cue.share(span,50,70)
end

-- A size as a percentage within Size's scale: anything else is the default.
function M.size(value)
    if type(value)~='number' or value~=value then return SIZE_DEFAULT end
    return math.max(SIZE_MIN,math.min(SIZE_MAX,value))
end

-- A Size setting, a range, as {appears, at the window}, percentages within its
-- scale; anything that is not a range is the default, 10% at both ends.
function M.sizes(span)
    if type(span)~='table' or type(span[1])~='number' or type(span[2])~='number' then
        return {SIZE_DEFAULT,SIZE_DEFAULT}
    end
    local low,high=M.size(span[1]),M.size(span[2])
    return {math.min(low,high),math.max(low,high)}
end

-- The countdown's measures for a Position, Size and Style on a screen height tall,
-- in screen units: the bar's width, height and outline, the text's line and font
-- size, the box's height (the line above the bar, or the one Style shows) and its top.
--
-- Position is set at the default Size and Style. Another Size or Style keeps the
-- box's vertical centre where the default box has it for that Position, so it
-- grows evenly up and down, then moves it back inside the screen if it would cross
-- the top or bottom edge.
function M.layout(height,position,size,style)
    size=M.size(size)
    local t=(size-SIZE_DEFAULT)/(SIZE_MAX-SIZE_DEFAULT)
    local scale=1+(BAR_MAX-1)*t
    -- Below the default the straight line would shrink the text to nothing by 5%;
    -- there it shrinks with the bar instead.
    local line=math.max(LINE+(LINE_MAX-LINE)*t,LINE*scale)
    local bar=HEIGHT*scale
    local centre=BOTTOMS[M.position(position)]-(LINE+HEIGHT)/2
    style=M.style(style)
    local box=(style~='bar' and line or 0)+(style~='label' and bar or 0)
    local top=math.max(0,math.min(centre-box/2,1-box))
    return {width=height*WIDTH*scale,bar=height*bar,outline=math.max(1,height*OUTLINE*scale),
        line=height*line,font=height*line*FONT/LINE,height=height*box,top=height*top}
end

-- Builds the countdown in the layer, hidden, and returns its handles. look:
-- position, size, style and opacity, as the settings give them.
--
-- It is built at Size's high end, the largest it gets. While Size's ends differ, the
-- time and the bar take the size between them by render transforms (M.show), each
-- scaled and moved to where the layout at that size puts it: laying it out again
-- every frame would set a new font size each time, and every size is a new set of
-- glyphs to draw.
function M.build(hud,layer,screen,look)
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    local suffix=Widgets.suffix()
    local style=M.style(look.style)
    local position,sizes=M.position(look.position),M.sizes(look.size)
    local layout=M.layout(screen.height,position,sizes[2],style)
    local width,bar,outline=layout.width,layout.bar,layout.outline
    -- SizeBox > Overlay of the time, centred at the top, and the bar centred along
    -- the bottom. The box is at least the bar's width and widens to a wider time.
    -- Bar only builds no time, Label only no bar or outline.
    local box=construct('/Script/UMG.SizeBox',tree,'PreymonitionCountdown'..suffix)
    local stack=construct('/Script/UMG.Overlay',tree,'PreymonitionCountdownStack'..suffix)
    box:SetMinDesiredWidth(width)
    box:SetHeightOverride(layout.height)
    box:SetContent(stack)
    -- Two opacities multiply: the box's render opacity is M.show's switch, 0 hidden
    -- and 1 shown, and the stack's is Opacity, animated as the count runs down. On
    -- the stack it fades the time, the bar and the outline together, one write a
    -- frame, and leaves their colours' own alphas and the switch alone.
    box:SetRenderOpacity(0)
    local fontFailed,text,fill
    local lines={}
    if style~='bar' then
        text=construct('/Script/UMG.TextBlock',tree,'PreymonitionCountdownText'..suffix)
    -- The font keeps its face; only its size changes. When it cannot, the time keeps
    -- the engine's default size and fontFailed says why.
        local sized,why=pcall(function()
            local font=text.Font
            font.Size=math.floor(layout.font+0.5)
            text:SetFont(font)
        end)
        fontFailed=not sized and tostring(why) or nil
        local textSlot=stack:AddChildToOverlay(text)
        textSlot:SetHorizontalAlignment(2)
        textSlot:SetVerticalAlignment(1)
        -- Scaled from its top centre, its top kept where the layout puts it.
        text:SetRenderTransformPivot({X=0.5,Y=0})
    end
    local barBox
    if style~='label' then
        barBox=construct('/Script/UMG.SizeBox',tree,'PreymonitionCountdownBar'..suffix)
        local barStack=construct('/Script/UMG.Overlay',tree,'PreymonitionCountdownBarStack'..suffix)
        fill=construct('/Script/UMG.Image',tree,'PreymonitionCountdownFill'..suffix)
        barBox:SetWidthOverride(width)
        barBox:SetHeightOverride(bar)
        barBox:SetContent(barStack)
        local barSlot=stack:AddChildToOverlay(barBox)
        barSlot:SetHorizontalAlignment(2)
        barSlot:SetVerticalAlignment(3)
        -- Scaled from its bottom centre, its bottom kept where the layout puts it.
        barBox:SetRenderTransformPivot({X=0.5,Y=1})
        -- The remaining part fills inside the outline and shrinks towards the left.
        local fillSlot=barStack:AddChildToOverlay(fill)
        fillSlot:SetHorizontalAlignment(0)
        fillSlot:SetVerticalAlignment(0)
        fillSlot:SetPadding({Left=outline,Top=outline,Right=outline,Bottom=outline})
        fill:SetRenderTransformPivot({X=0,Y=0.5})
        -- The outline: a thin line along each side, top, bottom, left, right.
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
    end
    local slot=layer:AddChildToOverlay(box)
    slot:SetHorizontalAlignment(2)
    slot:SetVerticalAlignment(1)
    slot:SetPadding({Left=0,Top=layout.top,Right=0,Bottom=0})
    local handles={hud=hold(hud,'hud'),layer=hold(layer,'layer'),box=hold(box,'box')}
    -- The widgets drawn in, kept as built: they belong to the HUD's widget tree, and
    -- every frame and request checks the HUD first (M.root). MCT detaches the
    -- countdown before it clears the layer or the HUD is replaced.
    local widgets={box=box,stack=stack,text=text,bar=barBox,fill=fill,lines=lines}
    return {handles=handles,widgets=widgets,applied={},fontFailed=fontFailed,style=style,
        opacity=M.opacity(look.opacity),sizes=sizes,position=position,screen=screen.height,built=layout}
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
-- progress 0 to 1, now true for the Perfect Opportunity window}. Opacity and Size
-- run from their low ends, as the count starts (progress 0), to their high ends as
-- it reaches the window (1), and stay there through it; equal ends hold still. Writes only what changed; a part the Style
-- left out is skipped. Its HUD was found live in this call (M.root).
function M.show(ui,view)
    local widgets=assert(ui.widgets,'countdown is no longer valid')
    local applied=ui.applied
    local opacity=view and 1 or 0
    if applied.opacity~=opacity then
        applied.opacity=opacity
        widgets.box:SetRenderOpacity(opacity)
    end
    if not view then return end
    local progress=view.now and 1 or view.progress or 0
    local range=ui.opacity
    local level=range[1]+(range[2]-range[1])*progress
    if applied.level~=level then
        applied.level=level
        widgets.stack:SetRenderOpacity(level)
    end
    local sizes=ui.sizes
    local size=sizes[1]+(sizes[2]-sizes[1])*progress
    if applied.size~=size then
        applied.size=size
        M.resize(ui,size)
    end
    local phase=view.now and 'now' or 'count'
    if applied.phase~=phase then
        applied.phase=phase
        local colors=COLORS[phase]
        if widgets.text then widgets.text:SetColorAndOpacity({SpecifiedColor=colors.text,ColorUseRule=0}) end
        if widgets.fill then widgets.fill:SetColorAndOpacity(colors.bar) end
        for _,image in ipairs(widgets.lines) do image:SetColorAndOpacity(colors.outline) end
    end
    if widgets.text and applied.text~=view.text then
        applied.text=view.text
        local library=assert(Combat.default(TEXT_LIBRARY),'KismetTextLibrary unavailable')
        widgets.text:SetText(library:Conv_StringToText(view.text))
    end
    if widgets.fill and applied.fraction~=view.fraction then
        applied.fraction=view.fraction
        widgets.fill:SetRenderScale({X=view.fraction,Y=1})
    end
end

-- Scales and moves the time and the bar from the built layout (Size's high end) to
-- where the layout at size puts them: the time's top at the box's top, the bar's
-- bottom at its bottom. The font keeps its share of the line, so the time scales
-- with it.
function M.resize(ui,size)
    local widgets,built=ui.widgets,ui.built
    local now=M.layout(ui.screen,ui.position,size,ui.style)
    if widgets.text then
        local scale=now.line/built.line
        widgets.text:SetRenderScale({X=scale,Y=scale})
        widgets.text:SetRenderTranslation({X=0,Y=now.top-built.top})
    end
    if widgets.bar then
        local scale=now.bar/built.bar
        widgets.bar:SetRenderScale({X=scale,Y=scale})
        widgets.bar:SetRenderTranslation({X=0,Y=(now.top+now.height)-(built.top+built.height)})
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
