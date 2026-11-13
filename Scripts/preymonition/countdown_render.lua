-- The countdown's widgets: a time above a thin bar, built in a cue layer. It
-- reads nothing from the game but the clock, through preymonition.combat; preymonition.countdown decides what
-- they show.
local MC=require('mc')
local Combat=require('preymonition.combat')

-- Sizes as shares of the screen height: the bar's width and height, its outline,
-- the text's line above it and the text's font size.
local WIDTH,HEIGHT,OUTLINE,LINE,FONT=0.2,0.015,0.002,0.035,0.02
-- Position puts the bar's bottom this share of the screen height below the
-- centre of a shield at its default size, near the shield's point. The centres
-- match the Omens template's: Middle centres it, Below and Above keep a shield
-- half the screen height 10% of it from the bottom or top edge.
local BELOW_CENTRE=0.2
local CENTRES={[0]=0.65,[1]=0.5,[2]=0.35}
-- Yellow while counting down, red for the parry window. The outline and the
-- remaining bar are see-through; the elapsed part is not drawn at all.
local COLORS={
    count={text={R=1,G=0.85,B=0.1,A=1},bar={R=1,G=0.85,B=0.1,A=0.5},outline={R=1,G=0.85,B=0.1,A=0.5}},
    now={text={R=1,G=0.2,B=0,A=1},bar={R=1,G=0.2,B=0,A=0.5},outline={R=1,G=0.2,B=0,A=0.5}},
}
local TEXT_LIBRARY='/Script/Engine.Default__KismetTextLibrary'
-- Widget names stay unique across Lua reloads, like the omens'.
local generation=0
local nonce=string.format('%06x',math.random(0,0xffffff))
local M={}

local function construct(classPath,outer,name)
    local class=assert(StaticFindObject(classPath),'missing widget class: '..classPath)
    local object=StaticConstructObject(class,outer,FName(name),0x40)
    assert(MC.valid(object),'widget construction failed: '..name)
    object:SetVisibility(3)
    return object
end

local function hold(object,name)
    return assert(MC.hold(object),'countdown cannot keep '..name)
end

-- Where the countdown sits for a Position: the top of its box, in screen units.
function M.top(position,height)
    local centre=CENTRES[position] or CENTRES[1]
    return height*(centre+BELOW_CENTRE-LINE-HEIGHT)
end

-- Builds the countdown in the layer, hidden, and returns its handles.
function M.build(hud,layer,screen,position)
    local tree=assert(hud.WidgetTree,'HUD has no widget tree')
    -- A settings update reattaches the same layer; replace its previous content.
    layer:ClearChildren()
    generation=generation+1
    local suffix=nonce..'_'..generation
    local height=screen.height
    local width,bar,line=height*WIDTH,height*HEIGHT,height*LINE
    local outline=math.max(1,height*OUTLINE)
    -- SizeBox > Overlay of the time, top right, and the bar along the bottom.
    local box=construct('/Script/UMG.SizeBox',tree,'PreymonitionCountdown'..suffix)
    local stack=construct('/Script/UMG.Overlay',tree,'PreymonitionCountdownStack'..suffix)
    local text=construct('/Script/UMG.TextBlock',tree,'PreymonitionCountdownText'..suffix)
    local barBox=construct('/Script/UMG.SizeBox',tree,'PreymonitionCountdownBar'..suffix)
    local barStack=construct('/Script/UMG.Overlay',tree,'PreymonitionCountdownBarStack'..suffix)
    local fill=construct('/Script/UMG.Image',tree,'PreymonitionCountdownFill'..suffix)
    box:SetWidthOverride(width)
    box:SetHeightOverride(line+bar)
    box:SetContent(stack)
    box:SetRenderOpacity(0)
    -- The font keeps its face; only its size changes.
    pcall(function()
        local font=text.Font
        font.Size=math.floor(height*FONT+0.5)
        text:SetFont(font)
    end)
    local textSlot=stack:AddChildToOverlay(text)
    textSlot:SetHorizontalAlignment(3)
    textSlot:SetVerticalAlignment(1)
    barBox:SetHeightOverride(bar)
    barBox:SetContent(barStack)
    local barSlot=stack:AddChildToOverlay(barBox)
    barSlot:SetHorizontalAlignment(0)
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
    slot:SetPadding({Left=0,Top=M.top(position,height),Right=0,Bottom=0})
    local handles={hud=hold(hud,'hud'),layer=hold(layer,'layer'),box=hold(box,'box'),
        text=hold(text,'text'),fill=hold(fill,'bar'),lines={}}
    for index,image in ipairs(lines) do handles.lines[index]=hold(image,'outline') end
    return {handles=handles,applied={}}
end

-- The countdown's widgets as live wrappers for this call, or nil once any is gone.
local function live(ui)
    local widgets={lines={}}
    for _,key in ipairs({'hud','box','text','fill'}) do
        widgets[key]=MC.get(ui.handles[key])
        if not widgets[key] then return nil end
    end
    for index,handle in ipairs(ui.handles.lines) do
        widgets.lines[index]=MC.get(handle)
        if not widgets.lines[index] then return nil end
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

-- Whether an object is in the same world as the countdown's HUD.
function M.sameWorld(ui,object)
    local hud=MC.get(ui.handles.hud)
    if not (hud and MC.valid(object)) then return false end
    local own=worldName(hud)
    return own~=nil and own==worldName(object)
end

-- A live object in the countdown's world, for calls that need a world context.
function M.context(ui)
    return assert(MC.get(ui.handles.hud),'countdown is no longer valid')
end

-- Game time in seconds, the clock an attack's hit window is in.
function M.now(ui)
    return Combat.gameTime(M.context(ui))
end

-- Shows a view: nil hides the countdown; otherwise {text, fraction 0 to 1,
-- now true for the parry window}. Writes only what changed.
function M.show(ui,view)
    local widgets=assert(live(ui),'countdown is no longer valid')
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
    for key,handle in pairs(ui.handles) do
        if key=='lines' then
            for _,item in ipairs(handle) do MC.release(item) end
        else
            MC.release(handle)
        end
    end
end

return M
