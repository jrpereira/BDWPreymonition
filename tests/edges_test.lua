-- The Edges template: MC_NPCAttackIndicator requests light the screen edges,
-- every edge when Framed, the attacked side's when Directional; a critical
-- attack turns them red and a resolve puts them out.
package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;'..package.path
require('mc.objects').useLifetimes({weak=function(object)
    return {get=function() return setmetatable({},{__index=object,__newindex=object}) end,release=function() end}
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
        return object(child.name..' slot')
    end
    function methods:ClearChildren() self.children={} end
    function methods:SetContent(child) self.content=child end
    return setmetatable(value,{__index=function(_,key)
        if methods[key] then return methods[key] end
        local field=type(key)=='string' and key:match('^Set(.+)$')
        if field then return function(self,v) self[field]=v end end
    end})
end
StaticFindObject=function(path) return {path=path} end
StaticConstructObject=function(_,_,name) return object(name:ToString()) end
FName=function(value) return {ToString=function() return value end} end
local delayed={}
ExecuteWithDelay=function(_,callback) delayed[#delayed+1]=callback end
ExecuteInGameThread=function(callback) callback() end
local function run()
    local batch=delayed
    delayed={}
    for _,callback in ipairs(batch) do callback() end
end

local template=dofile('Preymonition/Scripts/mc_edges.lua')
assert(template.name=='Edges' and template.category=='npc.attacks')
local hud=object('HUD',{WidgetTree=object('WidgetTree')})
local cleanups={}
local function attach(style)
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
    local layer=object('Edge layer')
    template.attach({hud=hud,cue=layer},{settings={EdgeStyle=style},screen={width=1920,height=1080,scale=1},
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
local function red(layer) return layer.children[1].children[1].content.ColorAndOpacity.G==0.2 end

-- Framed, the default: four edges of six deepening bands, unlit until an attack.
local layer=attach(nil)
assert(#layer.children==4,'four edges')
local bottom=layer.children[2]
assert(#bottom.children==6 and bottom.children[1].HeightOverride<bottom.children[6].HeightOverride,
    'each edge stacks deepening bands')
assert(layer.children[3].children[1].WidthOverride~=nil,'side edges take a width')
assert(lit(layer)=='off off off off','edges wait unseen')
update({kind='arrow',direction=2,path=PATH,indicator=indicator})
assert(lit(layer)=='off off off off','requests are ignored outside combat')
template.events.wake({},{name='wake'})
update({kind='arrow',direction=2,path=PATH,indicator=indicator})
assert(lit(layer)=='on on on on' and not red(layer),'Framed lights every edge for an attack')
update({kind='critical',direction=2,path=PATH,indicator=indicator})
assert(red(layer),'a critical attack turns them red')
update({kind='resolve',reason='dark',direction=3,path=PATH,indicator=indicator})
assert(lit(layer)=='on on on on','another arrow going dark changes nothing')
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
assert(lit(layer)=='off off off off' and not red(layer),'the resolve puts them out and calms them')
-- An indicator in another world is not this HUD's.
update({kind='arrow',direction=1,path='/Game/Other',indicator=object('Other',{world=elsewhere})})
assert(lit(layer)=='off off off off','another world\'s attack is ignored')
-- Unblockable requests are the center cue's.
update({kind='unblockable',active=true,path=PATH,indicator=indicator})
assert(lit(layer)=='off off off off')

-- Directional lights only the attacked side's edge.
layer=attach(2)
update({kind='arrow',direction=3,path=PATH,indicator=indicator})
assert(lit(layer)=='off off on off','Directional lights the left edge for a left attack')
update({kind='arrow',direction=4,path=PATH,indicator=indicator})
assert(lit(layer)=='off off off on','a new attack moves it')
update({kind='resolve',reason='dark',direction=4,path=PATH,indicator=indicator})
assert(lit(layer)=='off off off off','its arrow going dark puts it out')
update({kind='critical',direction=1,path=PATH,indicator=indicator})
assert(lit(layer)=='on off off off' and red(layer),'a critical attack not shown yet shows red')
update({kind='resolve',reason='hidden',path=PATH,indicator=indicator})
assert(lit(layer)=='off off off off','a hidden indicator ends it')

-- The early warning lights the edge before the indicator; the attack takes it
-- over, and one nothing takes over goes on its own.
update({kind='early',direction=2,unblockable=false})
assert(lit(layer)=='off on off off','the early warning lights the edge')
update({kind='arrow',direction=2,path=PATH,indicator=indicator})
run()
assert(lit(layer)=='off on off off','the attack takes it over')
update({kind='resolve',reason='sword',path=PATH,indicator=indicator})
update({kind='early',direction=1,unblockable=false})
run()
assert(lit(layer)=='off off off off','an early warning nothing takes over expires')

-- Combat end puts everything out; cleanup removes the edges.
update({kind='arrow',direction=1,path=PATH,indicator=indicator})
template.events.sleep({},{name='sleep'})
assert(lit(layer)=='off off off off','combat end puts the edges out')
for index=#cleanups,1,-1 do cleanups[index]() end
assert(#layer.children==0,'cleanup clears the layer')
print('PASS: Edges light every edge or the attacked side, turn red when critical and go with the attack')
