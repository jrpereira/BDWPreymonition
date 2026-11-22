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
-- How often the game clock is read, for the frame budget.
local clockReads=0
local statics={
    -- The countdown runs on game time, the clock attacks' hit windows are in.
    ['/Script/Engine.Default__GameplayStatics']=object('GameplayStatics',{GetTimeSeconds=function() clockReads=clockReads+1; return clock end,
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
-- Size is a range; a number given here is both ends. extra: more settings.
local function attach(position,size,extra)
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    local layer=object('Countdown layer')
    local settings={Position=position,Size=type(size)=='number' and {size,size} or size}
    for key,value in pairs(extra or {}) do settings[key]=value end
    template.attach({hud=hud,cue=layer},{settings=settings,screen={width=1920,height=1080,scale=1},
        onCleanup=function(callback) cleanups[#cleanups+1]=callback end},{})
    return layer
end
local function update(event) template.events.update({},event) end
local indicator=object('Indicator')
local PATH='/Game/HUD.Indicator'
local function equal(a,b) return math.abs(a-b)<1e-6 end

-- SizeBox > Overlay of the time, centred at the top, and the bar centred along
-- the bottom: a fill inside four outline lines.
local layer=attach(nil)
local box=layer.children[1]
local text,bar=box.content.children[1],box.content.children[2]
local fill=bar.content.children[1]
local function lines() local list={} for index=2,5 do list[#list+1]=bar.content.children[index].content end return list end
-- The box's render opacity shows and hides it; Opacity is the stack's, inside it.
local function shown() return box.RenderOpacity==1 end
local function label() return text.Text and text.Text.text end
assert(equal(box.MinDesiredWidth,216) and box.WidthOverride==nil,'the box is at least the bar wide and widens to the time')
assert(equal(bar.WidthOverride,216) and equal(bar.HeightOverride,1080*0.015),'the bar is 20% of the height wide')
assert(bar.slot.HorizontalAlignment==2,'the bar is centred under the time')
assert(text.slot.HorizontalAlignment==2 and text.slot.VerticalAlignment==1,'the time sits centred at the top')
assert(bar.slot.VerticalAlignment==3 and #bar.content.children==5,'the bar: a fill and four outline lines')
assert(text.Font.Size==22,'the time is 2% of the height')
assert(fill.RenderTransformPivot.X==0,'the bar runs down towards the left')
-- Middle puts the bar's bottom 55% of the height down.
assert(equal(box.slot.Padding.Top+box.HeightOverride,1080*0.55),'Middle: the bar ends 55% down')
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

-- The same direction reported again from another indicator is the same attack:
-- its count carries on, and it shows until both resolve.
local OTHER='/Game/HUD.Second'
update({kind='arrow',direction=3,path=PATH,indicator=indicator})
run(0.21)
update({kind='arrow',direction=3,path=OTHER,indicator=indicator})
assert(label()=='0.3s','a same-direction repeat from another indicator keeps the count')
update({kind='resolve',reason='sword',path=OTHER,indicator=indicator})
assert(shown() and label()=='0.3s','still counting while the first indicator has not resolved')
update({kind='critical',direction=3,path=PATH,indicator=indicator})
assert(label()=='NOW','the first indicator\'s Perfect Opportunity window says NOW')
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
assert(not shown(),'once all resolve it clears')
run(1.1)

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
    local reads=clockReads
    update({kind='arrow',direction=1,path=PATH,indicator=indicator})
    assert(asked==1,'a count asks for the next frame')
    assert(clockReads-reads==1,'an arrow reads the clock once')
    local before=gets
    reads=clockReads
    run(0.05)
    assert(gets-before==1 and asked==1,'a frame looks up the HUD once')
    assert(clockReads-reads==1,'and reads the clock once')
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

-- Below and Above mirror each other around Middle, at the default Size.
local function bottom(layer) local made=layer.children[1] return made.slot.Padding.Top+made.HeightOverride end
assert(equal(bottom(attach('below')),1080*0.775),'Below: 77.5% down')
assert(equal(bottom(attach('above')),1080*0.325),'Above: 32.5% down')
assert(equal(bottom(attach('middle',10)),1080*0.55),'10% is the default Size')
-- A saved value the picker no longer offers, such as the old numeric 2, is Middle;
-- a Size that is not a number is the default, one out of range the nearest end.
assert(equal(bottom(attach(2)),1080*0.55),'an unknown Position is Middle')
assert(equal(bottom(attach('middle','big')),1080*0.55),'an unknown Size is 10%')
assert(equal(bottom(attach('middle',{})),1080*0.55),'a Size that is not a range is 10% at both ends')

-- Size scales the bar by 1+2*(s-10)/90 and the text's line linearly to 70% of the
-- height at 100%, keeping the font's share of it; below 10% the text shrinks with
-- the bar. The box keeps its centre for the Position, then stays on screen.
local Render=require('preymonition.countdown_render')
local function parts(layer)
    local made=layer.children[1]
    return made,made.content.children[1],made.content.children[2]
end
do
    local made,time,strip=parts(attach('middle',100))
    assert(equal(strip.WidthOverride,216*3) and equal(strip.HeightOverride,1080*0.045),'100%: the bar is three times as big')
    assert(equal(made.MinDesiredWidth,216*3),'100%: the box is at least the bar wide')
    assert(equal(made.HeightOverride,1080*(0.7+0.045)),'100%: the time\'s line is 70% of the height')
    assert(time.Font.Size==math.floor(1080*0.7*0.02/0.035+0.5),'100%: the font keeps its share of the line')
    assert(time.slot.HorizontalAlignment==2 and strip.slot.HorizontalAlignment==2,'100%: time and bar stay centred')
    -- Middle's centre is 52.5% down; the box fits around it.
    assert(equal(made.slot.Padding.Top+made.HeightOverride/2,1080*0.525),'100% Middle keeps its centre')
    -- Below and Above would cross the screen edge: they stop at it.
    made=attach('below',100).children[1]
    assert(equal(made.slot.Padding.Top+made.HeightOverride,1080),'100% Below stops at the bottom edge')
    made=attach('above',100).children[1]
    assert(equal(made.slot.Padding.Top,0),'100% Above stops at the top edge')
    made,time,strip=parts(attach('middle',5))
    local small=1-2*5/90
    assert(equal(strip.WidthOverride,216*small) and equal(strip.HeightOverride,1080*0.015*small),'5%: the bar is 0.89 times as big')
    assert(equal(made.HeightOverride,1080*0.05*small),'5%: the time shrinks with the bar')
    assert(equal(made.slot.Padding.Top+made.HeightOverride/2,1080*0.525),'5% Middle keeps its centre')
    made=attach('below',55).children[1]
    assert(equal(made.slot.Padding.Top+made.HeightOverride/2,1080*0.75),'55% Below keeps its centre while it fits')
    made=attach('middle',500).children[1]
    assert(equal(made.HeightOverride,1080*0.745),'a Size above 100% is 100%')
    local layout=Render.layout(1080,'middle',10)
    assert(equal(layout.line,1080*0.035) and equal(layout.font,1080*0.02) and equal(layout.outline,1080*0.002),'10% is today\'s size')
    assert(equal(Render.layout(1080,'middle',100).outline,1080*0.006),'the outline grows with the bar')
end

-- One attack on a countdown attached with settings: its arrow at once, then after
-- 0.21 s (half the 0.42 s estimate), then its Perfect Opportunity window. Returns the
-- countdown's box and a function per moment's check, run in order.
local function attackOn(made,direction,checks)
    template.events.wake({},{name='wake'})
    update({kind='arrow',direction=direction,path=PATH,indicator=indicator})
    checks.start(made)
    run(0.21)
    checks.half(made)
    update({kind='critical',direction=direction,path=PATH,indicator=indicator})
    checks.now(made)
    update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
    template.events.sleep({},{name='sleep'})
    run(1.1)
end
local function textOf(made) return made.content.children[1].Text and made.content.children[1].Text.text end

-- Style: Bar only builds the bar and its outline alone, Label only the time alone;
-- either keeps the default box's centre for its Position and stays on screen.
do
    local made=attach('middle',10,{Style='bar'}).children[1]
    local strip=made.content.children[1]
    assert(#made.content.children==1 and strip.WidthOverride and #strip.content.children==5,'Bar only: the bar and its outline')
    assert(equal(made.HeightOverride,1080*0.015) and equal(made.slot.Padding.Top+made.HeightOverride/2,1080*0.525),
        'Bar only: the bar alone, centred where the full countdown is')
    attackOn(made,1,{start=function(box_) assert(box_.RenderOpacity==1 and equal(strip.content.children[1].RenderScale.X,1),'Bar only counts') end,
        half=function() assert(equal(strip.content.children[1].RenderScale.X,0.5),'and runs down') end,
        now=function() assert(strip.content.children[1].ColorAndOpacity.G==0.2,'and turns red, with no text to set') end})
    made=attach('middle',10,{Style='label'}).children[1]
    local time=made.content.children[1]
    assert(#made.content.children==1 and time.Font,'Label only: the time alone, no bar or outline')
    assert(equal(made.HeightOverride,1080*0.035) and equal(made.slot.Padding.Top+made.HeightOverride/2,1080*0.525),
        'Label only: the time\'s line, centred where the full countdown is')
    attackOn(made,1,{start=function() assert(textOf(made)=='0.5s','Label only counts') end,
        half=function() assert(textOf(made)=='0.3s','and runs down') end,
        now=function() assert(textOf(made)=='NOW' and time.ColorAndOpacity.SpecifiedColor.G==0.2,'and says NOW in red') end})
    made=attach('below',100,{Style='label'}).children[1]
    assert(equal(made.slot.Padding.Top+made.HeightOverride,1080),'Label only stays on screen')
    made=attach('middle',10,{Style='diagonal'}).children[1]
    assert(#made.content.children==2,'an unknown Style is Full')
end

-- Show direction in label: in the Perfect Opportunity window the time gives way to
-- the attack's direction as the Omens' arrow points on screen (the game's left and
-- right arrows show on the opposite sides), or NOW when the direction is unknown.
do
    for direction,word in ipairs({'UP','DOWN','RIGHT','LEFT'}) do
        local made=attach('middle',10,{Direction=1}).children[1]
        attackOn(made,direction,{start=function() assert(textOf(made)=='0.5s','the count still shows its time') end,
            half=function() end,
            now=function() assert(textOf(made)==word,'direction '..direction..' says '..word..', not '..tostring(textOf(made))) end})
    end
    local made=attach('middle',10,{Direction=1}).children[1]
    attackOn(made,nil,{start=function() end,half=function() end,
        now=function() assert(textOf(made)=='NOW','an unknown direction says NOW') end})
    made=attach('middle',10,{Direction=0}).children[1]
    attackOn(made,3,{start=function() end,half=function() end,
        now=function() assert(textOf(made)=='NOW','Off says NOW') end})
    made=attach('middle',10,{Direction=1,Style='label'}).children[1]
    attackOn(made,2,{start=function() end,half=function() end,
        now=function() assert(textOf(made)=='DOWN','Label only names it too') end})
end

-- Opacity: the stack's render opacity, inside the box's show and hide, fading the time,
-- the bar and the outline together: the low end as the count starts, rising as it runs
-- down, the high end in the window. Equal ends hold it.
do
    local made=attach('middle',10).children[1]
    local stack=made.content
    assert(made.slot and stack.RenderOpacity==nil,'nothing is faded before an attack')
    attackOn(made,1,{start=function() assert(made.RenderOpacity==1 and equal(stack.RenderOpacity,0.5),'50% as the count starts') end,
        half=function() assert(equal(stack.RenderOpacity,0.6),'60% halfway down the count') end,
        now=function() assert(equal(stack.RenderOpacity,0.7),'70% in the window') end})
    made=attach('middle',10,{Opacity={60,60}}).children[1]
    stack=made.content
    attackOn(made,1,{start=function() assert(equal(stack.RenderOpacity,0.6),'equal ends: 60% from the start') end,
        half=function() assert(equal(stack.RenderOpacity,0.6),'and through the count') end,
        now=function() assert(equal(stack.RenderOpacity,0.6),'and in the window') end})
    made=attach('middle',10,{Opacity={0,100}}).children[1]
    stack=made.content
    attackOn(made,1,{start=function() assert(stack.RenderOpacity==0 and made.RenderOpacity==1,'0% at the start, shown but clear') end,
        half=function() assert(equal(stack.RenderOpacity,0.5),'halfway') end,
        now=function() assert(stack.RenderOpacity==1,'full in the window') end})
end

-- Size, a range: built at its high end, the time and the bar start at the low end's
-- size and place by render transforms, the time's top and the bar's bottom where the
-- layout at that size puts them, and grow to the high end as the count reaches the
-- window. Equal ends are laid out at their size and hold still.
do
    local made=attach('middle',{10,100}).children[1]
    local time,strip=made.content.children[1],made.content.children[2]
    local low,high=Render.layout(1080,'middle',10),Render.layout(1080,'middle',100)
    assert(equal(strip.WidthOverride,216*3) and equal(made.HeightOverride,high.height),'built at the high end')
    assert(time.RenderTransformPivot.Y==0 and strip.RenderTransformPivot.Y==1,'the time scales from its top, the bar from its bottom')
    local function at(layout,label_)
        assert(equal(time.RenderScale.X,layout.line/high.line) and equal(time.RenderTranslation.Y,layout.top-high.top),label_..': the time')
        assert(equal(strip.RenderScale.X,layout.bar/high.bar)
            and equal(strip.RenderTranslation.Y,layout.top+layout.height-high.top-high.height),label_..': the bar')
    end
    attackOn(made,1,{start=function() at(low,'10% as it starts') end,
        half=function() at(Render.layout(1080,'middle',55),'55% halfway down the count') end,
        now=function() at(high,'100% in the window') end})
    assert(equal(time.RenderScale.X,1) and equal(strip.RenderTranslation.Y,0),'the high end is the built size')
    made=attach('middle',{30,30}).children[1]
    time,strip=made.content.children[1],made.content.children[2]
    assert(equal(strip.WidthOverride,216*(1+2*20/90)),'equal ends are laid out at that size')
    attackOn(made,1,{start=function() assert(equal(time.RenderScale.X,1) and equal(strip.RenderTranslation.Y,0),'and hold still') end,
        half=function() assert(equal(strip.RenderScale.X,1),'through the count') end,
        now=function() assert(equal(time.RenderTranslation.Y,0),'and in the window') end})
    made=attach('middle',{100,10}).children[1]
    assert(equal(made.content.children[2].WidthOverride,216*3),'reversed ends are put in order')
    made=attach('middle',{10,100},{Style='bar'}).children[1]
    strip=made.content.children[1]
    attackOn(made,1,{start=function() assert(equal(strip.RenderScale.X,1/3),'Bar only scales its bar') end,
        half=function() end,now=function() assert(equal(strip.RenderScale.X,1),'to the high end') end})
end
for index=#cleanups,1,-1 do cleanups[index]() end
print('PASS: Countdown counts to the Perfect Opportunity window, says NOW in red while it is open and clears with the attack, in preview too')
