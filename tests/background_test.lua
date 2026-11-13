-- The Background template: a shield behind the omens, centred where they line
-- up, that fades in with combat and follows the attack: faint white throughout
-- combat (In Combat), a see-through yellow while an attack is shown (Defending),
-- or only once its parry window opens (Critical); red while it is open.
package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;'..package.path
require('mc.objects').useLifetimes({weak=function(object)
    return {get=function() return (not object.invalid) and object or nil end,release=function() object.released=true end}
end})

local world={name='World'}
function world:IsValid() return true end
function world:GetFullName() return 'World /Game/Map.Map' end
local elsewhere={name='Elsewhere'}
function elsewhere:IsValid() return true end
function elsewhere:GetFullName() return 'World /Game/Other.Other' end
-- Fake UObjects record Set* calls as fields.
local function object(name,fields)
    local value=fields or {}
    value.name=name
    value.children=value.children or {}
    local methods={}
    function methods:IsValid() return not self.invalid end
    function methods:GetWorld() return self.world or world end
    function methods:AddChildToOverlay(child)
        self.children[#self.children+1]=child
        child.slot=object(child.name..' slot')
        return child.slot
    end
    function methods:ClearChildren() self.children={} end
    function methods:SetContent(child) self.content=child end
    function methods:SetBrushFromAtlasInterface(sprite) self.Brush=sprite end
    return setmetatable(value,{__index=function(_,key)
        if methods[key] then return methods[key] end
        local field=type(key)=='string' and key:match('^Set(.+)$')
        if field then return function(self,v) self[field]=v end end
    end})
end
local clock=0
local SHIELD='/Game/_Dawnwalker/UI/_Unified/Combat/Atlas/Frames/T_Combat_Icon_Shield.T_Combat_Icon_Shield'
local sprite=object('T_Combat_Icon_Shield')
local statics={
    -- Animations run on real time; the parry window multiplier cannot be read
    -- here, so 1.4 is assumed: each animation takes 280 ms.
    ['/Script/Engine.Default__GameplayStatics']=object('GameplayStatics',{GetRealTimeSeconds=function() return clock end}),
}
local loaded=false
StaticFindObject=function(path)
    if path==SHIELD then return loaded and sprite or nil end
    if path:match('^/Script/UMG%.') then return {path=path,IsValid=function() return true end} end
    return statics[path]
end
-- The shield sprite loads on demand.
LoadAsset=function(path) if path==SHIELD then loaded=true end end
StaticConstructObject=function(_,_,name) return object(name:ToString()) end
FName=function(value) return {ToString=function() return value end} end
local frames={}
EngineTickAvailable=true
ExecuteInGameThreadAfterFrames=function(_,callback) frames[#frames+1]=callback end
ExecuteWithDelay=function() error('the background waits on frames') end
local function run(seconds)
    clock=clock+(seconds or 0)
    local pending=frames
    frames={}
    for _,callback in ipairs(pending) do callback() end
end
local function settle(seconds)
    for _=1,100 do
        if #frames==0 then return end
        run(seconds)
    end
    error('the animation did not settle')
end

local template=dofile('Preymonition/Scripts/mc_background.lua')
assert(template.id=='Background' and template.category=='npc.attacks' and template.priority==9)
local hud=object('HUD',{WidgetTree=object('WidgetTree')})
local cleanups={}
local layer
local function attach(settings)
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    layer=object('Background layer')
    template.attach({hud=hud,cue=layer},{settings=settings or {},screen={width=1920,height=1080,scale=1},
        onCleanup=function(callback) cleanups[#cleanups+1]=callback end},{})
    return layer.children[1]
end
local function update(event) template.events.update({},event) end
local indicator=object('Indicator')
local PATH='/Game/HUD.Indicator'
local function equal(a,b) return math.abs(a-b)<1e-6 end
local function arrow(direction,path) update({kind='arrow',direction=direction or 2,path=path or PATH,indicator=indicator,sequence=1}) end
local function critical(direction) update({kind='critical',direction=direction or 2,path=PATH,indicator=indicator,sequence=2}) end
local function resolve() update({kind='resolve',reason='sword',path=PATH,indicator=indicator}) end
local function color(box) return box.content.ColorAndOpacity end
local function red(value) return value.R==1 and value.G==0.2 and value.B==0 and value.A==1 end
local function yellow(value) return value.R==1 and value.G==0.67 and value.B==0.19 and value.A==0.4 end
local function wake() template.events.wake({},{name='wake'}); settle(0.05) end
local function sleep() template.events.sleep({},{name='sleep'}); settle(0.1) end

-- The box is the omens' cue box, 40% of the short side; the shield image fills
-- it before Size scales it: the default 50% draws it half the screen height.
local box=attach()
local shield=box.content
assert(box.WidthOverride==432 and box.HeightOverride==432,'the box is 40% of the short side')
assert(equal(shield.RenderScale.X,540/432),'Size defaults to half the screen height')
assert(shield.Brush==sprite,'the shield takes the game\'s sprite')
assert(box.slot.VerticalAlignment==1 and equal(box.slot.Padding.Top,(1080-432)/2),'Middle centres it')
assert(box.RenderOpacity==0 and color(box).A==0,'it starts hidden')
-- Size: 100% is the full screen height, 5% the least.
assert(equal(attach({Size=100}).content.RenderScale.X,1080/432),'100% is the screen height')
assert(equal(attach({Size=1}).content.RenderScale.X,54/432),'Size is at least 5% of the height')
-- Position: Below keeps the shield's bottom 10% of the height above the bottom
-- edge, Above its top 10% below the top edge; the box shares its centre. At its
-- default size these are where the omens line up.
assert(equal(attach({Position=0}).slot.Padding.Top,1080*0.9-270-216),'Below')
assert(equal(attach({Position=2}).slot.Padding.Top,1080*0.1+270-216),'Above')
assert(equal(attach({Position=0,Size=60}).slot.Padding.Top,1080*0.9-324-216),'a larger shield sits by its own edge')

-- Defending, the default: clear until an attack shows, then a see-through
-- yellow, red once its parry window opens, clear once it resolves.
box=attach()
arrow()
assert(box.RenderOpacity==0,'requests are ignored outside combat')
wake()
assert(equal(box.RenderOpacity,0.5) and color(box).A==0,'combat fades the cue in to half; the shield waits')
arrow()
assert(yellow(color(box)),'an attack shows it yellow')
critical()
assert(red(color(box)) and equal(box.content.RenderScale.X,540/432),'its parry window turns it red, at its size')
resolve()
assert(color(box).A==0,'the resolve clears it')
-- An attack first seen in its parry window is red at once.
critical(3)
assert(red(color(box)),'an attack first seen critical turns it red')
resolve()
-- Another world's attacks are not followed.
update({kind='arrow',direction=1,path='/Game/Other',indicator=object('Other',{world=elsewhere}),sequence=3})
assert(color(box).A==0,'another world\'s attack is ignored')
-- The unblockable skull shows in the omens: the shield clears meanwhile.
arrow()
update({kind='unblockable',active=true,path=PATH,indicator=indicator})
assert(color(box).A==0,'the skull clears the shield')
update({kind='unblockable',active=false,path=PATH,indicator=indicator})
assert(yellow(color(box)),'and it returns once the skull passes')
resolve()
sleep()
assert(box.RenderOpacity==0 and color(box).A==0,'combat end fades it out')

-- In Combat: faint white throughout combat, red during the parry window.
box=attach({Visibility=1})
wake()
assert(color(box).A==0.2 and color(box).G==1,'faint white throughout combat')
arrow()
assert(color(box).A==0.2,'an attack leaves it faint')
critical()
assert(red(color(box)),'its parry window turns it red')
resolve()
assert(color(box).A==0.2 and color(box).G==1,'then faint white again')
sleep()

-- Critical: unseen until the parry window opens, then pops in red and grows to
-- twice its size over the animation's 280 ms.
box=attach({Visibility=3})
wake()
arrow()
assert(color(box).A==0,'a Critical shield waits unseen')
critical()
assert(red(color(box)) and equal(box.content.RenderScale.X,540/432),'it pops in red at its size')
run(0.14)
assert(equal(box.content.RenderScale.X,1.5*540/432),'growing')
settle(0.05)
assert(equal(box.content.RenderScale.X,2*540/432) and #frames==0,'to twice its size, then holds')
resolve()
assert(color(box).A==0 and equal(box.content.RenderScale.X,540/432),'the resolve hides it at its size')
sleep()

-- A shield built before the game had its sprite takes it when combat starts.
loaded=false
local load=LoadAsset
LoadAsset=function() end
local early=attach()
assert(early.content.Brush==nil,'no sprite yet: it stays clear')
LoadAsset=load
wake()
arrow()
assert(early.content.Brush==sprite and yellow(color(early)),'combat start gives it the sprite')
resolve()
sleep()

-- Cleanup clears the layer and releases every handle.
local last=layer
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
assert(#last.children==0 and early.released and early.content.released,'cleanup clears the layer and releases its handles')
print('PASS: Background shows the shield in combat, yellow with an attack, red in its parry window, and clears for the skull')
