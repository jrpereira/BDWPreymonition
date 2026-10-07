package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;'..package.path
-- Weak handles return their object only while it is live, like the bridge's.
local released=0
require('mc.objects').useLifetimes({weak=function(object)
    return {get=function() return object end,release=function() released=released+1 end}
end})

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
    function methods:GetOuter() return self.outer end
    function methods:GetFName()
        local value=self
        return {ToString=function() return value.fname or value.name end}
    end
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
local component=object('PlayerCombat')
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
local TIME_SOUND=object('UI_HUD_TimePushWarning')
local DEATH_SOUND=object('UI_Player_Death_Stinger')
objects[EVENTS..'UI/UI_Notifications/UI_HUD_TimePushWarning.UI_HUD_TimePushWarning']=TIME_SOUND
objects[EVENTS..'UI/UI_Notifications/UI_Player_Death_Stinger.UI_Player_Death_Stinger']=DEATH_SOUND

objects['PlayerCombat']=component
objects['/Script/Engine.Default__GameplayStatics']=statics
StaticFindObject=function(path) return objects[path] or (path:match('^/Script/UMG%.') and {path=path}) end
FName=function(value) return value end
local constructed=0
StaticConstructObject=function(class,outer,name)
    assert(outer==hudTree,'cue widgets belong to the HUD widget tree')
    constructed=constructed+1
    return object(name,{class=class.path})
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
local END='/Script/DogwoodCombat.PlayerCombatComponent:OnCombatEnded'
local START='/Script/DogwoodCombat.PlayerCombatComponent:OnCombatStarted'
local function param(value) return {get=function() return value end} end
-- The centre icon is about to change; the hook only sees the sprite argument.
local function centre(target,icon) hooks[ARROW]({get=function() return target.Reticle end},param(icon)) end

hudTree=object('WidgetTree')
local hud=object('HUD',{WidgetTree=hudTree})
local layer=object('Cue layer')
local template=dofile('Preymonition/Scripts/mc_preymonition.lua')
local moduleCleanups={}
template.loaded(function(callback) moduleCleanups[#moduleCleanups+1]=callback end)
assert(hooks[ARROW] and hooks[END],'the arrow styling and combat end are watched')
assert(hooks[START],'combat start is watched')
assert(blueprintHooks==0,'no blueprint function is hooked')
local hookCount=0
for _ in pairs(hooks) do hookCount=hookCount+1 end
assert(hookCount==3,'only the three working hooks; nothing is hooked just to trace')

fire(SHOW,indicator)
assert(#delayed==0,'events are ignored until a cue is attached')

local cleanups={}
local function attach(size,visuals)
    local original={}
    local settings={CueS=size}
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

attach(20)
assert(constructed==9 and #layer.children==1,'one box with a stack of shield, overlay, flash and four arrows')
assert(flashOf(layer.children[1]).BrushFromTexture==FLASH and flashOf(layer.children[1]).RenderOpacity==0,'the flash waits unseen')
local box=layer.children[1]
assert(box.WidthOverride==216 and box.HeightOverride==216,'Standard size is 20% of the short side')
assert(box.RenderOpacity==0,'the cue starts hidden')
assert(shieldOf(box).BrushFromAtlasInterface==sprite and shieldOf(box).ColorAndOpacity.A==0,
    'the cue is created with the shield sprite, hidden')

-- The arrow is handled during the game's styling call: shown in that same
-- frame, before any deferred work runs.
fire(SHOW,indicator)
local left=arrowOf(box,3)
assert(left.RenderOpacity==1,'the arrow shows during the game call itself')
local flash=flashOf(box)
assert(flash.RenderOpacity==1 and flash.RenderScale.X==1 and math.abs(flash.RenderTranslation.X+40)<1e-6,
    'a flash shows where the arrow appears')
assert(shieldOf(box).BrushFromAtlasInterface==sprite and left.Brush==ARROW_BRUSH,
    'cue keeps its shield and copies the live arrow')
assert(arrowOf(box,1).Brush==nil,'only the shown arrow is restyled')
assert(left.ColorAndOpacity.R==0.9,'the shown arrow takes the native lit colour')
assert(left.RenderOpacity==1 and left.RenderScale.X==1.5 and math.abs(left.RenderTranslation.X+40)<1e-6,
    'a detected arrow shows at once at full opacity, 1.5 times its size, one image out')
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'active cue rests at half opacity')
assert(left.RenderOpacity==1 and math.abs(left.RenderScale.X-2)<1e-6,'the shown arrow grows to twice its size')
assert(math.abs(flash.RenderOpacity)<1e-6 and math.abs(flash.RenderScale.X-1.5)<1e-6
    and math.abs(flash.RenderTranslation.X+40)<1e-6,'the flash fades out where it was while growing')
assert(math.abs(left.RenderTranslation.X+120)<1e-6 and math.abs(left.RenderTranslation.Y-5)<1e-6,
    'the left arrow travels out to three times its image width from its rest')
assert(arrowOf(box,1).RenderOpacity==0,'other arrows stay hidden')

-- The centre icon turning to the sword resolves the attack.
centre(indicator,SWORD)
run()
assert(math.abs(box.RenderOpacity-0.5)<1e-6,'a resolved attack keeps the idle cue')
assert(left.RenderOpacity==0 and left.RenderScale.X==1.5,'a resolved attack puts the arrow out at once')

fire(END,component)
run()
settle(0.05)
assert(box.RenderOpacity==0 and left.RenderOpacity==0,'combat end fades and resets the cue')
fire(SHOW,indicator)
run()
assert(#delayed==0 and box.RenderOpacity==0,'stale updates after combat end are ignored')

-- After combat end, only a combat start lets attacks through again.
fire(START,component)
run()
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6 and left.RenderOpacity==0,'combat start shows the idle cue')
fire(SHOW,indicator)
run()
settle(0.05)
assert(math.abs(box.RenderOpacity-0.5)<1e-6 and left.RenderOpacity==1,'combat start re-enables the cue')
fire(START,component)
run()
assert(#delayed==0,'a second combat start changes nothing')

-- A settings commit reattaches the same MCT layer after its cleanup.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
assert(#layer.children==0,'cleanup removes the cue from the layer')
attach(25)
assert(#layer.children==1 and layer.children[1].WidthOverride==270,'reattach rebuilds once at the new size')
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
assert(math.abs(bottom.RenderTranslation.Y-(5+15))<1e-6,'the bottom arrow shows up half an image out')
run()
settle(0.05)
assert(math.abs(bottom.RenderOpacity-1)<1e-6,'a styled indicator arrow shows its direction')
assert(math.abs(bottom.RenderTranslation.Y-(5+60))<1e-6,'and travels to two images out')
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
local critical={ImageSize={X=40,Y=30}}
other.BottomArrow.Brush=critical
fire(ARROW,other.BottomArrow)
run()
assert(bottom.Brush==critical and bottom.ColorAndOpacity.R==1 and bottom.ColorAndOpacity.G==0.2,
    'a critical arrow turns red with the new brush at once')
assert(math.abs(bottom.RenderScale.X-2.5)<1e-6 and math.abs(bottom.RenderOpacity-1)<1e-6
    and math.abs(bottom.RenderTranslation.Y-(5+60))<1e-6,'a critical arrow jumps to 2.5 times where it travelled')
assert(#delayed==0,'a critical arrow needs no frames: it does not pulse')
-- A later styling of the same attack changes nothing.
other.BottomArrow.Brush=ARROW_BRUSH
fire(ARROW,other.BottomArrow)
run()
assert(bottom.Brush==critical and bottom.ColorAndOpacity.G==0.2,'a later styling leaves the critical arrow')
-- The centre icon turning to the sword means no attack is pending: resolved.
centre(other,SWORD)
run()
assert(bottom.RenderOpacity==0 and bottom.RenderScale.X==1.5 and math.abs(layer.children[1].RenderOpacity-0.5)<1e-6,
    'a resolved attack puts its arrow out at once and keeps the idle cue')
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

-- An unblockable attack: the centre turns to a skull, in place and still.
local cueShield=shieldOf(layer.children[1])
centre(other,SKULL)
run()
assert(cueShield.BrushFromAtlasInterface==SKULL,'an unblockable attack shows the skull')
assert(#delayed==0 and cueShield.RenderTranslation==nil and cueShield.RenderScale.X==1,
    'the skull neither travels nor pulses, at its default size')
centre(other,SWORD)
run()
assert(cueShield.BrushFromAtlasInterface==sprite,'the shield returns once it passes')
settle(0.05)
centre(other,SKULL)
run()
fire(END,component)
run()
assert(cueShield.BrushFromAtlasInterface==sprite,'combat end returns the shield')
settle(0.05)
fire(START,component)
run()
settle(0.05)

-- The game gives a hidden indicator the same updates; only the visible one counts.
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
-- Its own indicator hidden, as when an attack is parried, the arrow goes.
other.visible=false
fire(ARROW,other.BottomArrow)
assert(bottom.RenderOpacity==0,'an arrow styled on its hidden source indicator puts it out')
other.visible=true
other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
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
fire(SHOW,indicator)
run()
hud.invalid=true
local before=cue.RenderOpacity
settle(0.05)
assert(cue.RenderOpacity==before,'a cue whose HUD is gone is never written')
hud.invalid=nil

-- The Visuals settings: shield shown, arrows twice the size moving half as far,
-- no glow, the time warning for arrows, and a larger skull with the stinger.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
assert(#posted==0,'no sound plays without one chosen')
attach(20,{BackgroundShield=1,ArrowsMove=50,ArrowsSize=200,ArrowsGlow=0,ArrowsSound=2,
    UnblockableSize=150,UnblockableSound=3})
local tuned=layer.children[1]
assert(shieldOf(tuned).ColorAndOpacity.A==0.2,'the background shield can be shown')
fire(START,component)
run()
settle(0.05)
other.BottomArrow.ColorAndOpacity=color(0.9)
fire(ARROW,other.BottomArrow)
local tunedBottom=arrowOf(tuned,2)
assert(math.abs(tunedBottom.RenderScale.X-3)<1e-6 and math.abs(tunedBottom.RenderTranslation.Y-(5+7.5))<1e-6,
    'arrow size and movement scale the arrow where it appears')
assert(#posted==1 and posted[1].event==TIME_SOUND and posted[1].location.Z==3,
    'the chosen arrow sound plays at the player when the arrow appears')
settle(0.05)
assert(math.abs(tunedBottom.RenderScale.X-4)<1e-6 and math.abs(tunedBottom.RenderTranslation.Y-(5+30))<1e-6,
    'and where it ends')
assert(flashOf(tuned).RenderOpacity==0,'with the glow off nothing flashes')
centre(other,SKULL)
assert(shieldOf(tuned).RenderScale.X==1.5 and #posted==2 and posted[2].event==DEATH_SOUND,
    'the unblockable skull takes its size and plays its sound')
centre(other,SWORD)
assert(shieldOf(tuned).RenderScale.X==1 and shieldOf(tuned).ColorAndOpacity.A==0.2,
    'the shield returns at its size and setting')
other.BottomArrow.ColorAndOpacity={R=0.17,G=0.02,B=0.02,A=0.8}
settle(0.05)

-- Preview shows the cue without an attack and keeps it through combat end.
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
template.preview=true
attach(20)
local preview=layer.children[1]
settle(0.05)
assert(math.abs(preview.RenderOpacity-0.5)<1e-6,'preview shows the cue on attach')
assert(math.abs(arrowOf(preview,1).RenderOpacity-1)<1e-6,'preview lights the top arrow')
assert(shieldOf(preview).BrushFromAtlasInterface==sprite and shieldOf(preview).ColorAndOpacity.A==0,
    'a new cue has the shield hidden')
fire(END,component)
run()
settle(0.05)
assert(math.abs(preview.RenderOpacity-0.5)<1e-6,'preview stays visible after combat end')
template.preview=false

for index=#cleanups,1,-1 do cleanups[index]() end
assert(scans==0,'nothing scans for objects')
assert(delays==0,'with the engine tick hooked nothing waits on ExecuteWithDelay')
assert(released==11*4,'each detached cue releases its eleven handles')
assert(moduleCleanups[1]() and removed==3,'session cleanup unregisters every hook')
assert(next(hooks)==nil,'no hook remains after cleanup')

-- At TRACE the hooks are the same: tracing adds lines, never hooks.
local Session=require('preymonition.session')
Session.setLog(dofile('Preymonition/Scripts/vendor/mc_log.lua').wrap(function() end))
moduleCleanups={}
template.loaded(function(callback) moduleCleanups[#moduleCleanups+1]=callback end)
hookCount=0
for _ in pairs(hooks) do hookCount=hookCount+1 end
assert(hookCount==3,'TRACE adds no hooks')
removed=0
assert(moduleCleanups[1]() and removed==3 and next(hooks)==nil,'and unhooked with the rest')
local fire_ok=pcall(fire,SHOW,indicator)
assert(not fire_ok,'no hook remains registered')
print('PASS: Preymonition session follows attacks, resolves, combat end, reattach and cleanup')
