package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;'..package.path
-- The acceptance aid's DETECT calls, by kind; taken() returns them and starts over.
local detects={}
package.loaded['preymonition.acceptance']={
    detect=function(kind,path) if path then detects[#detects+1]=kind end end,
    report=function() end,start=function() end,enabled=function() return true end,
}
local function taken()
    local list=table.concat(detects,' ')
    detects={}
    return list
end
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
local SWORD=object('T_Combat_Icon_Sword')
local RED_SHIELD=object('T_Combat_Icon_Shield')
local SKULL=object('T_Combat_Icon_SkullRed')
objects[FRAMES..'T_Combat_Icon_SkullRed.T_Combat_Icon_SkullRed']=SKULL
-- The game's attack flash texture.
local FLASH=object('T_Mask_AttackIndicator_Flash')
objects['/Game/_Dawnwalker/UI/_Unified/Combat/Textures/T_Mask_AttackIndicator_Flash.T_Mask_AttackIndicator_Flash']=FLASH
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
-- The indicator blueprint's designed arrows, whose artwork the cue takes when it attaches.
local DESIGNED='/Game/_Dawnwalker/UI/_Unified/Combat/WBP_CombatTargetIndicator.WBP_CombatTargetIndicator_C:WidgetTree.'
for _,key in ipairs(ARROWS) do
    objects[DESIGNED..key]=object('Designed'..key,{Brush=ARROW_BRUSH,
        RenderTransform={Translation={X=0,Y=5},Scale={X=1,Y=1}}})
end
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

local hooks,removed={},0
-- This UE4SS cannot hook blueprint functions; only native ones are tried.
local blueprintHooks=0
-- A hooked call runs the before callback, the game's own work, then the after one.
local after={}
RegisterHook=function(path,callback,post)
    if path:match('^/Game/') then blueprintHooks=blueprintHooks+1; error('ProcessInternal: 0x0') end
    after[path]=post
    hooks[path]=function(...)
        callback(...)
        if post then post(...) end
    end
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
local ARROW='/Script/UMG.Image:SetBrushFromAtlasInterface'
local SHOW={}
-- SHOW styles the indicator's lit arrow, as the game blueprint does for an attack.
local function fire(path,target)
    if path==SHOW then
        local lit,best=nil,0
        for _,key in ipairs(ARROWS) do
            local strength=target[key].ColorAndOpacity.R
            if strength>best then lit,best=target[key],strength end
        end
        path,target=ARROW,lit
    end
    hooks[path]({get=function() return target end})
end
local function param(value) return {get=function() return value end} end
-- The centre icon is about to change; the hook only sees the sprite argument.
local function centre(target,icon) hooks[ARROW]({get=function() return target.Reticle end},param(icon)) end

hudTree=object('WidgetTree')
local hud=object('HUD',{WidgetTree=hudTree})
local layer=object('Cue layer')
local template=dofile('Preymonition/Scripts/mc_center.lua')
assert(next(hooks)==nil,'nothing is hooked outside combat')
-- MCT owns combat: it reaches the template as its wake and sleep events, and
-- MCT's attack indicator source, started once the template is awake, delivers
-- MC_NPCAttackIndicator as its update event from inside the game's call.
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
startCombat()
assert(hooks[ARROW],'combat hooks the arrow styling')
assert(blueprintHooks==0,'no blueprint function is hooked')
local hookCount=0
for _ in pairs(hooks) do hookCount=hookCount+1 end
assert(hookCount==2,'the styling call and the early warning; nothing is hooked just to trace')

fire(SHOW,indicator)
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
-- SizeBox > Overlay of the shield image and the arrows overlay, which holds
-- the flash behind the four arrows.
local function shieldOf(cue) return cue.content.children[1] end
local function flashOf(cue) return cue.content.children[2].children[1] end
local function arrowOf(cue,index) return cue.content.children[2].children[index+1] end

attach(0)
assert(constructed==9 and #layer.children==1,'one box with a stack of shield, overlay, flash and four arrows')
assert(flashOf(layer.children[1]).BrushFromTexture==FLASH and flashOf(layer.children[1]).RenderOpacity==0,'the flash waits unseen')
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
-- The arrow is handled during the game's styling call: shown in that same
-- frame, before any deferred work runs.
budget.onset={cost(function() fire(SHOW,indicator) end)}
local left=arrowOf(box,3)
assert(left.RenderOpacity==1,'the arrow shows during the game call itself')
local flash=flashOf(box)
-- Movement is measured in units of 5% of the shorter screen side: 54 at 1080.
assert(flash.RenderOpacity==1 and flash.RenderScale.X==1 and math.abs(flash.RenderTranslation.X+54)<1e-6,
    'a flash shows where the arrow appears')
assert(shieldOf(box).BrushFromAtlasInterface==sprite and left.Brush==ARROW_BRUSH and arrowOf(box,1).Brush==ARROW_BRUSH,
    'cue keeps its shield; its arrows have the designed artwork from attach')
assert(left.ColorAndOpacity.R==1 and left.ColorAndOpacity.G==0.67,'the shown arrow is in the lit colour')
assert(left.RenderOpacity==1 and left.RenderScale.X==1.5 and math.abs(left.RenderTranslation.X+54)<1e-6,
    'a detected arrow shows at once at full opacity, 1.5 times its size, one unit out')
budget.frame={cost(function() clock=clock+0.05; run() end)}
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'active cue rests at half opacity')
assert(left.RenderOpacity==1 and math.abs(left.RenderScale.X-2.5)<1e-6,'the shown arrow grows to its critical size, 2.5 times')
assert(math.abs(flash.RenderOpacity)<1e-6 and math.abs(flash.RenderScale.X-1.5)<1e-6
    and math.abs(flash.RenderTranslation.X+54)<1e-6,'the flash fades out where it was while growing')
assert(math.abs(left.RenderTranslation.X+162)<1e-6 and math.abs(left.RenderTranslation.Y-5)<1e-6,
    'the left arrow travels out to three units from its rest')
assert(arrowOf(box,1).RenderOpacity==0,'other arrows stay hidden')

-- The centre icon turning to the sword resolves the attack.
budget.resolve={cost(function() centre(indicator,SWORD) end)}
-- Native work per event stays within budget: methods, of which setters, and
-- object lookups. The frame counts no clock lookup: the clock is kept.
local function within(name,methods,setters,finds)
    local spent=budget[name]
    assert(spent[1]<=methods and spent[2]<=setters and spent[3]<=finds,
        name..' costs '..table.concat(spent,'/')..', over '..methods..'/'..setters..'/'..finds)
end
within('onset',60,14,0)
within('frame',22,6,0)
within('resolve',42,6,0)
run()
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'a resolved attack keeps the idle cue')
assert(left.RenderOpacity==0 and left.RenderScale.X==1.5,'a resolved attack puts the arrow out at once')

endCombat()
run()
settle(0.05)
assert(box.RenderOpacity==0 and left.RenderOpacity==0,'combat end fades and resets the cue')
assert(hooks[ARROW]==nil and #delayed==0,'combat end unhooks the arrow styling')

-- After combat end, only a combat start lets attacks through again.
startCombat()
run()
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6 and left.RenderOpacity==0,'combat start shows the idle cue')
fire(SHOW,indicator)
run()
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6 and left.RenderOpacity==1,'combat start re-enables the cue')
local hooked=hooks[ARROW]
startCombat()
run()
assert(#delayed==0 and hooks[ARROW]==hooked,'a second combat start changes nothing')
-- Combat ending or starting mid-animation never strands the animation.
centre(indicator,SWORD)
settle(0.05)
fire(SHOW,indicator)
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

-- Only indicator arrows count: other atlas images and arrows elsewhere are ignored.
local other=newIndicator('WBP_CombatTargetIndicator_C_2','BottomArrow')
fire(ARROW,object('Portrait',{}))
run()
local stray=object('Menu.TopArrow',{fname='TopArrow',outer=object('Menu.WidgetTree',{outer=object('Menu')})})
objects[stray.name]=stray
fire(ARROW,stray)
run()
settle(0.05)
local bottom=arrowOf(layer.children[1],2)
assert(bottom.RenderOpacity==0,'only indicator arrows move the cue')
fire(SHOW,other)
assert(math.abs(bottom.RenderTranslation.Y-(5+27))<1e-6,'the bottom arrow shows up half a unit out')
run()
settle(0.05)
assert(math.abs(bottom.RenderOpacity-1)<1e-6,'a styled indicator arrow shows its direction')
assert(math.abs(bottom.RenderTranslation.Y-(5+81))<1e-6,'and travels half as far, to a unit and a half')
local hidden=newIndicator('WBP_CombatTargetIndicator_C_3','RightArrow')
hidden.RightArrow.visible=false
fire(SHOW,hidden)
run()
settle(0.05)
assert(arrowOf(layer.children[1],4).RenderOpacity==0
    and math.abs(bottom.RenderOpacity-1)<1e-6,'an arrow styled while hidden is not an attack')


-- The game styles an attack's arrow twice; the second time it turned red:
-- at once 2.5 times its size in the game's red with the new brush, where it
-- travelled, held until resolved.
centre(other,RED_SHIELD)
run()
assert(math.abs(bottom.RenderOpacity-1)<1e-6,'the red centre icon at an attack changes nothing yet')
taken()
local critical={ImageSize={X=40,Y=30}}
other.BottomArrow.Brush=critical
fire(ARROW,other.BottomArrow)
run()
assert(bottom.Brush==ARROW_BRUSH and bottom.ColorAndOpacity.R==1 and bottom.ColorAndOpacity.G==0.2,
    'a critical arrow turns red at once, keeping the designed artwork')
assert(math.abs(bottom.RenderScale.X-2.5)<1e-6 and math.abs(bottom.RenderOpacity-1)<1e-6
    and math.abs(bottom.RenderTranslation.Y-(5+81))<1e-6,'a critical arrow jumps to 2.5 times where it travelled')
assert(#delayed==0,'a critical arrow needs no frames: it does not pulse')
-- A later styling of the same attack changes nothing.
other.BottomArrow.Brush=ARROW_BRUSH
fire(ARROW,other.BottomArrow)
run()
assert(bottom.ColorAndOpacity.G==0.2,'a later styling leaves the critical arrow')
-- The centre icon turning to the sword means no attack is pending: resolved.
centre(other,SWORD)
run()
assert(bottom.RenderOpacity==0 and bottom.RenderScale.X==1.5 and math.abs(layer.children[1].RenderOpacity-0.5)<1e-6,
    'a resolved attack puts its arrow out at once and keeps the idle cue')
assert(taken()=='critical resolve','the acceptance aid sees the critical and the resolve, once each')
settle(0.05)
-- Turning a showing arrow dark also resolves it.
other.BottomArrow.ColorAndOpacity=color(0.9)
fire(ARROW,other.BottomArrow)
run()
settle(0.05)
assert(math.abs(bottom.RenderOpacity-1)<1e-6,'lit again, it is a new attack')
other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
fire(ARROW,other.BottomArrow)
run()
assert(bottom.RenderOpacity==0,'a dark arrow puts it out at once')
assert(taken()=='arrow','a new attack is detected as an arrow; a dark arrow is no game icon change')
settle(0.05)

-- One frame can resolve an attack and start the next: handled in the game's
-- order, the new arrow survives the sword that resolved the old one.
other.BottomArrow.ColorAndOpacity=color(0.9)
fire(ARROW,other.BottomArrow)
centre(other,RED_SHIELD)
centre(other,SWORD)
other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
other.LeftArrow.ColorAndOpacity=color(0.9)
fire(ARROW,other.LeftArrow)
centre(other,RED_SHIELD)
local otherLeft=arrowOf(layer.children[1],3)
assert(otherLeft.RenderOpacity==1 and bottom.RenderOpacity==0,'the next attack shows in the same frame')
settle(0.05)
assert(otherLeft.RenderOpacity==1,'and is still shown afterwards')
centre(other,SWORD)
other.LeftArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
settle(0.05)

-- An arrow coloured only after its brush is still dark during the call; it is
-- checked again next frame and shown then.
fire(ARROW,other.BottomArrow)
assert(bottom.RenderOpacity==0 and #delayed==1,'an arrow not lit yet is checked next frame')
other.BottomArrow.ColorAndOpacity=color(0.9)
run()
assert(bottom.RenderOpacity==1,'lit by then, it shows')
settle(0.05)
centre(other,SWORD)
other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
settle(0.05)

-- An unblockable attack: the centre turns to a skull in place, growing from its
-- size to twice that over 0.2s, then holding.
local cueShield=shieldOf(layer.children[1])
taken()
centre(other,SKULL)
assert(cueShield.BrushFromAtlasInterface==SKULL and math.abs(cueShield.RenderScale.X-1)<1e-6,
    'an unblockable attack shows the skull at its size')
clock=clock+0.1
run()
assert(math.abs(cueShield.RenderScale.X-1.5)<1e-6 and cueShield.RenderTranslation==nil,'it grows in place')
settle(0.05)
assert(math.abs(cueShield.RenderScale.X-2)<1e-6 and #delayed==0,'to twice its size, then holds')
centre(other,SWORD)
run()
assert(math.abs(cueShield.RenderScale.X-1)<1e-6,'the shield returns at its size')
assert(cueShield.BrushFromAtlasInterface==sprite,'the shield returns once it passes')
assert(taken()=='skull resolve','the acceptance aid sees the skull and its sword')
settle(0.05)
centre(other,SKULL)
run()
endCombat()
run()
assert(cueShield.BrushFromAtlasInterface==sprite,'combat end returns the shield')
settle(0.05)
startCombat()
run()
settle(0.05)

-- The game gives a hidden indicator the same updates; only the visible one counts.
taken()
local twin=newIndicator('WBP_CombatTargetIndicator_C_4','BottomArrow')
twin.visible=false
other.BottomArrow.ColorAndOpacity=color(0.9)
fire(ARROW,other.BottomArrow)
fire(ARROW,twin.BottomArrow)
centre(twin,SKULL)
assert(cueShield.BrushFromAtlasInterface==sprite,'a hidden indicator shows no skull')
fire(ARROW,other.BottomArrow)
fire(ARROW,twin.BottomArrow)
assert(bottom.ColorAndOpacity.G==0.2 and math.abs(bottom.RenderScale.X-2.5)<1e-6,
    'the visible indicator still turns critical')
centre(twin,SWORD)
assert(bottom.RenderOpacity==1,'a hidden indicator resolves nothing it did not show')
assert(taken()=='arrow critical','the acceptance aid reports the visible indicator only')
-- Its own indicator hidden, as when an attack is parried, the arrow goes.
other.visible=false
fire(ARROW,other.BottomArrow)
assert(bottom.RenderOpacity==0,'an arrow styled on its hidden source indicator puts it out')
other.visible=true
other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
settle(0.05)
-- Nor does a hidden twin take away the skull its visible indicator shows.
centre(other,SKULL)
assert(cueShield.BrushFromAtlasInterface==SKULL)
centre(twin,SWORD)
centre(twin,RED_SHIELD)
assert(cueShield.BrushFromAtlasInterface==SKULL,'a hidden twin leaves the skull')
centre(other,SWORD)
assert(cueShield.BrushFromAtlasInterface==sprite,'its own indicator takes it away')

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
fire(SHOW,indicator)
run()
hud.invalid=true
local before=cue.RenderOpacity
settle(0.05)
assert(cue.RenderOpacity==before,'a cue whose HUD is gone is never written')
hud.invalid=nil

-- The cue settings: shield shown, arrows twice the size moving half as far,
-- no glow, the time warning for arrows, and a larger skull with the stinger.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
assert(#posted==0,'no sound plays without one chosen')
attach(0,{GeneralShield=1,ParryMovement=50,ParrySize=200,ParryTrail=0,ParrySound=2,
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
other.BottomArrow.ColorAndOpacity=color(0.9)
fire(ARROW,other.BottomArrow)
local tunedBottom=arrowOf(tuned,2)
assert(math.abs(tunedBottom.RenderScale.X-3)<1e-6 and math.abs(tunedBottom.RenderTranslation.Y-(5+13.5))<1e-6,
    'arrow size and movement scale the arrow where it appears')
assert(#posted==1 and posted[1].event==SWISH_SOUND and posted[1].location.Z==9,
    'the chosen arrow sound plays at the attacker when the arrow appears')
-- An indicator whose queue names no attacker plays at the player.
other.AttackQueue=nil
settle(0.05)
assert(math.abs(tunedBottom.RenderScale.X-5)<1e-6 and math.abs(tunedBottom.RenderTranslation.Y-(5+40.5))<1e-6,
    'and where it ends')
assert(flashOf(tuned).RenderOpacity==0,'with the glow off nothing flashes')
centre(other,SKULL)
assert(shieldOf(tuned).RenderScale.X==1.5 and #posted==2 and posted[2].event==BOOM_SOUND
    and posted[2].location.Z==3,'the unblockable skull takes its size and plays its sound')
centre(other,SWORD)
assert(shieldOf(tuned).RenderScale.X==1 and shieldOf(tuned).ColorAndOpacity.A==0.2,
    'the shield returns at its size and setting')
other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
settle(0.05)

-- With the overlay style off, an attack still plays its sound but shows no arrow or flash.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(0,{ParryStyle=0,ParrySound=2})
local hiddenArrows=layer.children[1]
endCombat()
startCombat()
run()
settle(0.05)
local before=#posted
other.BottomArrow.ColorAndOpacity=color(0.9)
fire(ARROW,other.BottomArrow)
settle(0.05)
assert(arrowOf(hiddenArrows,2).RenderOpacity==0 and flashOf(hiddenArrows).RenderOpacity==0,
    'the overlay style off shows no arrow or flash')
assert(#posted==before+1,'and the parry sound still plays')
other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
settle(0.05)

-- The Glow style moves the game's flash in place of the arrow; the Fade trail
-- adds two fainter arrows behind it.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
attach(0,{ParryStyle=2,ParryTrail=2})
local looks=layer.children[1]
assert(#layer.children==1,'the center cue builds no screen edges')
local function trailOf(cue,index,ghost) return cue.content.children[2].children[5+(index-1)*2+ghost] end
endCombat()
startCombat()
run()
settle(0.05)
other.BottomArrow.ColorAndOpacity=color(0.9)
fire(ARROW,other.BottomArrow)
local glowArrow,near,far=arrowOf(looks,2),trailOf(looks,2,1),trailOf(looks,2,2)
assert(glowArrow.BrushFromTexture==FLASH and near.BrushFromTexture==FLASH,'the Glow style draws the flash')
assert(flashOf(looks).RenderOpacity==0,'the Fade trail shows no appearing flash')
-- Midway through the travel, one frame later.
clock=clock+0.1
run()
assert(glowArrow.RenderOpacity==1 and near.RenderOpacity==0.5 and far.RenderOpacity==0.25,
    'the trail keeps half and a quarter of the arrow\'s opacity')
assert(near.RenderTranslation.Y<glowArrow.RenderTranslation.Y and far.RenderTranslation.Y<near.RenderTranslation.Y,
    'and follows behind it')
settle(0.05)
assert(math.abs(far.RenderTranslation.Y-glowArrow.RenderTranslation.Y)<1e-6,'catching up once the arrow stops')
other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
fire(ARROW,other.BottomArrow)
settle(0.05)
assert(far.RenderOpacity==0,'the trail goes with the attack')

-- A critical attack: the arrow turns red, and the shield
-- follows its setting. Each case styles the attack's arrow twice, as the game
-- does, and resolves it.
local function criticalAttack(settings)
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    attach(0,settings)
    local cue=layer.children[1]
    endCombat()
    startCombat()
    run()
    settle(0.05)
    other.BottomArrow.ColorAndOpacity=color(0.9)
    fire(ARROW,other.BottomArrow)
    settle(0.05)
    local before={color=shieldOf(cue).ColorAndOpacity,scale=shieldOf(cue).RenderScale}
    fire(ARROW,other.BottomArrow)
    run()
    return cue,before
end
local function resolveAttack()
    other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
    fire(ARROW,other.BottomArrow)
    settle(0.05)
end
local function red(color) return color.R==1 and color.G==0.2 and color.B==0 end

-- Opportunity: hidden until critical, then pops in red and grows to twice its size.
local dynamic,before=criticalAttack({GeneralShield=3})
assert(before.color.A==0,'an Opportunity shield waits unseen')
assert(red(shieldOf(dynamic).ColorAndOpacity) and shieldOf(dynamic).ColorAndOpacity.A==1
    and math.abs(shieldOf(dynamic).RenderScale.X-1)<1e-6,'an Opportunity shield pops in red at its size')
assert(red(arrowOf(dynamic,2).ColorAndOpacity),'the arrow turns red too')
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
centre(other,SKULL)
assert(shieldOf(hidden).BrushFromAtlasInterface==SKULL and shieldOf(hidden).ColorAndOpacity.A==1,
    'the skull takes the centre')
settle(0.05)
assert(shieldOf(hidden).ColorAndOpacity.A==1,'and the critical shield never covers it')
centre(other,SWORD)
resolveAttack()

-- Animations take 200 ms times the parry window multiplier read when combat
-- starts: 280 ms at 1.4, which is also assumed when it cannot be read.
for _,multiplier in ipairs({1.4,false}) do
    parryMultiplier=multiplier or nil
    local timed=criticalAttack({})
    resolveAttack()
    other.BottomArrow.ColorAndOpacity=color(0.9)
    fire(ARROW,other.BottomArrow)
    local arrow=arrowOf(timed,2)
    local half=0.14
    clock=clock+half
    run()
    assert(math.abs(arrow.RenderTranslation.Y-(5+54))<1e-6,'halfway through its travel')
    clock=clock+half
    run()
    assert(math.abs(arrow.RenderTranslation.Y-(5+81))<1e-6,'and done at its duration')
    resolveAttack()
end
parryMultiplier=1

-- The game's early warning, for some attacks before the arrow lights: the cue
-- shows the attack then, with its sound at the attacker; the arrow takes it over
-- without a second show or sound. One nothing takes over expires.
local EARLY='/Script/Dawnwalker.DawnwalkerPlayerCharacter:ShowHelperAttackIndicator'
assert(hooks[EARLY],'combat hooks the early warning')
local function warn(direction,unblockable)
    hooks[EARLY](param(player),param({Direction=direction,bIsUnblockable=unblockable,Instigator=combat}))
end
local early=criticalAttack({ParrySound=2,UnblockableSound=2})
resolveAttack()
local before=#posted
warn(4,false)
local earlyBottom=arrowOf(early,2)
assert(earlyBottom.RenderOpacity==1 and arrowOf(early,1).RenderOpacity==0,'the game\'s 4 is the bottom arrow, shown at once')
assert(#posted==before+1 and posted[#posted].location.Z==9,'its sound plays at the attacker')
other.BottomArrow.ColorAndOpacity=color(0.9)
fire(ARROW,other.BottomArrow)
assert(#posted==before+1 and earlyBottom.RenderOpacity==1,'the lit arrow takes it over without a second sound')
fire(ARROW,other.BottomArrow)
assert(red(earlyBottom.ColorAndOpacity),'and turns critical on its second styling')
resolveAttack()
assert(earlyBottom.RenderOpacity==0,'and resolves as usual')
warn(1,false)
local earlyRight=arrowOf(early,4)
assert(earlyRight.RenderOpacity==1,'the game\'s 1 is the right arrow')
settle(0.05)
assert(earlyRight.RenderOpacity==0,'an early show nothing takes over expires')
-- Unblockable: the skull shows early and its sound plays once.
before=#posted
warn(0,true)
assert(shieldOf(early).BrushFromAtlasInterface==SKULL and #posted==before+1,'an early unblockable shows the skull')
centre(other,SKULL)
assert(#posted==before+1,'the skull icon takes it over without a second sound')
centre(other,SWORD)
settle(0.05)
assert(shieldOf(early).BrushFromAtlasInterface~=SKULL,'and it passes as usual')
warn(0,true)
settle(0.05)
assert(shieldOf(early).BrushFromAtlasInterface~=SKULL,'an early skull nothing takes over expires')

-- A lasting fault inside the game's call is logged once per kind; the repeats
-- are counted when combat ends.
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
local broken={get=function() error('unreadable') end}
for _=1,3 do hooks[ARROW](broken) end
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
assert(delays==4,'with the engine tick hooked only early warnings wait on ExecuteWithDelay, to expire')
-- Eleven handles per cue (thirteen cues), plus eight trailing arrows.
assert(released==11*13+8,'each detached cue releases its handles')
-- Stopping MCT detaches every cue, then puts the template to sleep.
removed=0
endCombat()
assert(removed==2 and next(hooks)==nil,'sleep unregisters both hooks')
endCombat()
assert(removed==2,'a second sleep has nothing left to remove')

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
-- A cue attached before the indicator blueprint loads takes its artwork when combat starts.
local designedTop=objects[DESIGNED..'TopArrow']
objects[DESIGNED..'TopArrow']=nil
cleanups={}
attach(0)
assert(arrowOf(layer.children[1],1).Brush==nil,'no artwork before the blueprint loads')
objects[DESIGNED..'TopArrow']=designedTop
startCombat()
assert(arrowOf(layer.children[1],1).Brush==ARROW_BRUSH,'combat start takes the artwork')
endCombat()
for index=#cleanups,1,-1 do cleanups[index]() end

-- At TRACE the hooks are the same: tracing adds lines, never hooks.
local Session=require('preymonition.session')
Session.setLog(dofile('Preymonition/Scripts/vendor/mc_log.lua').wrap(function() end))
startCombat()
hookCount=0
for _ in pairs(hooks) do hookCount=hookCount+1 end
assert(hookCount==2,'TRACE adds no hooks')
removed=0
endCombat()
assert(removed==2 and next(hooks)==nil,'and unhooked with the rest')
local fire_ok=pcall(fire,SHOW,indicator)
assert(not fire_ok,'no hook remains registered')
print('PASS: Preymonition session hooks only in combat, follows attacks, resolves, reattach and cleanup')
