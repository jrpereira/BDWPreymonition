package.path='ModCoreTemplates/Scripts/?.lua;ModCoreTemplates/Scripts/vendor/?.lua;'..package.path
local definitions,entries=dofile('Preymonition/tests/load_templates.lua')()
-- Four templates, all in npc.attacks: the background, the omens, the screen
-- edges and the countdown. Registration order does not matter: MCT orders
-- templates by priority.
assert(#definitions==4)
local byFile={}
for index,entry in ipairs(entries) do
    byFile[assert(entry.path:match('Preymonition/Scripts/mc_(%a+)%.lua$'),entry.path)]=definitions[index]
end
local omens,edges,countdown=assert(byFile.omens),assert(byFile.edges),assert(byFile.countdown)
local background=assert(byFile.background)
assert(omens.id=='Omens' and omens.label=='Omens Overlay' and edges.id=='Edges' and edges.label=='Edges Overlay')
assert(countdown.id=='Countdown' and countdown.label=='Countdown Overlay')
assert(background.id=='Background' and background.label=='Background Overlay')
-- The background first, so its layer joins the HUD under the omens'.
assert(background.priority==9 and omens.priority==10 and edges.priority==11 and countdown.priority==12,
    'background, omens, edges, then the countdown')
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

local paths={}
for index,entry in ipairs(entries) do
    paths[index]='9_ModCore_Preymonition/Scripts/'..entry.path:match('(mc_%a+%.lua)$')
end
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
local omensDefinition,edgesDefinition=assert(definitionOf(omens)),assert(definitionOf(edges))
local countdownDefinition=assert(definitionOf(countdown))
local backgroundDefinition=assert(definitionOf(background))
assert(omensDefinition.enabled and edgesDefinition.enabled and countdownDefinition.enabled
    and backgroundDefinition.enabled,'all four templates are selectable together')

-- Every key a template reads is one MCT composes from the menu ids, with its default.
local function defaults(definition,expected)
    for key,default in pairs(expected) do
        local row=assert(rows[definition.settings[key]],'no settings row for '..key)
        assert(row.default==default,key..' defaults to '..tostring(row.default))
    end
end
defaults(omensDefinition,{ParrySound=1,ParryStyle=2,ParrySize='30|80',ParryMovement='40|60',
    UnblockableSize='60|100',UnblockableSound=1,GeneralPosition=1,ParryPerfection=0,
    ParryBuildupVisibility=0,ParryBuildupAnimation=0})
assert(omensDefinition.settings.ParryEdges==nil,'the omens have no edge setting')
defaults(edgesDefinition,{EdgeStyle=1})
defaults(countdownDefinition,{Position=1})
defaults(backgroundDefinition,{Position=1,Visibility=2,Size=50})

-- Rows are ModCoreSettings menu data.
local function labels(row)
    local list={}
    for index,choice in ipairs(row.values) do list[index]=choice.label end
    return table.concat(list,'|')
end
assert(labels(rows[omensDefinition.settings.GeneralPosition])=='Below|Middle|Above')
assert(labels(rows[edgesDefinition.settings.EdgeStyle])=='Framed|Directional')
-- The shield is the Background template's: the omens have no shield settings.
assert(omensDefinition.settings.ShieldVisibility==nil and omensDefinition.settings.ShieldSize==nil,
    'the omens have no shield settings')
assert(labels(rows[backgroundDefinition.settings.Visibility])=='In Combat|Defending|Critical')
assert(labels(rows[backgroundDefinition.settings.Position])=='Below|Middle|Above')
local size=assert(rows[backgroundDefinition.settings.Size])
assert(size.type=='integer' and size.values.min==5 and size.values.max==100 and size.default==50)
-- The buildup settings show only while Perfection is prioritized.
local perfection=rows[omensDefinition.settings.ParryPerfection]
assert(perfection.label=='Prioritize Perfection over Buildup' and labels(perfection)=='Off|On')
assert(labels(rows[omensDefinition.settings.ParryBuildupVisibility])=='Hidden|Faint|Normal')
assert(labels(rows[omensDefinition.settings.ParryBuildupAnimation])=='Static|Partial|Normal')
for _,key in ipairs({'ParryBuildupVisibility','ParryBuildupAnimation'}) do
    local row=rows[omensDefinition.settings[key]]
    local visible=assert(row.conditions and row.conditions.visible or row.visible,key..' has a visibility condition')
    assert(visible.field==omensDefinition.settings.ParryPerfection and visible.values[1]==1,key..' shows only with Perfection on')
end
assert(labels(rows[countdownDefinition.settings.Position])=='Below|Middle|Above')
-- Both Size rows give their own description.
for _,key in ipairs({'ParrySize','UnblockableSize'}) do
    assert(rows[omensDefinition.settings[key]].description
        =='Define the size of the indicator when it shows up, and the size it grows to.',key..' description')
end
assert(rows[omensDefinition.settings.ParryMovement].description=='Define where the indicator shows up, and how far it '
    ..'travels: at 0% its back edge is on the center, at 100% its tip reaches the screen edge.','ParryMovement description')
-- Every setting explains itself.
for definition,keys in pairs({[omensDefinition]={'GeneralPosition','ParryStyle','ParrySize','ParryMovement','ParrySound','ParryPerfection','ParryBuildupVisibility','ParryBuildupAnimation',
    'UnblockableSize','UnblockableSound'},[edgesDefinition]={'EdgeStyle'},
    [countdownDefinition]={'Position'},[backgroundDefinition]={'Position','Visibility','Size'}}) do
    for _,key in ipairs(keys) do
        local description=rows[definition.settings[key]].description
        assert(type(description)=='string' and #description>0,key..' has a description')
    end
end
-- Each sound choice previews its own event; None previews silence.
local parry=assert(rows[omensDefinition.settings.ParrySound])
assert(parry.values[1].label=='None' and parry.values[1].sound=='none'
    and parry.values[2].label=='Chime' and parry.values[2].sound:match('UI_AA_Cooldown_Ended%.UI_AA_Cooldown_Ended$')
    and parry.values[3].label=='Swish' and parry.values[3].sound:match('UI_Claws_Equip%.UI_Claws_Equip$')
    and parry.values[4]==nil,'parry sounds preview')
local skull=assert(rows[omensDefinition.settings.UnblockableSound])
assert(skull.values[2].label=='Growl' and skull.values[3].sound:match('UI_PauseMenu_Resume'),'unblockable sounds preview')
-- The omens' standalone settings and Screen Edges show no heading: their rows sit under the template's toggle.
local function groupOf(groups,id)
    for _,group in ipairs(groups or {}) do
        if group.id==id then return group end
        local found=groupOf(group.groups,id)
        if found then return found end
    end
end
local function headingOf(field)
    return assert(groupOf(page.menu.groups,assert(rows[field]).group),'no group for '..field).style
end
assert(headingOf(omensDefinition.settings.GeneralPosition)=='none','Position has no heading')
assert(headingOf(omensDefinition.settings.UnblockableSize)~='none','Unblockable keeps its heading')
assert(headingOf(edgesDefinition.settings.EdgeStyle)=='none','Screen Edges has no heading')
assert(headingOf(omensDefinition.settings.ParryStyle)~='none','Parry & Block keeps its heading')
print('PASS: Preymonition registers the Background, Omens, Edges and Countdown templates in npc.attacks with their settings')
