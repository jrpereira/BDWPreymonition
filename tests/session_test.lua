package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;'..package.path
-- Weak handles return their object only while it is live, like the bridge's,
-- and as UE4SS does, a fresh wrapper on every get: never the same table twice.
local released=0
local function wrapper(object)
    return setmetatable({},{__index=object,__newindex=object})
end
require('mc.objects').useLifetimes({weak=function(object)
    return {get=function() return wrapper(object) end,release=function() released=released+1 end}
end})

local world={name='World'}
function world:IsValid() return true end
function world:GetFullName() return 'World /Game/Map.Map' end

-- Native work the fakes see, for the call budget: UObject method calls, of
-- which setters, and object lookups.
local calls={methods=0,setters=0,finds=0}
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
    function methods:GetOuter() return self.outer end
    function methods:GetFName()
        local value=self
        local text=value.fname or value.name
        return {ToString=function() return text end,GetComparisonIndex=function() return 'index:'..text end}
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
    function methods:SetBrush(brush)
        self.Brush=brush
        self.Background={OutlineSettings={Width=1}}
    end
    return setmetatable(value,{__index=function(_,key)
        if methods[key] then calls.methods=calls.methods+1; return methods[key] end
        local field=type(key)=='string' and key:match('^Set(.+)$')
        if field then
            calls.methods,calls.setters=calls.methods+1,calls.setters+1
            return function(self,v) self[field]=v end
        end
    end})
end

-- Native arrows: lit orange at strength, dim when inactive.
local function color(strength) return {R=strength,G=strength*0.67,B=strength*0.19,A=1} end
local ARROWS={'TopArrow','BottomArrow','LeftArrow','RightArrow'}
local objects={}
-- The game's centre icon sprites.
local FRAMES='/Game/_Dawnwalker/UI/_Unified/Combat/Atlas/Frames/'
local SKULL=object('T_Combat_Icon_SkullRed')
objects[FRAMES..'T_Combat_Icon_SkullRed.T_Combat_Icon_SkullRed']=SKULL
-- Native arrow artwork: 40 wide and 30 high, resting 5 below the indicator centre.
local ARROW_BRUSH={ImageSize={X=40,Y=30}}
-- An indicator whose WidgetTree holds four named arrow images and its centre
-- icon, the Reticle; lit is lit brightly.
local function newIndicator(name,lit)
    local value=object(name)
    local tree=object(name..'.WidgetTree',{outer=value})
    value.Reticle=object(name..'.Reticle',{fname='Reticle',outer=tree})
    objects[value.Reticle.name]=value.Reticle
    for _,key in ipairs(ARROWS) do
        local arrow=object(name..'.'..key,{fname=key,outer=tree,Brush=ARROW_BRUSH,
            RenderTransform={Translation={X=0,Y=5},Scale={X=1,Y=1}},
            ColorAndOpacity=color(key==lit and 0.9 or 0.2)})
        value[key]=arrow
        objects[arrow.name]=arrow
    end
    objects[name]=value
    return value
end
local indicator=newIndicator('WBP_CombatTargetIndicator_C_1','LeftArrow')
local clock=0
local statics=object('GameplayStatics')
function statics:GetRealTimeSeconds() return clock end
-- The player, and Wwise recording each event posted.
local player=object('Player')
function player:K2_GetActorLocation() return {X=1,Y=2,Z=3} end
function statics:GetPlayerPawn() return player end
local posted={}
local wwise=object('Wwise')
function wwise:PostEventAtLocation(event,location) posted[#posted+1]={event=event,location=location}; return 1 end
objects['/Script/AkAudio.Default__AkGameplayStatics']=wwise
local EVENTS='/Game/Audio/AK_Events/Events/'
local SWISH_SOUND=object('UI_Claws_Equip')
local BOOM_SOUND=object('UI_PauseMenu_Resume')
objects[EVENTS..'UI/UI_Inventory/UI_Claws_Equip.UI_Claws_Equip']=SWISH_SOUND
objects[EVENTS..'UI/UI_MainMenu/UI_PauseMenu_Resume.UI_PauseMenu_Resume']=BOOM_SOUND

objects['/Script/Engine.Default__GameplayStatics']=statics
-- The engine's PNG import: the Fancy pictures load from the mod's images folder,
-- here the source tree; fancyMissing makes every import fail.
local fancyMissing=false
local imported={}
local rendering=object('KismetRenderingLibrary')
function rendering:ImportFileAsTexture2D(context,path)
    imported[#imported+1]=path
    if fancyMissing then return nil end
    local name=path:match('^Preymonition/images/(fancy_%a+)%.png$')
    return name and object('Texture '..name) or nil
end
objects['/Script/Engine.Default__KismetRenderingLibrary']=rendering
-- The game's combat subsystem, reached without a scan, holds the parry window
-- multiplier per difficulty and platform. Each attack's animation takes 0.2s per
-- unit of it; 1 keeps the 0.2s the checks below expect.
local parryMultiplier=1
local function entries(list)
    return {ForEach=function(_,visit)
        for _,pair in ipairs(list) do visit({get=function() return pair[1] end},{get=function() return pair[2] end}) end
    end}
end
local combatSubsystem=object('CombatSubsystem',{ActionDifficultyLevel=1})
combatSubsystem.DifficultyConfig={ActionDifficulties={ForEach=function(_,visit)
    for level,value in pairs({[0]=2.5,[1]='current',[2]=1.2}) do
        local multiplier=value=='current' and parryMultiplier or value
        visit({get=function() return level end},{get=function() return {ParryWindowMultipliers=entries({
            {{ToString=function() return 'PS5' end},99},{{ToString=function() return 'Windows' end},multiplier}})} end})
    end
end}}
local subsystems=object('SubsystemBlueprintLibrary')
function subsystems:GetWorldSubsystem(_,class)
    if class==objects['/Script/DogwoodCombat.CombatSubsystem'] and parryMultiplier then return combatSubsystem end
end
objects['/Script/Engine.Default__SubsystemBlueprintLibrary']=subsystems
objects['/Script/DogwoodCombat.CombatSubsystem']=object('CombatSubsystemClass')
StaticFindObject=function(path)
    calls.finds=calls.finds+1
    return objects[path] or (path:match('^/Script/UMG%.') and {path=path})
end
-- An FName's comparison index stands for its text, as the engine's does.
FName=function(value)
    return {ToString=function() return value end,GetComparisonIndex=function() return 'index:'..value end}
end
local constructed=0
StaticConstructObject=function(class,outer,name)
    assert(outer==hudTree,'cue widgets belong to the HUD widget tree')
    constructed=constructed+1
    return object(name:ToString(),{class=class.path})
end
-- Combat state comes from the combat hooks; scanning every object is too slow.
local scans=0
FindAllOf=function() scans=scans+1; return {} end

-- UE4SS's own hooks are not used: MCT hooks the indicator through the event
-- bridge, which hands each icon change to its pre callback.
local hooks={}
RegisterHook=function(path) hooks[path]=true; error('UE4SS hooks are not used') end
local bridgeHooks,removed={},0
UE4SSLuaEventBridge={
    GetCapabilities=function() return {hooks=true,hooks_bp=true} end,
    Hooks={Hook=function(path,options)
        assert(options.object_paths and options.params[1]=='IconType')
        bridgeHooks[path]=options.pre
        return {Unhook=function() bridgeHooks[path]=nil; removed=removed+1 end}
    end},
}
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
-- The indicator's icon types: the game's 1-4 attack from the left, right, top
-- and bottom, 5-8 the same in the parry window, 9 the unblockable skull and 0
-- the sword. The bridge delivers each change on the next tick; here at once.
local ICON=require('mc.attack_indicator').ICON
local LEFT,RIGHT,TOP,BOTTOM,PARRY,SKULL_ICON,SWORD_ICON=1,2,3,4,4,9,0
local function icon(target,value)
    bridgeHooks[ICON]({object={path=target.name},params={IconType={value=value}}})
end

hudTree=object('WidgetTree')
local hud=object('HUD',{WidgetTree=hudTree})
local layer=object('Cue layer')
local template=dofile('Preymonition/Scripts/mc_center.lua')
assert(next(hooks)==nil,'nothing is hooked outside combat')
-- MCT owns combat: it reaches the template as its wake and sleep events, and
-- MCT's attack indicator source, started once the template is awake, delivers
-- MC_NPCAttackIndicator as its update event.
-- Its log goes to sourceLog once a check sets it.
local sourceLog
local source=require('mc.attack_indicator').new(_G,function(event)
    template.events.update({},event)
end,setmetatable({},{__index=function(_,level)
    return function(...) if sourceLog then sourceLog[level](...) end end
end}))
local function startCombat()
    template.events.wake({},{name='wake',signal='MC_CombatStart'})
    source:start()
end
local function endCombat()
    template.events.sleep({},{name='sleep',signal='MC_CombatEnd'})
    source:stop()
end
local function hookCount()
    local count=0
    for _ in pairs(bridgeHooks) do count=count+1 end
    return count
end
assert(hookCount()==0,'nothing is hooked outside combat')
startCombat()
assert(bridgeHooks[ICON] and hookCount()==1 and next(hooks)==nil,
    'combat hooks the indicator icon change through the bridge, and nothing else')

icon(indicator,LEFT)
icon(indicator,SWORD_ICON)
assert(#delayed==0,'events are ignored until a cue is attached')

local cleanups={}
local function attach(size,visuals)
    local original={}
    local settings={GeneralScale=size}
    for key,value in pairs(visuals or {}) do settings[key]=value end
    local result=template.attach({hud=hud,cue=layer},
        {settings=settings,screen={width=1920,height=1080,scale=1},
            onCleanup=function(callback) cleanups[#cleanups+1]=callback end},original)
    assert(result==original)
end
-- The game's shield sprite, loaded on demand.
local SPRITE_PATH='/Game/_Dawnwalker/UI/_Unified/Combat/Atlas/Frames/T_Combat_Icon_Shield.T_Combat_Icon_Shield'
local sprite=object('T_Combat_Icon_Shield')
LoadAsset=function(path) if path==SPRITE_PATH then objects[path]=sprite end end
-- Where an arrow is, by the spec, on this 1920x1080 screen: a unit is 5% of the
-- screen along the arrow's axis (96 across, 54 down), sizes are in units of the
-- height. Indicator Size {L,H} takes an arrow from 1+4L to 1+4H units; it appears with its back
-- edge a unit out and Movement takes its tip that share of the way to 7 units.
-- The default Chevron is sized by its width, the larger side; its length along
-- its travel is its height, turned or not. Returns its render scale and how far
-- its centre is from the cue's.
local Drawn=require('preymonition.drawn')
local CHEVRON=Drawn.layout('chevron')
local RATIO=CHEVRON.height/CHEVRON.width
-- It keeps its starting scale and grows by extending its lines from the tip:
-- also returns how many design units wider than its shape it is.
local function arrowAt(across,size,move,grow,offset)
    local unit=across and 96 or 54
    local from,to=54*(1+4*size[1]),54*(1+4*size[2])
    local size=from+(to-from)*grow
    local first=unit+from*RATIO
    local last=first+math.max(0,7*unit-first)*move
    local scale=from/CHEVRON.width
    return scale,first+(last-first)*offset-from*RATIO/2,size/scale-CHEVRON.width
end
-- Whether a drawn arrow's lines are extended for a shape that much wider: every
-- part keeps its thickness and extends its length alike.
local function grownBy(arrow,extra)
    for index,part in ipairs(arrow.content.children) do
        local x,y=Drawn.growScale(CHEVRON.parts[index],extra)
        local now=part.RenderScale or {X=1,Y=1}
        if math.abs(now.X-x)>1e-6 or math.abs(now.Y-y)>1e-6 then return false end
    end
    return true
end
-- A drawn arrow's front part, which shows its colour.
local function front(arrow) return arrow.content.children[5].ColorAndOpacity end
-- Defaults: Indicator Size 10% to 50%, Movement 70%.
local function arrowAtDefault(across,grow,offset) return arrowAt(across,{0.1,0.5},0.7,grow,offset) end
local function equal(a,b) return math.abs(a-b)<1e-6 end
-- SizeBox > Overlay of the shield image and the arrows overlay, which holds
-- the four arrows.
local function shieldOf(cue) return cue.content.children[1] end
local function arrowOf(cue,index) return cue.content.children[2].children[index] end

attach(0)
-- Four widgets, then per arrow a box, a canvas and six parts.
assert(constructed==4+4*8 and #layer.children==1,'one box with a stack of shield, overlay and four drawn arrows')
local box=layer.children[1]
assert(box.WidthOverride==432 and box.HeightOverride==432,'Scale 0% is 40% of the short side')
-- Middle by default: the box is centred on the screen's middle.
assert(box.slot.VerticalAlignment==1 and math.abs(box.slot.Padding.Top-(1080-432)/2)<1e-6,
    'the shield is centred')
assert(box.RenderOpacity==0,'the cue starts hidden')
assert(shieldOf(box).BrushFromAtlasInterface==sprite and shieldOf(box).ColorAndOpacity.A==0,
    'the cue is created with the shield sprite, hidden')

-- Native work per event, measured on the fakes.
local function cost(callback)
    local methods,setters,finds=calls.methods,calls.setters,calls.finds
    callback()
    return calls.methods-methods,calls.setters-setters,calls.finds-finds
end
local budget={}
-- The arrow is handled as its event arrives, before any deferred work runs.
budget.onset={cost(function() icon(indicator,LEFT) end)}
local left=arrowOf(box,3)
assert(left.RenderOpacity==1,'the arrow shows as its event arrives')
local startScale,startCentre=arrowAtDefault(true,0,0)
-- 1.4 units (75.6) wide, its length along its travel that times the shape's
-- ratio; its back edge a unit (96) out, its centre half its length beyond.
assert(equal(startScale,75.6/CHEVRON.width) and equal(startCentre,96+75.6*RATIO/2),'the spec, by hand')
assert(shieldOf(box).BrushFromAtlasInterface==sprite and left.class=='/Script/UMG.SizeBox',
    'cue keeps its shield; its arrows are drawn')
assert(front(left).R==1 and front(left).G==0.67,'the shown arrow is in the lit colour')
assert(left.RenderOpacity==1 and equal(left.RenderScale.X,startScale) and equal(left.RenderTranslation.X,startCentre)
    and left.RenderTranslation.Y==0,'a detected arrow shows at once at full opacity, at its starting size and place')
budget.frame={cost(function() clock=clock+0.05; run() end)}
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'active cue rests at half opacity')
local endScale,endCentre,endExtra=arrowAtDefault(true,1,1)
-- Grown to 3 units (162) wide by extending its lines, its tip 70% of the
-- way from where it started to 7 units (672).
local tip=96+75.6*RATIO
assert(equal(endScale,startScale) and equal(endExtra,162/startScale-CHEVRON.width)
    and equal(endCentre,tip+(672-tip)*0.7-75.6*RATIO/2),'the spec, by hand')
assert(grownBy(arrowOf(box,4),0) and not grownBy(left,0),'only the shown arrow extends')
assert(left.RenderOpacity==1 and equal(left.RenderScale.X,endScale) and grownBy(left,endExtra),
    'the shown arrow extends its lines to its critical size, keeping their thickness')
assert(equal(left.RenderTranslation.X,endCentre) and left.RenderTranslation.Y==0,
    'the game\'s left arrow shows and travels out on the screen\'s right')
assert(arrowOf(box,1).RenderOpacity==0,'other arrows stay hidden')

-- The indicator turning to the sword resolves the attack.
budget.resolve={cost(function() icon(indicator,SWORD_ICON) end)}
-- Native work per event, MCT's source included, stays within budget: methods,
-- of which setters, and object lookups. The frame counts no clock lookup: the
-- clock is kept.
local function within(name,methods,setters,finds)
    local spent=budget[name]
    assert(spent[1]<=methods and spent[2]<=setters and spent[3]<=finds,
        name..' costs '..table.concat(spent,'/')..', over '..methods..'/'..setters..'/'..finds)
end
within('onset',60,14,1)
within('frame',25,8,0)
within('resolve',42,6,1)
run()
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'a resolved attack keeps the idle cue')
assert(left.RenderOpacity==0 and equal(left.RenderScale.X,startScale),'a resolved attack puts the arrow out at once')

endCombat()
run()
settle(0.05)
assert(box.RenderOpacity==0 and left.RenderOpacity==0,'combat end fades and resets the cue')
assert(bridgeHooks[ICON]==nil and #delayed==0,'combat end unhooks the indicator')

-- After combat end, only a combat start lets attacks through again.
startCombat()
run()
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6 and left.RenderOpacity==0,'combat start shows the idle cue')
icon(indicator,LEFT)
run()
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6 and left.RenderOpacity==1,'combat start re-enables the cue')
local hooked=bridgeHooks[ICON]
startCombat()
run()
assert(#delayed==0 and bridgeHooks[ICON]==hooked,'a second combat start changes nothing')
-- Combat ending or starting mid-animation never strands the animation.
icon(indicator,SWORD_ICON)
settle(0.05)
icon(indicator,LEFT)
assert(#delayed>0,'an arrow animation is under way')
endCombat()
settle(0.05)
assert(math.abs(box.RenderOpacity)<1e-6,'combat ending mid-animation still fades the cue out')
endCombat()
startCombat()
endCombat()
startCombat()
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'quick combat changes settle on the idle cue')

-- A settings commit reattaches the same MCT layer after its cleanup.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
assert(#layer.children==0,'cleanup removes the cue from the layer')
attach(50)
assert(#layer.children==1 and shieldOf(layer.children[1]).RenderScale.X==1.5,'reattach rebuilds once at the new scale')
assert(layer.children[1].WidthOverride==432 and layer.children[1].content.children[2].slot.Padding.Left==18,
    'Scale resizes only the shield: the box and the arrows keep their size')
-- Back to Scale 0%: the arrow travel below is in units of 54.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(0)
assert(#delayed==0 and layer.children[1].RenderOpacity==0,'a reattached cue waits for the next arrow')

-- An indicator in view shows its attack; a hidden one's changes are not attacks.
local other=newIndicator('WBP_CombatTargetIndicator_C_2','BottomArrow')
local bottom=arrowOf(layer.children[1],2)
icon(other,BOTTOM)
local _,bottomStart=arrowAtDefault(false,0,0)
local bottomScale,bottomEnd,bottomExtra=arrowAtDefault(false,1,1)
assert(equal(bottom.RenderTranslation.Y,bottomStart),'the bottom arrow shows up by the height\'s units')
run()
settle(0.05)
assert(math.abs(bottom.RenderOpacity-1)<1e-6,'an indicator attack shows its direction')
assert(equal(bottom.RenderTranslation.Y,bottomEnd) and bottom.RenderTranslation.X==0,'and travels as far as Movement takes it')
local hidden=newIndicator('WBP_CombatTargetIndicator_C_3','RightArrow')
hidden.visible=false
icon(hidden,RIGHT)
run()
settle(0.05)
assert(arrowOf(layer.children[1],4).RenderOpacity==0
    and math.abs(bottom.RenderOpacity-1)<1e-6,'an attack on a hidden indicator is not shown')

-- The parry window opens: the arrow turns red at once, 2.5 times its size,
-- where it travelled, held until resolved.
icon(other,BOTTOM+PARRY)
run()
assert(front(bottom).R==1 and front(bottom).G==0.2,'a critical arrow turns red at once')
assert(equal(bottom.RenderScale.X,bottomScale) and grownBy(bottom,bottomExtra) and math.abs(bottom.RenderOpacity-1)<1e-6
    and equal(bottom.RenderTranslation.Y,bottomEnd),'a critical arrow jumps to its grown size where it travelled')
assert(#delayed==0,'a critical arrow needs no frames: it does not pulse')
-- The same attack out of its window again changes nothing.
icon(other,BOTTOM)
run()
assert(front(bottom).G==0.2,'the critical arrow holds')
-- The sword means no attack is pending: resolved.
icon(other,SWORD_ICON)
run()
assert(bottom.RenderOpacity==0 and equal(bottom.RenderScale.X,startScale) and math.abs(layer.children[1].RenderOpacity-0.5)<1e-6,
    'a resolved attack puts its arrow out at once and keeps the idle cue')
settle(0.05)
icon(other,BOTTOM)
run()
settle(0.05)
assert(math.abs(bottom.RenderOpacity-1)<1e-6,'a new attack shows again')
-- A weak spot is no attack either.
icon(other,11)
run()
assert(bottom.RenderOpacity==0,'a weak spot resolves the attack')
settle(0.05)

-- One frame can resolve an attack and start the next: handled in the game's
-- order, the new arrow survives the sword that resolved the old one.
icon(other,BOTTOM)
icon(other,BOTTOM+PARRY)
icon(other,SWORD_ICON)
icon(other,LEFT)
local otherLeft=arrowOf(layer.children[1],3)
assert(otherLeft.RenderOpacity==1 and bottom.RenderOpacity==0,'the next attack shows in the same frame')
settle(0.05)
assert(otherLeft.RenderOpacity==1,'and is still shown afterwards')
icon(other,SWORD_ICON)
settle(0.05)

-- A parry window whose arrow was never seen shows the arrow red at once.
icon(other,TOP+PARRY)
local otherTop=arrowOf(layer.children[1],1)
assert(otherTop.RenderOpacity==1 and front(otherTop).G==0.2,'arrow and window together show it critical')
icon(other,SWORD_ICON)
settle(0.05)

-- An unblockable attack: the centre turns to a skull in place, growing from its
-- size to twice that over 0.2s, then holding.
local cueShield=shieldOf(layer.children[1])
icon(other,SKULL_ICON)
assert(cueShield.BrushFromAtlasInterface==SKULL and math.abs(cueShield.RenderScale.X-1)<1e-6,
    'an unblockable attack shows the skull at its size')
clock=clock+0.1
run()
assert(math.abs(cueShield.RenderScale.X-1.5)<1e-6 and cueShield.RenderTranslation==nil,'it grows in place')
settle(0.05)
assert(math.abs(cueShield.RenderScale.X-2)<1e-6 and #delayed==0,'to twice its size, then holds')
icon(other,SWORD_ICON)
run()
assert(math.abs(cueShield.RenderScale.X-1)<1e-6,'the shield returns at its size')
assert(cueShield.BrushFromAtlasInterface==sprite,'the shield returns once it passes')
settle(0.05)
icon(other,SKULL_ICON)
run()
endCombat()
run()
assert(cueShield.BrushFromAtlasInterface==sprite,'combat end returns the shield')
settle(0.05)
startCombat()
run()
settle(0.05)

-- The game gives a hidden indicator the same updates; only the visible one counts.
local twin=newIndicator('WBP_CombatTargetIndicator_C_4','BottomArrow')
twin.visible=false
icon(other,BOTTOM)
icon(twin,BOTTOM)
icon(twin,SKULL_ICON)
assert(cueShield.BrushFromAtlasInterface==sprite,'a hidden indicator shows no skull')
icon(other,BOTTOM+PARRY)
icon(twin,BOTTOM+PARRY)
assert(front(bottom).G==0.2 and equal(bottom.RenderScale.X,bottomScale),
    'the visible indicator still turns critical')
icon(twin,SWORD_ICON)
assert(bottom.RenderOpacity==1,'a hidden indicator resolves nothing it did not show')
-- Its own indicator hidden, as when an attack is parried, the arrow goes.
other.visible=false
icon(other,BOTTOM)
assert(bottom.RenderOpacity==0,'a change on its hidden source indicator puts it out')
other.visible=true
icon(other,SWORD_ICON)
settle(0.05)
-- Nor does a hidden twin take away the skull its visible indicator shows.
icon(other,SKULL_ICON)
assert(cueShield.BrushFromAtlasInterface==SKULL)
icon(twin,SWORD_ICON)
icon(twin,BOTTOM+PARRY)
assert(cueShield.BrushFromAtlasInterface==SKULL,'a hidden twin leaves the skull')
icon(other,SWORD_ICON)
assert(cueShield.BrushFromAtlasInterface==sprite,'its own indicator takes it away')
-- A skull followed straight by an arrow gives way to it.
icon(other,SKULL_ICON)
icon(other,BOTTOM)
assert(cueShield.BrushFromAtlasInterface==sprite and bottom.RenderOpacity==1,'an arrow after the skull returns the shield')
icon(other,SWORD_ICON)
settle(0.05)

-- From here on deferred work runs per frame, as when the engine tick is hooked.
local delays=0
EngineTickAvailable=true
ExecuteInGameThreadAfterFrames=function(count,callback)
    assert(count==1)
    delayed[#delayed+1]=callback
end
local executeWithDelay=ExecuteWithDelay
ExecuteWithDelay=function(...) delays=delays+1; return executeWithDelay(...) end

-- A collected HUD stops pending animation without touching the cue.
local cue=layer.children[1]
icon(indicator,LEFT)
run()
hud.invalid=true
local before=cue.RenderOpacity
settle(0.05)
assert(cue.RenderOpacity==before,'a cue whose HUD is gone is never written')
hud.invalid=nil

-- The cue settings: shield shown, arrows from 2 to 5 units moving half as far,
-- the time warning for arrows, and a larger skull with the stinger.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
assert(#posted==0,'no sound plays without one chosen')
attach(0,{GeneralShield=1,ParryMovement=50,ParrySize={25,100},ParrySound=2,
    UnblockableSize=150,UnblockableSound=2})
local tuned=layer.children[1]
assert(shieldOf(tuned).ColorAndOpacity.A==0.2,'the background shield can be shown')
endCombat()
startCombat()
run()
settle(0.05)
-- The indicator's queued attack names its attacker through a combat component.
local enemy=object('Enemy')
function enemy:K2_GetActorLocation() return {X=7,Y=8,Z=9} end
local combat=object('Enemy.Combat')
function combat:GetOwner() return enemy end
local attacks={{Instigator=object('Gone',{invalid=true})},{Instigator=combat},{Instigator=nil}}
function attacks:GetArrayNum() return 3 end
other.AttackQueue=attacks
icon(other,BOTTOM)
local tunedBottom=arrowOf(tuned,2)
local tunedScale,tunedCentre=arrowAt(false,{0.25,1},0.5,0,0)
-- Two units (108) wide, its back edge a unit (54) out.
assert(equal(tunedScale,108/CHEVRON.width) and equal(tunedCentre,54+108*RATIO/2),'the spec, by hand')
assert(equal(tunedBottom.RenderScale.X,tunedScale) and equal(tunedBottom.RenderTranslation.Y,tunedCentre),
    'Indicator Size sizes the arrow where it appears')
assert(#posted==1 and posted[1].event==SWISH_SOUND and posted[1].location.Z==9,
    'the chosen arrow sound plays at the attacker when the arrow appears')
-- An indicator whose queue names no attacker plays at the player.
other.AttackQueue=nil
settle(0.05)
local tunedEndScale,tunedEnd,tunedExtra=arrowAt(false,{0.25,1},0.5,1,1)
-- Extended to five units (270) wide, its tip halfway from where it started to
-- 7 units (378).
local tunedTip=54+108*RATIO
assert(equal(tunedEndScale,tunedScale) and equal(tunedExtra,270/tunedScale-CHEVRON.width)
    and equal(tunedEnd,tunedTip+(378-tunedTip)/2-108*RATIO/2),'the spec, by hand')
assert(equal(tunedBottom.RenderScale.X,tunedEndScale) and grownBy(tunedBottom,tunedExtra)
    and equal(tunedBottom.RenderTranslation.Y,tunedEnd),'and Movement where it ends')
icon(other,SKULL_ICON)
assert(shieldOf(tuned).RenderScale.X==1.5 and #posted==2 and posted[2].event==BOOM_SOUND
    and posted[2].location.Z==3,'the unblockable skull takes its size and plays its sound')
icon(other,SWORD_ICON)
assert(shieldOf(tuned).RenderScale.X==1 and shieldOf(tuned).ColorAndOpacity.A==0.2,
    'the shield returns at its size and setting')
icon(other,SWORD_ICON)
settle(0.05)

-- With the overlay style off, an attack still plays its sound but shows no arrow.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(0,{ParryStyle=0,ParrySound=2})
local hiddenArrows=layer.children[1]
endCombat()
startCombat()
run()
settle(0.05)
local before=#posted
icon(other,BOTTOM)
settle(0.05)
assert(arrowOf(hiddenArrows,2).RenderOpacity==0,'the overlay style off shows no arrow')
assert(#posted==before+1,'and the parry sound still plays')
icon(other,SWORD_ICON)
settle(0.05)

-- The Chevron style draws its own arrows.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(0,{ParryStyle=2})
local looks=layer.children[1]
assert(#layer.children==1,'the center cue builds no screen edges')
endCombat()
startCombat()
run()
settle(0.05)
icon(other,BOTTOM)
local drawn=arrowOf(looks,2)
-- A drawn arrow: a box its shape's size, turned to its direction, holding a canvas
-- of solid parts, back to front: black outlines, dimmer insets, then the front.
local chevron=CHEVRON
local function partsOf(arrow) return arrow.content.children end
assert(drawn.class=='/Script/UMG.SizeBox' and drawn.RenderTransformAngle==180
    and equal(drawn.WidthOverride,chevron.width) and #partsOf(drawn)==6,'the bottom chevron is drawn, turned down')
local function colours(arrow)
    local list={}
    for index,part in ipairs(partsOf(arrow)) do list[index]=part.ColorAndOpacity end
    return list
end
local lit=colours(drawn)
assert(lit[1].R==0 and lit[2].R==0,'a thin black outline')
assert(equal(lit[3].R,0.55) and equal(lit[3].G,0.67*0.55),'a dimmer inset of the arrow colour')
assert(lit[5].R==1 and lit[5].G==0.67,'and the front in the arrow colour')
settle(0.05)
-- Its size and place follow the same spec, from the drawn shape's box.
local chevronScale,_,chevronExtra=arrowAtDefault(false,1,1)
assert(drawn.RenderOpacity==1 and equal(drawn.RenderScale.X,chevronScale) and grownBy(drawn,chevronExtra),
    'a drawn arrow keeps its starting scale and extends its lines')
icon(other,BOTTOM+PARRY)
run()
local red=colours(drawn)
assert(red[1].R==0 and red[5].R==1 and red[5].G==0.2 and equal(red[3].G,0.2*0.55),'critical turns the inset and front red')
icon(other,SWORD_ICON)
settle(0.05)
assert(drawn.RenderOpacity==0,'the arrow goes with the attack')

-- The Perspective style lays the Chevron on a ground plane at the waist, seen
-- from 20 degrees above at half a screen height away: up is away from the camera.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(0,{ParryStyle=3})
local ground=layer.children[1]
endCombat()
startCombat()
run()
settle(0.05)
-- A flat place, as the spec puts it, projected onto the plane: its depth is
-- how far up it is; nearer things grow.
local function projected(x,y)
    local depth=-y
    local k=540/(540+depth*math.cos(math.rad(20)))
    return x*k,-depth*math.sin(math.rad(20))*k,k
end
icon(other,BOTTOM)
settle(0.05)
local near=arrowOf(ground,2)
local flatScale,flatCentre=arrowAtDefault(false,1,1)
local _,nearY,nearK=projected(0,flatCentre)
assert(near.RenderTransformAngle==nil,'a ground arrow is drawn already turned')
assert(equal(near.RenderTranslation.Y,nearY) and equal(near.RenderTranslation.X,0) and nearY<flatCentre,
    'the bottom arrow shows where its flat place projects, foreshortened')
assert(nearK>1 and equal(near.RenderScale.X,flatScale*nearK),'and larger, being nearer')
icon(other,SWORD_ICON)
settle(0.05)
icon(other,TOP)
settle(0.05)
local far=arrowOf(ground,1)
local _,farY,farK=projected(0,-flatCentre)
assert(equal(far.RenderTranslation.Y,farY) and farK<1 and equal(far.RenderScale.X,flatScale*farK),
    'the top arrow shows further up the plane, smaller')
icon(other,SWORD_ICON)
settle(0.05)
-- Side arrows lie on the plane too: their arms are sheared onto it.
local side=arrowOf(ground,3)
local sheared=0
for _,part in ipairs(side.content.children) do
    if part.RenderShear and math.abs(part.RenderShear.X)>1e-3 then sheared=sheared+1 end
end
assert(side.RenderTransformAngle==nil and sheared>0,'side arrows are sheared onto the plane')

-- The Fancy style shows the mod's pictures, an arrow pointing right, turned to
-- each direction; the red picture shows while the attack is critical. A picture
-- scales as a whole as the arrow grows.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(0,{ParryStyle=4})
local fancy=layer.children[1]
assert(imported[#imported]:match('fancy_') and #imported==2,'both pictures load from the images folder')
endCombat()
startCombat()
run()
settle(0.05)
icon(other,BOTTOM)
local picture=arrowOf(fancy,2)
local pictures=picture.content.children
assert(picture.class=='/Script/UMG.SizeBox' and picture.RenderTransformAngle==90 and #pictures==2
    and pictures[1].BrushFromTexture.name=='Texture fancy_normal' and pictures[2].BrushFromTexture.name=='Texture fancy_critical',
    'the bottom arrow is the right-pointing picture turned down')
assert(arrowOf(fancy,1).RenderTransformAngle==270 and arrowOf(fancy,3).RenderTransformAngle==0
    and arrowOf(fancy,4).RenderTransformAngle==180,'and turned up, right and left for the others')
assert(pictures[1].ColorAndOpacity.A==1 and pictures[2].ColorAndOpacity.A==0,'yellow while not critical')
settle(0.05)
-- Its box is the arrow's span, 428 along and 1774 across, sized by the 1774.
local along,across=687-259,1774
local from,to=54*1.4,54*3
local first=54+from*along/across
local last=first+(378-first)*0.7
assert(equal(picture.RenderScale.X,to/across) and equal(picture.RenderTranslation.Y,last-to*along/across/2),
    'it scales as a whole, its tip where the travel puts it')
icon(other,BOTTOM+PARRY)
run()
assert(pictures[1].ColorAndOpacity.A==0 and pictures[2].ColorAndOpacity.A==1,'red once critical')
icon(other,SWORD_ICON)
settle(0.05)
-- Without its pictures the cue draws a Chevron.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
fancyMissing=true
attach(0,{ParryStyle=4})
assert(#arrowOf(layer.children[1],2).content.children==6,'missing pictures fall back to the Chevron')
fancyMissing=false

-- A critical attack: the arrow turns red, and the shield follows its setting.
-- Each case shows the attack, opens its parry window and resolves it.
local function criticalAttack(settings)
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    attach(0,settings)
    local cue=layer.children[1]
    endCombat()
    startCombat()
    run()
    settle(0.05)
    icon(other,BOTTOM)
    settle(0.05)
    local before={color=shieldOf(cue).ColorAndOpacity,scale=shieldOf(cue).RenderScale}
    icon(other,BOTTOM+PARRY)
    run()
    return cue,before
end
local function resolveAttack()
    icon(other,SWORD_ICON)
    settle(0.05)
end
local function red(color) return color.R==1 and color.G==0.2 and color.B==0 end

-- Critical: hidden until critical, then pops in red and grows to twice its size.
local dynamic,before=criticalAttack({GeneralShield=3})
assert(before.color.A==0,'a Critical shield waits unseen')
assert(red(shieldOf(dynamic).ColorAndOpacity) and shieldOf(dynamic).ColorAndOpacity.A==1
    and math.abs(shieldOf(dynamic).RenderScale.X-1)<1e-6,'a Critical shield pops in red at its size')
assert(red(front(arrowOf(dynamic,2))),'the arrow turns red too')
clock=clock+0.1
run()
assert(math.abs(shieldOf(dynamic).RenderScale.X-1.5)<1e-6,'growing over 0.2s')
settle(0.05)
assert(math.abs(shieldOf(dynamic).RenderScale.X-2)<1e-6,'to twice its size')
resolveAttack()
assert(shieldOf(dynamic).ColorAndOpacity.A==0 and math.abs(shieldOf(dynamic).RenderScale.X-1)<1e-6,
    'the resolve hides the shield')

-- In Combat: the faint shield turns red at its size, then returns.
local static=criticalAttack({GeneralShield=1})
assert(red(shieldOf(static).ColorAndOpacity) and math.abs(shieldOf(static).RenderScale.X-1)<1e-6,
    'an In Combat shield turns red without growing')
resolveAttack()
assert(shieldOf(static).ColorAndOpacity.A==0.2 and not red(shieldOf(static).ColorAndOpacity),
    'and returns to its faint white')

-- Defending: faint while the attack shows, red once critical, gone once resolved.
local defending,shown=criticalAttack({GeneralShield=2})
assert(shown.color.A==0.2 and not red(shown.color),'a Defending shield shows faintly with the attack')
assert(red(shieldOf(defending).ColorAndOpacity) and math.abs(shieldOf(defending).RenderScale.X-1)<1e-6,
    'turns red without growing once critical')
resolveAttack()
assert(shieldOf(defending).ColorAndOpacity.A==0,'and hides once the attack resolves')

-- Off: no shield, even for a critical attack; the skull still shows.
local hidden=criticalAttack({GeneralShield=0})
assert(shieldOf(hidden).ColorAndOpacity.A==0,'with the shield off none shows')
icon(other,SKULL_ICON)
assert(shieldOf(hidden).BrushFromAtlasInterface==SKULL and shieldOf(hidden).ColorAndOpacity.A==1,
    'the skull takes the centre')
settle(0.05)
assert(shieldOf(hidden).ColorAndOpacity.A==1,'and the critical shield never covers it')
icon(other,SWORD_ICON)
resolveAttack()

-- Animations take 200 ms times the parry window multiplier read when combat
-- starts: 280 ms at 1.4, which is also assumed when it cannot be read.
for _,multiplier in ipairs({1.4,false}) do
    parryMultiplier=multiplier or nil
    local timed=criticalAttack({})
    resolveAttack()
    icon(other,BOTTOM)
    local arrow=arrowOf(timed,2)
    local half=0.14
    clock=clock+half
    run()
    assert(equal(arrow.RenderTranslation.Y,select(2,arrowAtDefault(false,0.5,0.5))),'halfway through its travel')
    clock=clock+half
    run()
    assert(equal(arrow.RenderTranslation.Y,bottomEnd),'and done at its duration')
    resolveAttack()
end
parryMultiplier=1

-- A lasting fault handling events is logged once per kind; the repeats are
-- counted when combat ends. A direction the cue has no arrow for faults.
local Session=require('preymonition.session')
local logged={}
sourceLog=setmetatable({enabled=function() return false end},{__index=function(_,level)
    return function(...)
        local parts={level}
        for index=1,select('#',...) do parts[#parts+1]=tostring((select(index,...))) end
        logged[#logged+1]=table.concat(parts,' ')
    end
end})
Session.setLog(sourceLog)
for index=1,3 do
    for _,kind in ipairs({'arrow','critical'}) do
        template.events.update({},{kind=kind,direction=99,path=kind..index,indicator=other,sequence=0})
    end
end
local errors=0
for _,line in ipairs(logged) do if line:match('^error') then errors=errors+1 end end
assert(errors==2,'one error per kind, not one per call')
endCombat()
local repeats=0
for _,line in ipairs(logged) do if line:match('^warn') and line:match('2%s+more times') then repeats=repeats+1 end end
assert(repeats==2,'repeats are counted at combat end')
startCombat()

for index=#cleanups,1,-1 do cleanups[index]() end
assert(scans==0,'nothing scans for objects')
assert(delays==0,'with the engine tick hooked nothing waits on ExecuteWithDelay')
-- Ten handles per cue, and six parts per arrow held twice (to colour and to
-- grow), for fourteen drawn cues; the Fancy cue holds its two pictures per arrow.
assert(released==(10+2*4*6)*14+(10+4*2),'each detached cue releases its handles')
-- Stopping MCT detaches every cue, then puts the template to sleep.
removed=0
endCombat()
assert(removed==1 and hookCount()==0,'sleep unhooks the indicator')
endCombat()
assert(removed==1,'a second sleep has nothing left to remove')

-- Position: Below puts the box's bottom 10% of the height above the bottom
-- edge; Above puts its top 10% below the top edge.
for position,top in pairs({[0]=1080*0.9-432,[2]=1080*0.1}) do
    cleanups={}
    attach(0,{GeneralPosition=position})
    assert(math.abs(layer.children[1].slot.Padding.Top-top)<1e-6,'shield position '..position)
    for index=#cleanups,1,-1 do cleanups[index]() end
end
-- A scaled shield keeps its edge there: at +50% it is 648 across, and the box
-- shares its centre.
cleanups={}
attach(50,{GeneralPosition=0})
assert(math.abs(layer.children[1].slot.Padding.Top-(1080*0.9-324-216))<1e-6,'a scaled shield sits by its own edge')
for index=#cleanups,1,-1 do cleanups[index]() end

-- At TRACE the hooks are the same: tracing adds lines, never hooks.
local Session=require('preymonition.session')
Session.setLog(dofile('Preymonition/Scripts/vendor/mc_log.lua').wrap(function() end))
startCombat()
assert(hookCount()==1 and next(hooks)==nil,'TRACE adds no hooks')
removed=0
endCombat()
assert(removed==1 and hookCount()==0,'and unhooked with the rest')
print('PASS: Preymonition session hooks only in combat, follows attacks, resolves, reattach and cleanup')
