-- The Countdown template: an attack starts a yellow count to its estimated
-- Perfect Opportunity window; the game's own Perfect Opportunity window turns it
-- red and says NOW while the bar runs down; a resolve or combat end clears it.
package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;'..package.path
-- Handle lookups, for the frame budget.
local gets=0
require('mc.objects').useLifetimes({weak=function(object)
    return {get=function() gets=gets+1; return setmetatable({},{__index=object,__newindex=object}) end,release=function() end}
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
    function methods:IsValid() return self.invalid~=true end
    function methods:GetWorld() return self.world or world end
    function methods:AddChildToOverlay(child)
        self.children[#self.children+1]=child
        child.slot=object(child.name..' slot')
        return child.slot
    end
    function methods:ClearChildren() self.children={} end
    function methods:SetContent(child) self.content=child end
    return setmetatable(value,{__index=function(_,key)
        if methods[key] then return methods[key] end
        local field=type(key)=='string' and key:match('^Set(.+)$')
        if field then return function(self,v) self[field]=v end end
    end})
end
local clock=0
local statics={
    -- The countdown runs on game time, the clock attacks' hit windows are in.
    ['/Script/Engine.Default__GameplayStatics']=object('GameplayStatics',{GetTimeSeconds=function() return clock end,
        GetRealTimeSeconds=function() error('the countdown runs on game time') end}),
    -- An attacker's hit window, by stub: start and end, or -1 when the game has none.
    ['/Script/DogwoodCombat.Default__CombatBlueprintFunctionLibrary']=object('CombatBlueprintFunctionLibrary',
        {GetHitWindowTime=function(_,stub,ending) return stub.window[ending and 2 or 1] end}),
    ['/Script/Engine.Default__KismetTextLibrary']=object('KismetTextLibrary',
        {Conv_StringToText=function(_,text) return {text=text} end}),
}
-- Widget classes, by path, and how often one is looked up.
local classes,classFinds={},0
-- How often an attacker's stub is looked up.
local stubFinds=0
StaticFindObject=function(path)
    if path:match('^/Script/UMG%.') then
        classFinds=classFinds+1
        classes[path]=classes[path] or object(path,{path=path})
        return classes[path]
    end
    if path:match(':Stubs%.') then stubFinds=stubFinds+1 end
    return statics[path] or {path=path}
end
-- The engine refuses a second object under one name in an outer (a crash in game): every
-- name built must be new.
local builtNames={}
local function newName(name)
    local text=name:ToString()
    assert(not builtNames[text],'widget name built twice: '..text)
    builtNames[text]=true
    return text
end
-- fontless: the text has no Font to resize.
local fontless=false
StaticConstructObject=function(class,_,name)
    local made=object(newName(name))
    if class.path=='/Script/UMG.TextBlock' and not fontless then made.Font={Size=24} end
    return made
end
FName=function(value) return {ToString=function() return value end} end
-- Frames run when the test says so.
local frames={}
EngineTickAvailable=true
ExecuteInGameThreadAfterFrames=function(_,callback) frames[#frames+1]=callback end
ExecuteWithDelay=function() error('the countdown waits on frames') end
local function run(seconds)
    clock=clock+seconds
    local pending=frames
    frames={}
    for _,callback in ipairs(pending) do callback() end
end

local template=dofile('Preymonition/Scripts/mc_countdown.lua')
assert(template.id=='Countdown' and template.category=='npc.attacks' and template.priority==12)
local hud=object('HUD',{WidgetTree=object('WidgetTree')})
local cleanups={}
local function attach(position)
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    local layer=object('Countdown layer')
    template.attach({hud=hud,cue=layer},{settings={Position=position},screen={width=1920,height=1080,scale=1},
        onCleanup=function(callback) cleanups[#cleanups+1]=callback end},{})
    return layer
end
local function update(event) template.events.update({},event) end
local indicator=object('Indicator')
local PATH='/Game/HUD.Indicator'
local function equal(a,b) return math.abs(a-b)<1e-6 end

-- SizeBox > Overlay of the time, top right, and the bar along the bottom: a
-- fill inside four outline lines.
local layer=attach(nil)
local box=layer.children[1]
local text,bar=box.content.children[1],box.content.children[2]
local fill=bar.content.children[1]
local function lines() local list={} for index=2,5 do list[#list+1]=bar.content.children[index].content end return list end
local function shown() return box.RenderOpacity==1 end
local function label() return text.Text and text.Text.text end
assert(equal(box.WidthOverride,216) and equal(bar.HeightOverride,1080*0.015),'the bar is 20% of the height wide')
assert(text.slot.HorizontalAlignment==3 and text.slot.VerticalAlignment==1,'the time sits top right')
assert(bar.slot.VerticalAlignment==3 and #bar.content.children==5,'the bar: a fill and four outline lines')
assert(text.Font.Size==22,'the time is 2% of the height')
assert(fill.RenderTransformPivot.X==0,'the bar runs down towards the left')
-- Middle puts the bar's bottom 20% of the height below the centre.
assert(equal(box.slot.Padding.Top+box.HeightOverride,1080*0.7),'Middle: the bar ends 20% below the centre')
assert(not shown(),'the countdown waits unseen')

update({kind='arrow',direction=2,path=PATH,indicator=indicator})
assert(not shown(),'requests are ignored outside combat')
template.events.wake({},{name='wake'})
-- The parry window multiplier cannot be read here: 1.4 is assumed, so the count is 0.42 s.
update({kind='arrow',direction=2,path=PATH,indicator=indicator})
assert(shown() and label()=='0.5s' and equal(fill.RenderScale.X,1),'an attack starts a full count, rounded up')
assert(text.ColorAndOpacity.SpecifiedColor.G==0.85 and fill.ColorAndOpacity.A==0.5
    and lines()[1].ColorAndOpacity.A==0.5,'the count is yellow, its bar and outline see-through')
run(0.21)
assert(label()=='0.3s' and equal(fill.RenderScale.X,0.5),'the count and the bar run down')
-- The game's arrow showing again for the same attack does not restart it.
update({kind='arrow',direction=2,path=PATH,indicator=indicator})
assert(label()=='0.3s','the same attack keeps its count')
run(0.3)
assert(label()=='0.0s' and fill.RenderScale.X==0 and #frames==0,'a count that runs out holds at 0.0')
assert(text.ColorAndOpacity.SpecifiedColor.G==0.85,'still yellow: NOW waits for the game\'s Perfect Opportunity window')
update({kind='critical',direction=2,path=PATH,indicator=indicator})
assert(label()=='NOW' and equal(fill.RenderScale.X,1),'the Perfect Opportunity window says NOW with a full bar')
assert(text.ColorAndOpacity.SpecifiedColor.G==0.2 and fill.ColorAndOpacity.G==0.2
    and lines()[4].ColorAndOpacity.G==0.2,'and turns everything red')
update({kind='critical',direction=2,path=PATH,indicator=indicator})
run(0.25)
assert(equal(fill.RenderScale.X,0.75),'the red bar runs down over a second; a repeated critical does not restart it')
run(1)
assert(fill.RenderScale.X==0 and label()=='NOW' and #frames==0,'then holds empty until the attack resolves')
update({kind='resolve',reason='sword',path='/Game/HUD.Other',indicator=indicator})
assert(shown(),'another indicator\'s resolve changes nothing')
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
assert(not shown(),'the resolve clears it')

-- A Perfect Opportunity window sooner than the estimate cuts the count short.
update({kind='arrow',direction=1,path=PATH,indicator=indicator})
run(0.1)
update({kind='critical',direction=1,path=PATH,indicator=indicator})
assert(label()=='NOW','an early Perfect Opportunity window says NOW at once')
-- A new attack starts a new count, yellow again.
update({kind='arrow',direction=3,path=PATH,indicator=indicator})
assert(label()=='0.5s' and text.ColorAndOpacity.SpecifiedColor.G==0.85,'a new attack counts again')
-- A Perfect Opportunity window whose arrow was never seen says NOW at once.
update({kind='resolve',reason='hidden',path=PATH,indicator=indicator})
update({kind='critical',direction=4,path=PATH,indicator=indicator})
assert(shown() and label()=='NOW','an unseen attack\'s Perfect Opportunity window says NOW')
-- Another world's attacks and unblockable skulls are not counted.
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
update({kind='arrow',direction=1,path='/Game/Other',indicator=object('Other',{world=elsewhere})})
update({kind='unblockable',active=true,path=PATH,indicator=indicator})
assert(not shown(),'another world\'s attack and the skull are ignored')

-- With MCT naming the attacker, the count runs to OPEN_BEFORE (0.18 s) before the
-- attack's hit window, and the red bar to the hit window's end.
local guard=object('Guard',{window={0,0}})
statics['/Game/Map.Map:Stubs.Guard']=guard
local function attack(from,to)
    guard.window={from,to}
    update({kind='arrow',direction=1,path=PATH,indicator=indicator,stub='/Game/Map.Map:Stubs.Guard'})
end
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
attack(clock+0.88,clock+1.1)
assert(label()=='0.7s' and equal(fill.RenderScale.X,1),'the count runs to 0.18 s before the hit window')
run(0.35)
assert(label()=='0.4s' and equal(fill.RenderScale.X,0.5),'and runs down by it')
run(0.25)
update({kind='critical',direction=1,path=PATH,indicator=indicator,stub='/Game/Map.Map:Stubs.Guard'})
assert(label()=='NOW' and equal(fill.RenderScale.X,1),'the Perfect Opportunity window says NOW')
run(0.25)
assert(equal(fill.RenderScale.X,0.5),'the red bar runs to the hit window\'s end, 0.5 s away')
run(0.3)
assert(fill.RenderScale.X==0 and #frames==0,'and empties there')
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
-- The stub is looked up once a combat: the next attack from it reads the kept one.
local finds=stubFinds
attack(clock+0.88,clock+1.1)
assert(label()=='0.7s' and stubFinds==finds,'a stub seen this combat is not looked up again')
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
guard.invalid=true
attack(clock+0.88,clock+1.1)
assert(label()=='0.5s' and stubFinds==finds+1,'a stub that died is looked up again: gone, the estimate')
guard.invalid=nil
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
-- A hit window the game does not have (-1), or a stub that is gone, falls back to the estimate.
attack(-1,-1)
assert(label()=='0.5s','no hit window: the estimate')
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
update({kind='arrow',direction=2,path=PATH,indicator=indicator,stub='/Game/Map.Map:Stubs.Gone'})
assert(label()=='0.5s','a stub that is gone: the estimate')
update({kind='critical',direction=2,path=PATH,indicator=indicator,stub='/Game/Map.Map:Stubs.Gone'})
run(0.5)
assert(equal(fill.RenderScale.X,0.5),'and the red bar runs over a second')
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})

-- Combat end clears it.
update({kind='arrow',direction=1,path=PATH,indicator=indicator})
template.events.sleep({},{name='sleep'})
assert(not shown(),'combat end clears the countdown')
run(0.1)

-- A live preview (ModCore Templates in the mod menu): attached with params.preview, it
-- counts without combat for preview events, the menu's widget as their indicator. With
-- no attack to time it counts 0.7 s, the npc.attacks script's gap from arrow to
-- critical, on real time (the game may be paused under the menu), stepping by engine
-- frames, which tick with the menu open; its red bar runs over 0.5 s, to the script's
-- resolve. Game events never reach it and combat end leaves it.
do
    local statics_=statics['/Script/Engine.Default__GameplayStatics']
    local realTime=100
    statics_.GetRealTimeSeconds=function() return realTime end
    local delayed={}
    ExecuteWithDelay=function(_,callback) delayed[#delayed+1]=callback end
    ExecuteInGameThread=function(callback) callback() end
    -- Real time runs; game time stands still, as while paused.
    local function tick(seconds)
        realTime=realTime+seconds
        local pending=frames
        frames={}
        for _,callback in ipairs(pending) do callback() end
    end
    local real=attach(nil).children[1]
    local previewLayer=object('Preview layer')
    template.attach({hud=hud,cue=previewLayer},{settings={},screen={width=1920,height=1080,scale=1},preview=true,
        onCleanup=function(callback) cleanups[#cleanups+1]=callback end},{})
    local own=previewLayer.children[1]
    local ownText,ownFill=own.content.children[1],own.content.children[2].content.children[1]
    local menu=object('Menu')
    local function send(kind,path,direction)
        update({kind=kind,direction=direction or 3,reason='sword',path=path,sequence=1,indicator=menu,preview=true})
    end
    assert(own.RenderOpacity==0,'the preview countdown waits unseen: it has no idle state')
    send('arrow','preview:1:1')
    assert(own.RenderOpacity==1 and ownText.Text.text=='0.7s' and real.RenderOpacity==0,
        'a preview arrow counts 0.7 s on the preview alone, without combat')
    assert(#frames==1 and #delayed==0,'a preview steps by frames, never ExecuteWithDelay')
    tick(0.35)
    assert(ownText.Text.text=='0.4s' and equal(ownFill.RenderScale.X,0.5),'on real time, while game time stands still')
    tick(0.36)
    assert(ownText.Text.text=='0.0s' and #frames==0,'it runs out as the script\'s critical comes')
    send('critical','preview:1:1')
    assert(ownText.Text.text=='NOW' and equal(ownFill.RenderScale.X,1),'the preview critical says NOW')
    tick(0.25)
    assert(equal(ownFill.RenderScale.X,0.5),'its red bar runs over 0.5 s')
    template.events.wake({},{name='wake'})
    update({kind='arrow',direction=1,path=PATH,indicator=indicator})
    assert(real.RenderOpacity==1 and ownText.Text.text=='NOW','a game event never reaches the preview')
    send('resolve','preview:1:1')
    assert(own.RenderOpacity==0 and real.RenderOpacity==1,'a preview resolve leaves the HUD\'s count')
    send('arrow','preview:2:1')
    template.events.sleep({},{name='sleep'})
    assert(real.RenderOpacity==0 and own.RenderOpacity==1,'combat end leaves the preview')
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    tick(0.1)
    assert(#previewLayer.children==0 and #frames==0,'cleanup clears it and stops its steps')
    ExecuteWithDelay=function() error('the countdown waits on frames') end
    frames={}
end

-- The estimate takes the difficulty's parry window multiplier, read from the game's
-- combat subsystem when combat starts, or when the countdown attaches in combat (the
-- template enabled or its settings applied mid-fight): 0.3 s times it.
do
    local multiplier
    local function entries(list)
        return {ForEach=function(_,visit)
            for _,pair in ipairs(list) do visit({get=function() return pair[1] end},{get=function() return pair[2] end}) end
        end}
    end
    local subsystem=object('CombatSubsystem',{ActionDifficultyLevel=1,DifficultyConfig={ActionDifficulties={ForEach=function(_,visit)
        visit({get=function() return 1 end},{get=function() return {ParryWindowMultipliers=entries({
            {{ToString=function() return 'PS5' end},99},{{ToString=function() return 'Windows' end},multiplier}})} end})
    end}}})
    statics['/Script/DogwoodCombat.CombatSubsystem']=object('CombatSubsystemClass')
    statics['/Script/Engine.Default__SubsystemBlueprintLibrary']=object('SubsystemBlueprintLibrary',
        {GetWorldSubsystem=function() return multiplier and subsystem or nil end})
    local function count(counted)
        update({kind='arrow',direction=1,path=PATH,indicator=indicator})
        local shownText=counted.content.children[1].Text.text
        update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
        return shownText
    end
    for _,case in ipairs({{1,'0.3s'},{2.5,'0.8s'}}) do
        multiplier=case[1]
        local counted=attach(nil).children[1]
        template.events.wake({},{name='wake'})
        assert(count(counted)==case[2],'at '..case[1]..' the estimate is '..case[2])
        template.events.sleep({},{name='sleep'})
    end
    template.events.wake({},{name='wake'})
    local late=attach(nil).children[1]
    assert(count(late)=='0.8s','a countdown attached in combat takes the difficulty\'s pace')
    template.events.sleep({},{name='sleep'})
    multiplier=nil
    run(0.1)
end

-- A frame looks up the HUD once and reads the clock. While the game is paused (its
-- clock standing still) nothing is drawn and the next look waits five frames; once
-- the clock moves the count runs every frame again. A HUD that is gone stops it.
do
    local asked
    local afterFrames=ExecuteInGameThreadAfterFrames
    ExecuteInGameThreadAfterFrames=function(count,callback) asked=count; frames[#frames+1]=callback end
    template.events.wake({},{name='wake'})
    local counted=attach(nil).children[1]
    local countText=counted.content.children[1]
    update({kind='arrow',direction=1,path=PATH,indicator=indicator})
    assert(asked==1,'a count asks for the next frame')
    local before=gets
    run(0.05)
    assert(gets-before==1 and asked==1,'a frame looks up the HUD once')
    local paused=countText.Text.text
    run(0)
    assert(asked==5 and countText.Text.text==paused,'paused: nothing drawn, the next look five frames on')
    run(0)
    assert(asked==5,'still paused')
    run(0.1)
    assert(asked==1 and countText.Text.text~=paused,'the clock moving runs the count every frame again')
    hud.invalid=true
    run(0.05)
    assert(#frames==0,'a HUD that is gone stops the count')
    hud.invalid=nil
    template.events.sleep({},{name='sleep'})
    ExecuteInGameThreadAfterFrames=afterFrames
    run(0.1)
end

-- A font size that cannot be set leaves the time at the default size, warned about once.
do
    local warnings={}
    local logger={enabled=function() return false end}
    for _,level in ipairs({'trace','debug','info','warn','error','critical'}) do
        logger[level]=function(...) if level=='warn' then warnings[#warnings+1]=table.concat({...}) end end
    end
    local Countdown=require('preymonition.countdown')
    Countdown.setLog(logger)
    fontless=true
    attach(nil)
    attach(nil)
    fontless=false
    assert(#warnings==1 and warnings[1]:match('^countdown font size not set; the time keeps the default size: '),
        'a font that cannot be sized warns once')
    Countdown.setLog(setmetatable({enabled=function() return false end},{__index=function() return function() end end}))
end

assert(classFinds==4,'each widget class is looked up once across attaches: SizeBox, Overlay, TextBlock and Image')

-- Below and Above follow the omens' cue area at its default size.
assert(equal(attach('below').children[1].slot.Padding.Top+box.HeightOverride,1080*0.85),'Below: 85% down')
assert(equal(attach('above').children[1].slot.Padding.Top+box.HeightOverride,1080*0.55),'Above: 55% down')
-- A saved value the picker no longer offers, such as the old numeric 2, is Middle.
assert(equal(attach(2).children[1].slot.Padding.Top+box.HeightOverride,1080*0.7),'an unknown Position is Middle')
for index=#cleanups,1,-1 do cleanups[index]() end
print('PASS: Countdown counts to the Perfect Opportunity window, says NOW in red while it is open and clears with the attack, in preview too')
