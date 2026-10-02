package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;'..package.path

local world={name='World'}
function world:IsValid() return true end
function world:GetFullName() return 'World /Game/Map.Map' end

-- Fake UObjects record Set* calls as fields; reads use plain fields.
local function object(name,fields)
    local value=fields or {}
    value.name=name
    value.children=value.children or {}
    value.visible=value.visible~=false
    value.RenderOpacity=value.RenderOpacity or 1
    local methods={}
    function methods:IsValid() return self.invalid~=true end
    function methods:GetFullName() return 'Object '..self.name end
    function methods:GetWorld() return world end
    function methods:IsVisible() return self.visible end
    function methods:GetRenderOpacity() return self.RenderOpacity end
    function methods:GetParent() return self.parent end
    function methods:AddChildToOverlay(child)
        self.children[#self.children+1]=child
        child.parent=self
        return object(child.name..' slot')
    end
    function methods:ClearChildren()
        for _,child in ipairs(self.children) do child.parent=nil end
        self.children={}
    end
    function methods:SetContent(child) self.content=child; child.parent=self end
    function methods:SetBrush(brush)
        self.Brush=brush
        self.Background={OutlineSettings={Width=1}}
    end
    return setmetatable(value,{__index=function(_,key)
        if methods[key] then return methods[key] end
        local field=type(key)=='string' and key:match('^Set(.+)$')
        if field then return function(self,v) rawset(self,field,v) end end
    end})
end

local function color(strength) return {R=strength,G=0,B=0,A=1} end
local indicator=object('Indicator',{
    Reticle=object('Reticle',{Brush='shield'}),
    TopArrow=object('Top',{ColorAndOpacity=color(0.2),Brush='arrow'}),
    BottomArrow=object('Bottom',{ColorAndOpacity=color(0.2),Brush='arrow'}),
    LeftArrow=object('Left',{ColorAndOpacity=color(0.9),Brush='arrow'}),
    RightArrow=object('Right',{ColorAndOpacity=color(0.2),Brush='arrow'}),
})
local component=object('PlayerCombat')
local inCombat=true
local subsystem=object('CombatSubsystem')
function subsystem:GetIsInCombat() return inCombat end
local clock=0
local statics=object('GameplayStatics')
function statics:GetRealTimeSeconds() return clock end

local objects={['Indicator']=indicator,['PlayerCombat']=component,
    ['/Script/Engine.Default__GameplayStatics']=statics}
StaticFindObject=function(path) return objects[path] or (path:match('^/Script/UMG%.') and {path=path}) end
FName=function(value) return value end
local constructed=0
StaticConstructObject=function(class,outer,name)
    assert(outer==hudTree,'cue widgets belong to the HUD widget tree')
    constructed=constructed+1
    return object(name,{class=class.path})
end
local visibleIndicators={}
FindAllOf=function(class)
    if class=='CombatSubsystem' then return {subsystem} end
    if class=='WBP_CombatTargetIndicator_C' then return visibleIndicators end
end

local hooks,removed={},0
RegisterHook=function(path,callback)
    hooks[path]=callback
    return 1,2
end
UnregisterHook=function(path,pre,post)
    assert(hooks[path] and pre==1 and post==2)
    hooks[path]=nil
    removed=removed+1
    return true
end
local delayed={}
ExecuteWithDelay=function(milliseconds,callback) delayed[#delayed+1]=callback end
ExecuteInGameThread=function(callback) callback() end
local function run()
    local batch=delayed
    delayed={}
    for _,callback in ipairs(batch) do callback() end
end
local function settle(seconds)
    for _=1,100 do
        if #delayed==0 then return end
        clock=clock+seconds
        run()
    end
    error('deferred work did not settle')
end
local function fire(path,target)
    hooks[path]({get=function() return target end})
end
local SHOW='/Script/DogwoodUI.CombatTargetIndicatorBase:UpdateIconTypeToMatchObservedStubState'
local CLEAR='/Script/DogwoodUI.CombatTargetIndicatorBase:NotifyIndicatorCleared'
local END='/Script/DogwoodCombat.PlayerCombatComponent:OnCombatEnded'

hudTree=object('WidgetTree')
local hud=object('HUD',{WidgetTree=hudTree})
local layer=object('Cue layer')
local template=dofile('Preymonition/Scripts/mc_preymonition.lua')
local moduleCleanups={}
template.loaded(function(callback) moduleCleanups[#moduleCleanups+1]=callback end)
assert(hooks[SHOW] and hooks[CLEAR] and hooks[END],'all three attack hooks must register')

fire(SHOW,indicator)
assert(#delayed==0,'events are ignored until a cue is attached')

local cleanups={}
local function attach(size)
    local original={}
    local result=template.attach({hud=hud,cue=layer},
        {settings={CueS=size},screen={width=1920,height=1080,scale=1},
            onCleanup=function(callback) cleanups[#cleanups+1]=callback end},original)
    assert(result==original)
end
attach(20)
assert(constructed==7 and #layer.children==1,'one box with shield, overlay and four arrows')
local box=layer.children[1]
assert(box.WidthOverride==216 and box.HeightOverride==216,'Standard size is 20% of the short side')
assert(box.RenderOpacity==0,'the cue starts hidden')

fire(SHOW,indicator)
fire(SHOW,indicator)
assert(#delayed==1,'hook work is coalesced into one deferred drain')
run()
local left=box.content.content.children[3]
assert(box.content.Brush.DrawAs==3 and box.content.Brush.OutlineSettings.Width==0
    and left.Brush=='arrow','cue copies native artwork without the outline')
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'active cue rests at half opacity')
assert(left.RenderOpacity==1 and math.abs(left.RenderScale.X-0.8)<1e-6,'selected arrow settles at 0.8')
assert(box.content.content.children[1].RenderOpacity==0,'other arrows stay hidden')

fire(CLEAR,indicator)
run()
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'an ordinary clear keeps the idle cue')

inCombat=false
fire(END,component)
run()
settle(0.05)
assert(box.RenderOpacity==0 and left.RenderOpacity==0,'combat end fades and resets the cue')
fire(SHOW,indicator)
run()
assert(#delayed==0 and box.RenderOpacity==0,'stale updates after combat end are ignored')

-- A settings commit reattaches the same MCT layer after its cleanup.
inCombat=true
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
assert(#layer.children==0,'cleanup removes the cue from the layer')
visibleIndicators={indicator}
attach(25)
assert(#layer.children==1 and layer.children[1].WidthOverride==270,'reattach rebuilds once at the new size')
assert(#delayed==1,'an attack already on screen is replayed after attach')
settle(0.05)
assert(math.abs(layer.children[1].RenderOpacity-0.5)<1e-6)

for index=#cleanups,1,-1 do cleanups[index]() end
assert(moduleCleanups[1]() and removed==3,'session cleanup unregisters every hook')
local fire_ok=pcall(fire,SHOW,indicator)
assert(not fire_ok,'no hook remains registered')
print('PASS: Preymonition session follows attacks, clears, combat end, reattach and cleanup')
