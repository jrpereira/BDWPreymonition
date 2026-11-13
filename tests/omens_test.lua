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
local template=dofile('Preymonition/Scripts/mc_omens.lua')
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
    -- The cue box is 40% of the short side, 432 high; the omens line up on the
    -- Background's shield at its default size, half the screen height. The
    -- hand-worked arrows below use Size 10% to 50% and Movement 5% to 60%.
    local settings={ParrySize={10,50},ParryMovement={5,60}}
    for key,value in pairs(visuals or {}) do settings[key]=value end
    local result=template.attach({hud=hud,cue=layer},
        {settings=settings,screen={width=1920,height=1080,scale=1},
            onCleanup=function(callback) cleanups[#cleanups+1]=callback end},original)
    assert(result==original)
end
-- Where an arrow is, by the spec, on this 1920x1080 screen with the cue in the
-- middle: the screen edge is 960 across and 540 down from its centre, and sizes
-- are in units of 5% of the height (54). Size {L,H} takes an arrow from
-- 1+9L to 1+9H units. Movement from Center {L,H} is the space the arrow has:
-- at 0% its back edge (at its starting size) is on the centre, at 100% its tip
-- is at the screen edge. It shows with its tip at L and stops it at H.
-- The default Chevron is sized by its width, the larger side; its length along
-- its travel is its height, turned or not. Returns its render scale and how far
-- its centre is from the cue's.
local Drawn=require('preymonition.omens_drawn')
local CHEVRON=Drawn.layout('chevron')
local RATIO=CHEVRON.height/CHEVRON.width
-- It keeps its starting scale and grows by extending its lines from the tip:
-- also returns how many design units wider than its shape it is.
local function arrowAt(across,size,move,grow,offset)
    local edge=across and 960 or 540
    local from,to=54*(1+9*size[1]),54*(1+9*size[2])
    local size=from+(to-from)*grow
    -- Movement is the space the arrow has: at 0% its back edge is on the
    -- centre, at 100% its tip at the screen edge.
    local length=from*RATIO
    local first=length+move[1]*(edge-length)
    local last=length+move[2]*(edge-length)
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
-- The tests' Size 10% to 50% and Movement from Center 5% to 60% (the defaults are 30%-80% and 40%-60%).
local function arrowAtDefault(across,grow,offset) return arrowAt(across,{0.1,0.5},{0.05,0.6},grow,offset) end
local function equal(a,b) return math.abs(a-b)<1e-6 end
-- SizeBox > Overlay of the centre image (the skull) and the arrows overlay,
-- which holds the four arrows.
local function shieldOf(cue) return cue.content.children[1] end
local function arrowOf(cue,index) return cue.content.children[2].children[index] end

attach()
-- Four widgets, then per arrow a box, a canvas and six parts.
assert(constructed==4+4*8 and #layer.children==1,'one box with a stack of centre, overlay and four drawn arrows')
local box=layer.children[1]
assert(box.WidthOverride==432 and box.HeightOverride==432,'the box is 40% of the short side')
-- Middle by default: the box is centred on the screen's middle.
assert(box.slot.VerticalAlignment==1 and math.abs(box.slot.Padding.Top-(1080-432)/2)<1e-6,
    'the cue is centred')
assert(box.RenderOpacity==0,'the cue starts hidden')
assert(shieldOf(box).BrushFromAtlasInterface==nil and shieldOf(box).ColorAndOpacity.A==0,
    'the centre is clear: the shield is the Background template\'s')

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
-- 1.9 units (102.6) wide, its length along its travel that times the shape's
-- ratio; with its back edge on the centre its tip is at 0%, so 5% puts its tip
-- 5% of the rest of the way to the edge on, its centre half its length back.
local length=102.6*RATIO
assert(equal(startScale,102.6/CHEVRON.width) and equal(startCentre,length+0.05*(960-length)-length/2),'the spec, by hand')
assert(shieldOf(box).ColorAndOpacity.A==0 and left.class=='/Script/UMG.SizeBox',
    'the centre stays clear; the arrows are drawn')
assert(front(left).R==1 and front(left).G==0.67,'the shown arrow is in the lit colour')
assert(left.RenderOpacity==1 and equal(left.RenderScale.X,startScale) and equal(left.RenderTranslation.X,startCentre)
    and left.RenderTranslation.Y==0,'a detected arrow shows at once at full opacity, at its starting size and place')
budget.frame={cost(function() clock=clock+0.05; run() end)}
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'active cue rests at half opacity')
local endScale,endCentre,endExtra=arrowAtDefault(true,1,1)
-- Grown to 5.5 units (297) wide by extending its lines, its tip 60% of the
-- space it has on towards the screen edge.
assert(equal(endScale,startScale) and equal(endExtra,297/startScale-CHEVRON.width)
    and equal(endCentre,length+0.6*(960-length)-length/2),'the spec, by hand')
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
attach()
assert(#layer.children==1 and layer.children[1].WidthOverride==432
    and layer.children[1].content.children[2].slot.Padding.Left==18,'reattach rebuilds once')
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

-- An unblockable attack: the centre turns to a skull in place, growing over
-- 0.2s from its starting size to its grown size, then holding. Size runs from 1
-- unit (54) at 0% to the screen height (1080) at 100%; the default 60%-100% takes
-- it from 1+19*0.6 units (669.6) to 1080. The centre image fills the 432 box.
local function skullAt(share) return 54*(1+19*share)/432 end
local cueShield=shieldOf(layer.children[1])
-- Whether the centre shows the skull; it is clear otherwise.
local function skullShown(image) return image.BrushFromAtlasInterface==SKULL and image.ColorAndOpacity.A==1 end
local function clear(image) return image.ColorAndOpacity.A==0 end
icon(other,SKULL_ICON)
assert(skullShown(cueShield) and math.abs(cueShield.RenderScale.X-skullAt(0.6))<1e-6,
    'an unblockable attack shows the skull at its starting size')
clock=clock+0.1
run()
assert(math.abs(cueShield.RenderScale.X-skullAt(0.8))<1e-6 and cueShield.RenderTranslation==nil,'it grows in place')
settle(0.05)
assert(math.abs(cueShield.RenderScale.X*432-1080)<1e-6 and #delayed==0,'to the full screen height, then holds')
icon(other,SWORD_ICON)
run()
assert(clear(cueShield),'the centre clears once it passes')
settle(0.05)
icon(other,SKULL_ICON)
run()
endCombat()
run()
assert(clear(cueShield),'combat end clears the skull')
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
assert(clear(cueShield),'a hidden indicator shows no skull')
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
assert(skullShown(cueShield))
icon(twin,SWORD_ICON)
icon(twin,BOTTOM+PARRY)
assert(skullShown(cueShield),'a hidden twin leaves the skull')
icon(other,SWORD_ICON)
assert(clear(cueShield),'its own indicator takes it away')
-- A skull followed straight by an arrow gives way to it.
icon(other,SKULL_ICON)
icon(other,BOTTOM)
assert(clear(cueShield) and bottom.RenderOpacity==1,'an arrow after the skull clears it')
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

-- The cue settings: arrows from 3.25 to 10 units moving from 10% to 50%,
-- the time warning for arrows, and a larger skull with the stinger.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
assert(#posted==0,'no sound plays without one chosen')
attach(nil,{ParryMovement={10,50},ParrySize={25,100},ParrySound=2,
    UnblockableSize={0,50},UnblockableSound=2})
local tuned=layer.children[1]
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
local tunedScale,tunedCentre=arrowAt(false,{0.25,1},{0.1,0.5},0,0)
-- 3.25 units (175.5) wide, its tip 10% of the space it has on (the bottom
-- edge 540 away), its centre half its length back.
local tunedLength=175.5*RATIO
assert(equal(tunedScale,175.5/CHEVRON.width) and equal(tunedCentre,tunedLength+0.1*(540-tunedLength)-tunedLength/2),
    'the spec, by hand')
assert(equal(tunedBottom.RenderScale.X,tunedScale) and equal(tunedBottom.RenderTranslation.Y,tunedCentre),
    'Size sizes the arrow where it appears')
assert(#posted==1 and posted[1].event==SWISH_SOUND and posted[1].location.Z==9,
    'the chosen arrow sound plays at the attacker when the arrow appears')
-- An indicator whose queue names no attacker plays at the player.
other.AttackQueue=nil
settle(0.05)
local tunedEndScale,tunedEnd,tunedExtra=arrowAt(false,{0.25,1},{0.1,0.5},1,1)
-- Extended to ten units (540) wide, its tip halfway through the space it has.
assert(equal(tunedEndScale,tunedScale) and equal(tunedExtra,540/tunedScale-CHEVRON.width)
    and equal(tunedEnd,tunedLength+0.5*(540-tunedLength)-tunedLength/2),'the spec, by hand')
assert(equal(tunedBottom.RenderScale.X,tunedEndScale) and grownBy(tunedBottom,tunedExtra)
    and equal(tunedBottom.RenderTranslation.Y,tunedEnd),'and Movement where it ends')
icon(other,SKULL_ICON)
assert(math.abs(shieldOf(tuned).RenderScale.X-skullAt(0))<1e-6 and #posted==2 and posted[2].event==BOOM_SOUND
    and posted[2].location.Z==3,'the unblockable skull takes its size and plays its sound')
icon(other,SWORD_ICON)
assert(shieldOf(tuned).ColorAndOpacity.A==0,'the skull goes with the attack')
icon(other,SWORD_ICON)
settle(0.05)

-- With the overlay style off, an attack still plays its sound but shows no arrow.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(nil,{ParryStyle=0,ParrySound=2})
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
attach(nil,{ParryStyle=2})
local looks=layer.children[1]
assert(#layer.children==1,'the omens build no screen edges')
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
attach(nil,{ParryStyle=3})
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
-- Movement shares are of the furthest an arrow can show on the screen: the
-- bottom edge (540 down) for a nearing arrow; for a receding one, where it has
-- shrunk to a quarter of its size, short of the horizon. How far out on the
-- plane a share of the screen distance is:
local sin,cos=math.sin(math.rad(20)),math.cos(math.rad(20))
local function onPlane(share,away)
    local screen=share*(away and 0.75*540*sin/cos or 540)
    return screen*540/(540*sin+(away and -1 or 1)*screen*cos)
end
-- And back: the share a distance on the plane is.
local function shareOnPlane(flat,away)
    local screen=flat*540*sin/(540+(away and 1 or -1)*flat*cos)
    return screen/(away and 0.75*540*sin/cos or 540)
end
-- Movement is the space the arrow has: 0% puts its back edge on the centre.
local function tipOnPlane(share,away,length)
    local start=shareOnPlane(length,away)
    return onPlane(start+(1-start)*share,away)
end
-- The default Chevron starts 1.9 units (102.6) wide and keeps that scale; its
-- tip ends 60% of the way.
local flatScale,length=102.6/CHEVRON.width,102.6*RATIO
icon(other,BOTTOM)
settle(0.05)
local near=arrowOf(ground,2)
local nearCentre=tipOnPlane(0.6,false,length)-length/2
local _,nearY,nearK=projected(0,nearCentre)
assert(near.RenderTransformAngle==nil,'a ground arrow is drawn already turned')
assert(equal(near.RenderTranslation.Y,nearY) and equal(near.RenderTranslation.X,0) and nearY<nearCentre,
    'the bottom arrow shows where its flat place projects, foreshortened')
assert(nearK>1 and equal(near.RenderScale.X,flatScale*nearK),'and larger, being nearer')
icon(other,SWORD_ICON)
settle(0.05)
icon(other,TOP)
settle(0.05)
local far=arrowOf(ground,1)
local farCentre=tipOnPlane(0.6,true,length)-length/2
local _,farY,farK=projected(0,-farCentre)
assert(equal(far.RenderTranslation.Y,farY) and farK<1 and equal(far.RenderScale.X,flatScale*farK),
    'the top arrow shows further up the plane, smaller')
assert(farCentre>nearCentre,'the same share covers more ground receding than nearing')
icon(other,SWORD_ICON)
settle(0.05)
-- At 100% a nearing tip reaches the screen edge, and a receding one shows at a
-- quarter of its size.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(nil,{ParryStyle=3,ParryMovement={0,100}})
ground=layer.children[1]
endCombat()
startCombat()
run()
settle(0.05)
assert(equal(select(2,projected(0,onPlane(1,false))),540),'100% nearing is the screen edge')
assert(equal(select(3,projected(0,-onPlane(1,true))),0.25),'100% receding is a quarter of the size')
icon(other,BOTTOM)
settle(0.05)
assert(equal(arrowOf(ground,2).RenderTranslation.Y,select(2,projected(0,onPlane(1,false)-length/2))),
    'the bottom arrow travels to the edge')
icon(other,SWORD_ICON)
settle(0.05)
icon(other,TOP)
settle(0.05)
assert(equal(arrowOf(ground,1).RenderTranslation.Y,select(2,projected(0,-(onPlane(1,true)-length/2)))),
    'and the top arrow to a quarter of its size')
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
attach(nil,{ParryStyle=4})
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
-- Its box is the arrow's span, 428 by 1774 picture pixels, in design units 100
-- across, sized by the 100. Slate shrinks a centred box larger than the arrows'
-- panel (432 less 18 each side), so it stays well inside it.
local along,across=(687-259)*100/1774,100
assert(equal(picture.WidthOverride,along) and picture.HeightOverride==across and across<432-36,
    'the box is small enough not to be shrunk')
-- Each picture's tip sits on the box's right edge, at mid-height: normal's tip
-- is pixel column 686, rows 865 to 867; critical's column 670, rows 878 to 900.
for index,tip in ipairs({{687,866.5},{671,889.5}}) do
    local slot=pictures[index].slot
    assert(equal(slot.Position.X+tip[1]*100/1774,along) and equal(slot.Position.Y+tip[2]*100/1774,50)
        and equal(slot.Size.Y,100),'its tip on the axis, at the box\'s edge')
end
local from,to=54*1.9,54*5.5
local length=from*along/across
local first=length+0.05*(540-length)
local last=length+0.6*(540-length)
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
attach(nil,{ParryStyle=4})
assert(#arrowOf(layer.children[1],2).content.children==6,'missing pictures fall back to the Chevron')
fancyMissing=false

-- Prioritize Perfection over Buildup, by default with a Hidden, Static buildup,
-- holds the yellow arrow back; the parry window starts its whole show, red: the
-- arrow appears at its start and travels and grows from there.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(nil,{ParryPerfection=1})
endCombat()
startCombat()
run()
settle(0.05)
local perfect=arrowOf(layer.children[1],2)
icon(other,BOTTOM)
run()
settle(0.05)
assert(perfect.RenderOpacity==0,'the yellow arrow is not shown')
icon(other,BOTTOM+PARRY)
assert(math.abs(perfect.RenderOpacity-1)<1e-6 and front(perfect).G==0.2,'the parry window shows the arrow, red')
assert(equal(perfect.RenderTranslation.Y,bottomStart),'from where an arrow starts')
run()
settle(0.05)
assert(equal(perfect.RenderTranslation.Y,bottomEnd) and grownBy(perfect,bottomExtra) and front(perfect).G==0.2,
    'and travels and grows as a new attack would, still red')
icon(other,BOTTOM+PARRY)
run()
assert(equal(perfect.RenderTranslation.Y,bottomEnd),'a repeated parry window does not restart it')
icon(other,SWORD_ICON)
run()
assert(perfect.RenderOpacity==0,'the attack resolving puts it out')
settle(0.05)
-- A Faint, Partial buildup: the yellow arrow shows see-through, grows and
-- travels 30% of its way, silently; the parry window turns it red and opaque,
-- carries it on from there and plays its sound: perfection starts.
-- A Normal, Normal buildup shows and moves as without the option.
for _,case in ipairs({{visibility=1,animation=1,opacity=0.35,travel=0.3},{visibility=2,animation=2,opacity=1,travel=1}}) do
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    attach(nil,{ParryPerfection=1,ParryBuildupVisibility=case.visibility,ParryBuildupAnimation=case.animation,ParrySound=2})
    endCombat()
    startCombat()
    run()
    settle(0.05)
    local buildup=arrowOf(layer.children[1],2)
    local sounds=#posted
    icon(other,BOTTOM)
    run()
    settle(0.05)
    assert(math.abs(buildup.RenderOpacity-case.opacity)<1e-6 and front(buildup).G==0.67,'the buildup shows yellow at its visibility')
    local _,at,extra=arrowAtDefault(false,case.travel,case.travel)
    assert(equal(buildup.RenderTranslation.Y,at) and grownBy(buildup,extra),'grown and travelled its share of the way')
    assert(#posted==sounds,'the buildup plays no sound')
    icon(other,BOTTOM+PARRY)
    assert(math.abs(buildup.RenderOpacity-1)<1e-6 and front(buildup).G==0.2 and equal(buildup.RenderTranslation.Y,at),
        'the parry window turns it red and opaque where it is')
    assert(#posted==sounds+1,'the sound plays once perfection starts')
    run()
    settle(0.05)
    assert(equal(buildup.RenderTranslation.Y,bottomEnd) and grownBy(buildup,bottomExtra),'and carries it on to the end')
    icon(other,SWORD_ICON)
    settle(0.05)
end
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach()
endCombat()
startCombat()
run()
settle(0.05)

-- A critical attack: the arrow turns red.
-- Each case shows the attack, opens its parry window and resolves it.
local function criticalAttack(settings)
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    attach(nil,settings)
    local cue=layer.children[1]
    endCombat()
    startCombat()
    run()
    settle(0.05)
    icon(other,BOTTOM)
    settle(0.05)
    icon(other,BOTTOM+PARRY)
    run()
    return cue
end
local function resolveAttack()
    icon(other,SWORD_ICON)
    settle(0.05)
end
local function red(color) return color.R==1 and color.G==0.2 and color.B==0 end

local critical=criticalAttack({})
assert(red(front(arrowOf(critical,2))),'a critical attack turns the arrow red')
assert(shieldOf(critical).ColorAndOpacity.A==0,'and leaves the centre clear: the shield is the Background\'s')
resolveAttack()
-- The skull takes the centre over a critical attack.
criticalAttack({})
icon(other,SKULL_ICON)
assert(skullShown(shieldOf(layer.children[1])),'the skull takes the centre')
settle(0.05)
assert(skullShown(shieldOf(layer.children[1])),'and holds')
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
local Session=require('preymonition.omens')
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
-- grow), for sixteen drawn cues; the Fancy cue holds its two pictures per arrow.
assert(released==(10+2*4*6)*16+(10+4*2),'each detached cue releases its handles')
-- Stopping MCT detaches every cue, then puts the template to sleep.
removed=0
endCombat()
assert(removed==1 and hookCount()==0,'sleep unhooks the indicator')
endCombat()
assert(removed==1,'a second sleep has nothing left to remove')

-- Position: the cue box shares the centre of the Background's shield at its
-- default size (540 high): Below keeps that shield's bottom 10% of the height
-- above the bottom edge, Above its top 10% below the top edge.
for position,top in pairs({[0]=1080*0.9-270-216,[2]=1080*0.1+270-216}) do
    cleanups={}
    attach(nil,{GeneralPosition=position})
    assert(math.abs(layer.children[1].slot.Padding.Top-top)<1e-6,'cue position '..position)
    for index=#cleanups,1,-1 do cleanups[index]() end
end

-- Movement from Center runs to the screen edge the arrow travels
-- towards, from the cue's centre wherever Position puts it: Above centres the
-- cue 378 down, so 100% takes a bottom arrow's tip 702 down from there.
local function travel(movement,direction,index)
    cleanups={}
    attach(nil,{GeneralPosition=2,ParryMovement=movement})
    local cue=layer.children[1]
    endCombat()
    startCombat()
    run()
    settle(0.05)
    icon(other,direction)
    local arrow=arrowOf(cue,index)
    local start=arrow.RenderTranslation.Y
    run()
    settle(0.05)
    local stop=arrow.RenderTranslation.Y
    icon(other,SWORD_ICON)
    settle(0.05)
    for at=#cleanups,1,-1 do cleanups[at]() end
    return start,stop
end
local half=102.6*RATIO/2
local start,stop=travel({0,100},BOTTOM,2)
assert(equal(start,half) and equal(stop,702-half),'0% is the cue\'s centre and 100% the bottom edge')
start,stop=travel({0,100},TOP,1)
assert(equal(start,-half) and equal(stop,-(378-half)),'and the top edge for an upward arrow')
start,stop=travel({50,50},BOTTOM,2)
assert(equal(start,2*half+0.5*(702-2*half)-half) and equal(stop,start),
    '50% is halfway through the space the arrow has; equal ends keep it still')

-- With no settings the cue takes the defaults: Size 30% to 80%, Movement 40% to 60%.
cleanups={}
template.attach({hud=hud,cue=layer},{settings={},screen={width=1920,height=1080,scale=1},
    onCleanup=function(callback) cleanups[#cleanups+1]=callback end},{})
local defaultCue=layer.children[1]
endCombat()
startCombat()
run()
settle(0.05)
icon(other,BOTTOM)
local defaultScale,defaultStart=arrowAt(false,{0.3,0.8},{0.4,0.6},0,0)
assert(equal(arrowOf(defaultCue,2).RenderScale.X,defaultScale) and equal(arrowOf(defaultCue,2).RenderTranslation.Y,defaultStart),
    'the default arrow starts 3.7 units wide, its tip 40% of the space it has out')
icon(other,SWORD_ICON)
settle(0.05)
for index=#cleanups,1,-1 do cleanups[index]() end

-- At TRACE the hooks are the same: tracing adds lines, never hooks.
local Session=require('preymonition.omens')
Session.setLog(dofile('Preymonition/Scripts/vendor/mc_log.lua').wrap(function() end))
startCombat()
assert(hookCount()==1 and next(hooks)==nil,'TRACE adds no hooks')
removed=0
endCombat()
assert(removed==1 and hookCount()==0,'and unhooked with the rest')
print('PASS: the omens template hooks only in combat, follows attacks, resolves, reattach and cleanup')
