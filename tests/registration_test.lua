package.path='ModCoreTemplates/Scripts/?.lua;ModCoreTemplates/Scripts/vendor/?.lua;'..package.path
local definitions,entries=dofile('Preymonition/tests/load_templates.lua')()
-- Two templates: the center cue and the screen edges, both in npc.attacks.
assert(#definitions==2 and entries[1].path:match('Preymonition/Scripts/mc_center%.lua$')
    and entries[2].path:match('Preymonition/Scripts/mc_edges%.lua$'))
local center,edges=definitions[1],definitions[2]
assert(center.id=='Center' and center.label=='Center Overlay' and edges.id=='Edges' and edges.label=='Edges Overlay')
assert(center.priority==10 and edges.priority==11,'the center cue comes before the edges')
local category=dofile('ModCoreTemplates/Scripts/categories/npc_attacks.lua')
local graph=require('mc.selectors').compile(category.objects)
for _,template in ipairs(definitions) do
    assert(template.category=='npc.attacks')
    assert(template.objects.hud and template.objects.cue and template.render==nil)
    assert(template.loaded==nil and type(template.attach)=='function')
    assert(type(template.events.wake)=='function' and type(template.events.sleep)=='function'
        and type(template.events.update)=='function',
        'combat reaches each template as wake and sleep, attacks as update')
    local projected=require('mc.selectors').project(graph,template.objects)
    assert(projected.byName.hud_root,'cue layer must pull in its HUD root dependency')
    assert(projected.byName.cue.create==true,'each template gets its own layer')
end

local paths={'9_ModCore_Preymonition/Scripts/mc_center.lua','9_ModCore_Preymonition/Scripts/mc_edges.lua'}
local model=require('mc.menu_model').build({category},definitions,paths)
local menu=require('mc.menu').generate(model.registry)
local page=assert(menu.providers['ModCoreTemplates.module.9ModCorePreymonition'])
local function definitionOf(template)
    for _,candidate in pairs(menu.definitions['npc.attacks']) do
        if candidate.id==template.id then return candidate end
    end
end
local rows={}
for _,row in ipairs(page.rows) do rows[row.id]=row end
local centerDefinition,edgesDefinition=assert(definitionOf(center)),assert(definitionOf(edges))
assert(centerDefinition.enabled and edgesDefinition.enabled,'both templates are selectable together')

-- Every key a template reads is one MCT composes from the menu ids, with its default.
local function defaults(definition,expected)
    for key,default in pairs(expected) do
        local row=assert(rows[definition.settings[key]],'no settings row for '..key)
        assert(row.default==default,key..' defaults to '..tostring(row.default))
    end
end
defaults(centerDefinition,{ParrySound=0,ParryStyle=1,ParrySize=100,ParryMovement=100,ParryTrail=1,
    UnblockableSize=100,UnblockableSound=0,GeneralScale=0,GeneralPosition=1,GeneralShield=0})
assert(centerDefinition.settings.ParryEdges==nil,'the center cue has no edge setting')
defaults(edgesDefinition,{EdgeStyle=1})

-- Rows are ModCoreSettings menu data.
local scale=assert(rows[centerDefinition.settings.GeneralScale])
assert(scale.range and scale.range.min==-50 and scale.range.max==200 and scale.default==0)
local function labels(row)
    local list={}
    for index,choice in ipairs(row.choices) do list[index]=choice.label end
    return table.concat(list,'|')
end
assert(labels(rows[centerDefinition.settings.GeneralPosition])=='Below|Middle|Above')
assert(labels(rows[edgesDefinition.settings.EdgeStyle])=='Framed|Directional')
-- Each sound choice previews its own event; None previews silence.
local parry=assert(rows[centerDefinition.settings.ParrySound])
assert(parry.choices[1].label=='None' and parry.choices[1].sound=='none'
    and parry.choices[2].label=='Chime' and parry.choices[2].sound:match('UI_AA_Cooldown_Ended%.UI_AA_Cooldown_Ended$')
    and parry.choices[3].label=='Swish' and parry.choices[3].sound:match('UI_Claws_Equip%.UI_Claws_Equip$')
    and parry.choices[4]==nil,'parry sounds preview')
local skull=assert(rows[centerDefinition.settings.UnblockableSound])
assert(skull.choices[2].label=='Growl' and skull.choices[3].sound:match('UI_PauseMenu_Resume'),'unblockable sounds preview')
-- Center's standalone settings and Screen Edges show no heading: their rows sit under the template's toggle.
local function groupOf(groups,id)
    for _,group in ipairs(groups or {}) do
        if group.id==id then return group end
        local found=groupOf(group.groups,id)
        if found then return found end
    end
end
local function headingOf(field)
    return assert(groupOf(page.menu.groups,assert(rows[field]).group),'no group for '..field).heading
end
assert(headingOf(centerDefinition.settings.GeneralScale)==false,'Shield Scale has no heading')
assert(headingOf(edgesDefinition.settings.EdgeStyle)==false,'Screen Edges has no heading')
assert(headingOf(centerDefinition.settings.ParryStyle)~=false,'Parry & Block keeps its heading')
print('PASS: Preymonition registers the Center and Edges templates in npc.attacks with their settings')
