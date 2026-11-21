-- A resolution, window or UI-scale change mid-session: MCT reads the host screen at
-- MC_PlayerReady and MC_CombatStart and updates every attachment laid out for another
-- one with the new params.screen (ModCoreTemplates' tests/mc/screen_change_test.lua).
-- Here through MCT's runtime and the npc.attacks category: the Omens, the Edges and
-- the Countdown rebuild for the new screen, and the same screen rebuilds nothing.
package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;ModCoreTemplates/Scripts/vendor/?.lua;'..package.path
dofile('ModCoreTemplates/tests/support/lifetimes.lua').install()
local Runtime=require('mc.runtime')

local world={name='World'}
function world:IsValid() return true end
function world:GetFullName() return 'World /Game/Map.Map' end
-- Fake UObjects record Set* calls as fields. They take children both as MCT adds
-- its layers (AddChild, with a Slot) and as the templates fill them (AddChildToOverlay).
local addresses=0
local function object(name,fields)
    local value=fields or {}
    addresses=addresses+1
    value.name,value.address=name,addresses
    value.children=value.children or {}
    value.RenderOpacity=value.RenderOpacity or 1
    value.RenderTransform=value.RenderTransform or {Translation={X=0,Y=0},Scale={X=1,Y=1}}
    local methods={}
    function methods:IsValid() return self.invalid~=true end
    function methods:GetFullName() return 'Object '..self.name end
    function methods:GetAddress() return self.address end
    function methods:GetWorld() return world end
    function methods:GetParent() return self.parent end
    function methods:GetOuter() return self.outer end
    function methods:GetRenderOpacity() return self.RenderOpacity end
    function methods:GetChildrenCount() return #self.children end
    function methods:GetChildAt(index) return self.children[index+1] end
    function methods:AddChild(child)
        self.children[#self.children+1]=child
        child.parent=self
        -- An overlay slot, as the HUD root's: MCT stacks its layers by reordering them.
        child.Slot=object(child.name..' Slot',{Padding={Left=0,Top=0,Right=0,Bottom=0},
            HorizontalAlignment=0,VerticalAlignment=0})
        function child.Slot:GetClass() return {GetName=function() return 'OverlaySlot' end} end
        return child.Slot
    end
    function methods:RemoveChild(child)
        for index,item in ipairs(self.children) do
            if item==child then table.remove(self.children,index); child.parent=nil; return true end
        end
        return false
    end
    function methods:AddChildToOverlay(child)
        self.children[#self.children+1]=child
        child.parent=self
        child.slot=object(child.name..' slot')
        return child.slot
    end
    methods.AddChildToCanvas=methods.AddChildToOverlay
    function methods:ClearChildren()
        for _,child in ipairs(self.children) do child.parent=nil end
        self.children={}
    end
    function methods:SetContent(child) self.content=child; child.parent=self end
    return setmetatable(value,{__index=function(_,key)
        if methods[key] then return methods[key] end
        local field=type(key)=='string' and key:match('^Set(.+)$')
        if field then return function(self,v) self[field]=v end end
    end})
end

-- The engine's PNG import: the mod's pictures load from the source tree's images folder.
local rendering=object('KismetRenderingLibrary')
function rendering:ImportFileAsTexture2D(_,path)
    local name=path:match('^Preymonition/images/([%w_]+)%.png$')
    local file=name and io.open(path,'rb')
    if file then file:close() end
    return file and object('Texture '..name) or nil
end
local statics=object('GameplayStatics')
function statics:GetRealTimeSeconds() return 0 end
function statics:GetTimeSeconds() return 0 end
local objects={
    ['/Script/Engine.Default__KismetRenderingLibrary']=rendering,
    ['/Script/Engine.Default__GameplayStatics']=statics,
    ['/Script/Engine.Default__KismetTextLibrary']=object('KismetTextLibrary',
        {Conv_StringToText=function(_,text) return {text=text} end}),
}
local classes={}
StaticFindObject=function(path)
    if path:match('^/Script/UMG%.') then
        classes[path]=classes[path] or object(path,{path=path})
        return classes[path]
    end
    return objects[path]
end
FName=function(value)
    return {ToString=function() return value end,GetComparisonIndex=function() return 'index:'..value end}
end
-- Widgets built, MCT's layers and the templates' own.
local constructed=0
StaticConstructObject=function(class,outer,name)
    constructed=constructed+1
    return object(name and name:ToString() or class.path,{class=class.path,outer=outer,
        Font=class.path=='/Script/UMG.TextBlock' and {Size=24} or nil})
end
FindAllOf=function() return {} end
UE4SSLuaEventBridge.GetCapabilities=function() return {hooks=true,hooks_bp=true} end
UE4SSLuaEventBridge.Hooks={Request=function() return {Remove=function() end} end}
ExecuteWithDelay=function() end
ExecuteInGameThread=function(callback) callback() end

-- The game's HUD: npc.attacks finds it by class, reaches its root widget and adds one
-- cue layer per template there.
local HUD_CLASS='/Game/_Dawnwalker/UI/_Unified/HUD/WBP_GameHUD.WBP_GameHUD_C'
local tree=object('WidgetTree')
local root=object('RootWidget',{outer=tree})
local hud=object('HUD',{class=HUD_CLASS,WidgetTree=tree})
local screen={width=1920,height=1080,scale=1}
local reads,errors=0,{}
local host={
    valid=function(v) return v~=nil and v:IsValid() end,
    identity=function(v) return v.name end,
    ready=function() return true end,
    matches=function(v,s) return v.class==s.class end,
    parent=function() end,
    find=function(selector) return selector.class==HUD_CLASS and {hud} or {} end,
    member=function(v,path) if v==hud and path=='WidgetTree.RootWidget' then return root end end,
    watch=function() end,
    screen=function()
        reads=reads+1
        return {width=screen.width,height=screen.height,scale=screen.scale,
            center=screen.width/2,middle=screen.height/2}
    end,
    subscribe=function() return function() end end,
    onError=function(e) errors[#errors+1]=e end,
}

local definitions=dofile('Preymonition/tests/load_templates.lua')()
local templates={}
for _,definition in ipairs(definitions) do
    -- MCT names each template after its module; the Audio Cues draw nothing.
    if definition.id~='Preymonition_Audio' then
        templates[#templates+1]=definition
    end
end
assert(#templates==3,'the Omens, the Edges and the Countdown')
local runtime=Runtime.new(host,{dofile('ModCoreTemplates/Scripts/categories/npc_attacks.lua')},templates)
runtime:select('npc.attacks',{Preymonition_Omens={},Preymonition_Edges={},Preymonition_Countdown={}})
runtime:start()
local function noErrors()
    local first=errors[1]
    assert(not first,first and tostring(first.stage)..' '..tostring(first.template)..': '..first.message)
end

-- The cue layers in priority order: the Omens (10), the Edges (11), the Countdown (12).
local function layers()
    assert(#root.children==3,'one cue layer per template')
    return root.children[1],root.children[2],root.children[3]
end
local function equal(a,b) return math.abs(a-b)<1e-6 end
-- What each template laid out from its screen.
local function layout()
    local omens,edges,countdown=layers()
    local box=omens.children[1]
    local edge=edges.children[1].children[1]
    local count=countdown.children[1]
    return {box=box,size=box.WidthOverride,top=box.slot.Padding.Top,
        depth=edge.HeightOverride,countdownTop=count.slot.Padding.Top,countdownWidth=count.MinDesiredWidth}
end
-- An arrow shown now, through MCT's update event: its travel runs out from the cue's
-- centre towards the screen edge, so where it starts depends on that edge.
local Fancy=require('preymonition.omens_fancy')
local RATIO=Fancy.SIZE.X/math.max(Fancy.SIZE.X,Fancy.SIZE.Y)
local attacks=0
local function arrowStart(direction)
    attacks=attacks+1
    local path='Indicator'..attacks
    runtime:emit('MC_NPCAttackIndicator',{kind='arrow',direction=direction,path=path,indicator=object(path)})
    local arrow=layers().children[1].content.children[1].children[direction]
    assert(arrow.RenderOpacity>0,'the arrow shows')
    local offset=direction<=2 and arrow.RenderTranslation.Y or arrow.RenderTranslation.X
    runtime:emit('MC_NPCAttackIndicator',{kind='resolve',path=path,reason='sword'})
    return math.abs(offset)
end
-- By the spec, with the default Size 30%-80% and Movement 40%-60%: the arrow starts
-- 1+9*0.3 units of 5% of the height across, its tip 40% of the way from its back edge
-- on the centre to the screen edge, its centre half its length back.
local function expectedStart(edge,height)
    local from=height*0.05*(1+9*0.3)
    local length=from*RATIO
    return length+0.4*(edge-length)-length/2
end

-- 1. Attached at player ready on a 1920x1080 screen.
runtime:signal('MC_PlayerReady')
noErrors()
local first=layout()
assert(equal(first.size,432) and equal(first.top,(1080-432)/2),'the cue box is 40% of the short side, centred')
assert(equal(first.depth,1080*0.08),'the edges reach 8% of the short side in')
assert(equal(first.countdownTop,1080*0.5) and equal(first.countdownWidth,1080*0.2),'the countdown sits 50% down')
runtime:signal('MC_CombatStart')
noErrors()
assert(equal(arrowStart(3),expectedStart(960,1080)),'the left arrow travels towards the 960 edge')
assert(equal(arrowStart(1),expectedStart(540,1080)),'the top arrow travels towards the 540 edge')

-- 2. A wider screen at the next combat start: every template rebuilds for it, read once.
runtime:signal('MC_CombatEnd')
screen.width=2560
reads=0
local built=constructed
runtime:signal('MC_CombatStart')
noErrors()
assert(reads==1,'the new screen is read once for every attachment')
assert(constructed>built,'the templates rebuild')
local wide=layout()
assert(wide.box~=first.box,'the Omens build a new cue box')
-- A wider screen keeps the short side: the box, the edge depth and the countdown stay.
assert(equal(wide.size,432) and equal(wide.depth,first.depth) and equal(wide.countdownTop,first.countdownTop))
assert(equal(arrowStart(3),expectedStart(1280,1080)),'the left arrow now travels towards the 1280 edge')
assert(equal(arrowStart(1),expectedStart(540,1080)),'the top arrow keeps its 540 edge')

-- 3. The same screen at the next combat start updates nothing.
runtime:signal('MC_CombatEnd')
built=constructed
runtime:signal('MC_CombatStart')
noErrors()
assert(constructed==built and layout().box==wide.box,'an unchanged screen rebuilds nothing')

-- 4. A taller screen moves everything laid out from the height.
runtime:signal('MC_CombatEnd')
screen.height=1440
runtime:signal('MC_CombatStart')
noErrors()
local tall=layout()
assert(equal(tall.size,576) and equal(tall.top,(1440-576)/2),'the cue box is 40% of the new short side')
assert(equal(tall.depth,1440*0.08),'the edges reach 8% of the new short side in')
assert(equal(tall.countdownTop,1440*0.5) and equal(tall.countdownWidth,1440*0.2),'the countdown follows the height')
assert(equal(arrowStart(3),expectedStart(1280,1440)),'the left arrow travels towards the 1280 edge')
assert(equal(arrowStart(1),expectedStart(720,1440)),'the top arrow travels towards the 720 edge')

runtime:stop()
noErrors()
print('PASS screen_change_test')
