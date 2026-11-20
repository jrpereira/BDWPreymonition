-- The Edges template: MC_NPCAttackIndicator requests light the attacked side's
-- screen edge, yellow from its parry window and red from its Perfect Opportunity
-- window, each behind an Activate Edges switch; a resolve puts it out. An
-- unblockable attack lights every edge red while it shows.
package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;'..package.path
-- Handle lookups, for the request budget.
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
    function methods:IsValid() return true end
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
-- The engine's PNG import: the gradient pictures load from the source tree's
-- images folder, each a new texture named after its file; missing makes every
-- import fail.
local missing=false
local imported={}
local rendering=object('KismetRenderingLibrary')
function rendering:ImportFileAsTexture2D(_,path)
    imported[#imported+1]=path
    if missing then return nil end
    local name=path:match('^Preymonition/images/(edge_[%w_]+)%.png$')
    return name and object('Texture '..name) or nil
end
-- Widget classes, by path, and how often one is looked up.
local classes,classFinds={},0
StaticFindObject=function(path)
    if path=='/Script/Engine.Default__KismetRenderingLibrary' then return rendering end
    if path:match('^/Script/UMG%.') then
        classFinds=classFinds+1
        classes[path]=classes[path] or object(path,{path=path})
        return classes[path]
    end
    return {path=path}
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
StaticConstructObject=function(_,_,name) return object(newName(name)) end
FName=function(value) return {ToString=function() return value end} end
-- Edges never defer work.
ExecuteWithDelay=function() error('edges defer nothing') end

local template=dofile('Preymonition/Scripts/mc_edges.lua')
assert(template.id=='Edges' and template.label=='Edges Flash' and template.category=='npc.attacks')
local hud=object('HUD',{WidgetTree=object('WidgetTree')})
local cleanups={}
-- Attaches with the settings in extra over Bands and every Activate Edges switch On.
local function attach(extra)
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    local layer=object('Edge layer')
    local settings={VisualsStyle='bands'}
    for key,value in pairs(extra or {}) do settings[key]=value end
    template.attach({hud=hud,cue=layer},{settings=settings,screen={width=1920,height=1080,scale=1},
        onCleanup=function(callback) cleanups[#cleanups+1]=callback end},{})
    return layer
end
local function update(event) template.events.update({},event) end
local indicator=object('Indicator')
local PATH='/Game/HUD.Indicator'
local function lit(layer)
    local list={}
    for index,edge in ipairs(layer.children) do list[index]=edge.RenderOpacity==1 and 'on' or 'off' end
    return table.concat(list,' ')
end
local function red(layer) return layer.children[1].children[1].content.ColorAndOpacity.G==0.06 end
local function arrow(direction,path) update({kind='arrow',direction=direction,path=path or PATH,indicator=indicator}) end
local function critical(direction,path) update({kind='critical',direction=direction,path=path or PATH,indicator=indicator}) end
local function resolve(path,reason) update({kind='resolve',reason=reason or 'sword',path=path or PATH,indicator=indicator}) end
local function unblockable(active) update({kind='unblockable',active=active,path=PATH,indicator=indicator}) end

-- Four edges of six deepening bands, unlit until an attack.
local layer=attach()
assert(#layer.children==4,'four edges')
local bottom=layer.children[2]
assert(#bottom.children==6 and bottom.children[1].HeightOverride<bottom.children[6].HeightOverride,
    'each edge stacks deepening bands')
assert(layer.children[3].children[1].WidthOverride~=nil,'side edges take a width')
-- The game's left and right show on the opposite sides: its left lights the
-- screen's right edge, its right the left edge.
assert(layer.children[3].children[1].slot.HorizontalAlignment==3,'left lights the right edge')
assert(layer.children[4].children[1].slot.HorizontalAlignment==1,'right lights the left edge')
assert(lit(layer)=='off off off off','edges wait unseen')
arrow(2)
assert(lit(layer)=='off off off off','requests are ignored outside combat')
template.events.wake({},{name='wake'})

-- Both directional switches On, the default: the attacked side lights yellow,
-- turns red in its Perfect Opportunity window and goes out as it resolves.
arrow(2)
assert(lit(layer)=='off on off off' and not red(layer),'an attack lights its side yellow')
critical(2)
assert(lit(layer)=='off on off off' and red(layer),'its Perfect Opportunity window turns it red')
resolve('/Game/HUD.Other')
assert(lit(layer)=='off on off off','another indicator\'s resolve changes nothing')
resolve()
assert(lit(layer)=='off off off off' and not red(layer),'the resolve puts it out and calms it')
arrow(3)
assert(lit(layer)=='off off on off','a left attack lights edge 3')
arrow(4)
assert(lit(layer)=='off off off on','a new attack moves it')
resolve()
critical(1)
assert(lit(layer)=='on off off off' and red(layer),'an attack first seen critical shows red')
resolve(PATH,'hidden')
assert(lit(layer)=='off off off off','a hidden indicator ends it')
-- A request looks up the HUD once, whatever it lights or tints; the edges and their
-- bands are kept while it lives.
local before=gets
arrow(1)
critical(1)
resolve()
assert(gets-before==3 and lit(layer)=='off off off off','one HUD lookup per request')
-- An indicator in another world is not this HUD's.
update({kind='arrow',direction=1,path='/Game/Other',indicator=object('Other',{world=elsewhere})})
assert(lit(layer)=='off off off off','another world\'s attack is ignored')

-- Attack incoming On, Perfect Opportunity Off: yellow from the arrow to the resolve.
layer=attach({ActivatePerfect=0})
arrow(3)
assert(lit(layer)=='off off on off' and not red(layer),'Incoming alone lights yellow')
critical(3)
assert(lit(layer)=='off off on off' and not red(layer),'and stays yellow in the Perfect Opportunity window')
resolve()
assert(lit(layer)=='off off off off','until the attack resolves')
critical(1)
assert(lit(layer)=='on off off off' and not red(layer),'an attack first seen critical lights yellow')
resolve()

-- Attack incoming Off, Perfect Opportunity On: nothing until critical, then red.
layer=attach({ActivateIncoming=0})
arrow(4)
assert(lit(layer)=='off off off off','Perfect alone ignores the parry window')
critical(4)
assert(lit(layer)=='off off off on' and red(layer),'then lights red in the Perfect Opportunity window')
resolve()
assert(lit(layer)=='off off off off' and not red(layer),'until the attack resolves')

-- Both Off: no directional lighting at all.
layer=attach({ActivateIncoming=0,ActivatePerfect=0})
arrow(1)
critical(1)
assert(lit(layer)=='off off off off','both Off light nothing for an attack')
unblockable(true)
assert(lit(layer)=='on on on on' and red(layer),'Unblockable still lights every edge')
unblockable(false)
assert(lit(layer)=='off off off off','and goes with it')
resolve()

-- Unblockable Attack: every edge red while it shows; over a directional attack,
-- which shows again once it goes.
layer=attach()
unblockable(true)
assert(lit(layer)=='on on on on' and red(layer),'an unblockable attack lights every edge red')
unblockable(true)
assert(lit(layer)=='on on on on','a repeat changes nothing')
unblockable(false)
assert(lit(layer)=='off off off off' and not red(layer),'and puts them out as it goes')
arrow(3)
unblockable(true)
assert(lit(layer)=='on on on on' and red(layer),'it wins over a yellow attack')
critical(3)
assert(lit(layer)=='on on on on' and red(layer),'the attack\'s window changes nothing while it shows')
unblockable(false)
assert(lit(layer)=='off off on off' and red(layer),'then the attack shows again, red now')
unblockable(true)
resolve()
assert(lit(layer)=='on on on on','a directional resolve leaves the unblockable lighting')
unblockable(false)
assert(lit(layer)=='off off off off','and nothing is left after it')
arrow(2)
unblockable(true)
unblockable(false)
assert(lit(layer)=='off on off off' and not red(layer),'a yellow attack shows yellow again')
resolve()
-- Unblockable Attack Off ignores it.
layer=attach({ActivateUnblockable=0})
unblockable(true)
assert(lit(layer)=='off off off off','Unblockable Off lights nothing')
arrow(1)
assert(lit(layer)=='on off off off' and not red(layer),'and leaves the directional lighting alone')
unblockable(false)
resolve()

-- Combat end puts everything out, the unblockable lighting too; cleanup removes the edges.
layer=attach()
arrow(1)
template.events.sleep({},{name='sleep'})
assert(lit(layer)=='off off off off','combat end puts the edges out')
template.events.wake({},{name='wake'})
arrow(2)
unblockable(true)
template.events.sleep({},{name='sleep'})
assert(lit(layer)=='off off off off' and not red(layer),'combat end clears an unblockable attack')
template.events.wake({},{name='wake'})
unblockable(false)
arrow(4)
assert(lit(layer)=='off off off on' and not red(layer),'the next fight starts clean')
template.events.sleep({},{name='sleep'})
for index=#cleanups,1,-1 do cleanups[index]() end
cleanups={}
assert(#layer.children==0,'cleanup clears the layer')

-- Style Bands: six per edge, the deepest Thickness deep; together they reach Intensity at the rim.
local function near(a,b) return math.abs(a-b)<1e-9 end
local function image(layer,index,band) return layer.children[index].children[band or 1].content end
do
    layer=attach()
    local alpha=image(layer,1,1).ColorAndOpacity.A
    assert(near(1-(1-alpha)^6,0.5),'default Intensity 50%: the rim is half opaque')
    assert(near(layer.children[1].children[6].HeightOverride,1080*0.08),'default Thickness 8% of the shorter side')
    assert(near(layer.children[3].children[6].WidthOverride,1080*0.08),'side edges as deep')
    layer=attach({VisualsThickness=15,VisualsIntensity=80})
    alpha=image(layer,2,3).ColorAndOpacity.A
    assert(near(1-(1-alpha)^6,0.8),'Intensity 80% at the rim')
    assert(near(layer.children[2].children[6].HeightOverride,1080*0.15)
        and near(layer.children[2].children[3].HeightOverride,1080*0.15/2),'Thickness 15%, the bands evenly spaced')
    template.events.wake({},{name='wake'})
    update({kind='critical',direction=1,path=PATH,indicator=indicator})
    local color=image(layer,4,6).ColorAndOpacity
    assert(red(layer) and color.G==0.06 and near(color.A,alpha),'critical bands turn red at the same opacity')
    update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
    assert(image(layer,4,6).ColorAndOpacity.G==0.67,'and calm back to yellow')
    template.events.sleep({},{name='sleep'})
end

-- Style, a gradient picture: one picture per edge, Thickness deep along its whole length, tinted
-- with Intensity as its opacity. Top and bottom take _v, the bottom mirrored;
-- the sides _h, the right screen edge (the game's left, index 3) mirrored.
do
    imported={}
    layer=attach({VisualsStyle='soft',VisualsThickness=10,VisualsIntensity=60})
    for index=1,4 do
        assert(#layer.children[index].children==1,'one image per edge')
    end
    local expect={
        {file='edge_soft_v',scale={X=1,Y=1},height=true,v=1,h=0},
        {file='edge_soft_v',scale={X=1,Y=-1},height=true,v=3,h=0},
        {file='edge_soft_h',scale={X=-1,Y=1},height=false,v=0,h=3},
        {file='edge_soft_h',scale={X=1,Y=1},height=false,v=0,h=1},
    }
    for index,want in ipairs(expect) do
        local box=layer.children[index].children[1]
        local picture=box.content
        assert(picture.BrushFromTexture.name=='Texture '..want.file,index..' shows '..want.file)
        assert(picture.RenderScale.X==want.scale.X and picture.RenderScale.Y==want.scale.Y,index..' flips as its side needs')
        assert(picture.RenderTransformPivot.X==0.5 and picture.RenderTransformPivot.Y==0.5,'mirrored around its centre')
        if want.height then assert(near(box.HeightOverride,108) and box.WidthOverride==nil,index..' 10% deep, full width')
        else assert(near(box.WidthOverride,108) and box.HeightOverride==nil,index..' 10% deep, full height') end
        assert(box.slot.VerticalAlignment==want.v and box.slot.HorizontalAlignment==want.h,index..' on its screen edge')
        local color=picture.ColorAndOpacity
        assert(color.G==0.67 and near(color.A,0.6),index..' yellow at Intensity 60%')
    end
    assert(#imported==2,'two pictures load')
    -- Loaded once: a later build reuses them.
    layer=attach({VisualsStyle='soft'})
    assert(#imported==2,'the pictures load once per file')
    assert(near(image(layer,1).ColorAndOpacity.A,0.5),'default Intensity 50% as the picture\'s opacity')
    template.events.wake({},{name='wake'})
    update({kind='critical',direction=3,path=PATH,indicator=indicator})
    assert(lit(layer)=='off off on off' and image(layer,3).ColorAndOpacity.G==0.06
        and near(image(layer,3).ColorAndOpacity.A,0.5),'a critical attack turns the pictures red at the same opacity')
    update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
    template.events.sleep({},{name='sleep'})
    -- Soft is the default Style.
    imported={}
    layer=attach({VisualsStyle=false})
    assert(image(layer,1).BrushFromTexture.name=='Texture edge_soft_v','Soft by default')
    -- A picture that cannot load draws bands, warned about once.
    missing=true
    local warnings={}
    local quiet={enabled=function() return false end}
    for _,name in ipairs({'trace','debug','info','error','critical'}) do quiet[name]=function() end end
    quiet.warn=function(...) warnings[#warnings+1]=table.concat({...}) end
    require('preymonition.edges').setLog(quiet)
    layer=attach({VisualsStyle='linear',VisualsIntensity=40})
    layer=attach({VisualsStyle='linear',VisualsIntensity=40})
    assert(#warnings==1 and warnings[1]:find('linear',1,true),'warned once per gradient')
    assert(#layer.children[1].children==6 and image(layer,1).BrushFromTexture==nil,'an unloadable gradient draws bands')
    assert(near(1-(1-image(layer,1).ColorAndOpacity.A)^6,0.4),'at the chosen Intensity')
    layer=attach({VisualsStyle='gone'})
    assert(#layer.children[2].children==6,'a gradient whose pictures are gone draws bands')
    assert(#warnings==2,'each gradient warns once')
    template.events.wake({},{name='wake'})
    update({kind='critical',direction=2,path=PATH,indicator=indicator})
    assert(red(layer),'the fallback turns red too')
    update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
    template.events.sleep({},{name='sleep'})
    missing=false
end

-- A live preview (ModCore Templates in the mod menu): attached with params.preview,
-- it lights without combat for preview events, the menu's widget as their indicator;
-- game events never reach it and combat end leaves it.
local function previewAttach(settings)
    local previewLayer=object('Preview layer')
    template.attach({hud=hud,cue=previewLayer},{settings=settings,screen={width=1920,height=1080,scale=1},
        preview=true,onCleanup=function(callback) cleanups[#cleanups+1]=callback end},{})
    return previewLayer
end
do
    local real=attach()
    local previewLayer=previewAttach({})
    local menu=object('Menu')
    assert(lit(previewLayer)=='off off off off','the preview edges wait unlit: they have no idle state')
    update({kind='arrow',direction=3,path='preview:1:1',sequence=1,indicator=menu,preview=true})
    assert(lit(previewLayer)=='off off on off' and lit(real)=='off off off off',
        'a preview event lights only the preview, without combat')
    update({kind='critical',direction=3,path='preview:1:1',sequence=2,indicator=menu,preview=true,silent=true})
    assert(red(previewLayer) and not red(real),'and turns only it red, silent or not')
    update({kind='unblockable',active=true,path='preview:5:1',indicator=menu,preview=true})
    assert(lit(previewLayer)=='on on on on' and lit(real)=='off off off off','a preview unblockable attack lights only the preview')
    update({kind='unblockable',active=false,path='preview:5:1',indicator=menu,preview=true})
    assert(lit(previewLayer)=='off off on off' and red(previewLayer),'and its attack shows again after it')
    template.events.wake({},{name='wake'})
    arrow(1)
    assert(lit(real)=='on off off off' and lit(previewLayer)=='off off on off','a game event never reaches the preview')
    unblockable(true)
    assert(lit(real)=='on on on on' and lit(previewLayer)=='off off on off','nor a game unblockable attack')
    unblockable(false)
    update({kind='resolve',reason='sword',path='preview:1:1',indicator=menu,preview=true})
    assert(lit(previewLayer)=='off off off off' and lit(real)=='on off off off','a preview resolve leaves the HUD\'s attack')
    update({kind='arrow',direction=4,path='preview:2:1',sequence=1,indicator=menu,preview=true})
    template.events.sleep({},{name='sleep'})
    assert(lit(real)=='off off off off' and lit(previewLayer)=='off off off on','combat end leaves the preview')
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    assert(#previewLayer.children==0,'cleanup clears the preview layer')
    -- The preview follows the page's switches: Perfect Opportunity alone, no Unblockable.
    previewLayer=previewAttach({ActivateIncoming=0,ActivateUnblockable=0})
    update({kind='arrow',direction=2,path='preview:1:1',sequence=1,indicator=menu,preview=true})
    assert(lit(previewLayer)=='off off off off','the preview skips the parry window with Attack incoming Off')
    update({kind='critical',direction=2,path='preview:1:1',sequence=2,indicator=menu,preview=true})
    assert(lit(previewLayer)=='off on off off' and red(previewLayer),'and lights red in the Perfect Opportunity window')
    update({kind='unblockable',active=true,path='preview:5:1',indicator=menu,preview=true})
    assert(lit(previewLayer)=='off on off off','Unblockable Attack Off leaves it')
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
end
assert(classFinds==3,'each widget class is looked up once across attaches: Overlay, SizeBox and Image')
print('PASS: Edges light the attacked side yellow and red, every edge for an unblockable attack, each behind its switch, in preview too')
