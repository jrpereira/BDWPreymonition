package.path='ModCoreTemplates/Scripts/?.lua;ModCoreTemplates/Scripts/vendor/?.lua;'..package.path
local definitions,entries=dofile('Preymonition/tests/load_templates.lua')()
-- Five templates, all in npc.attacks: the omens, the sound cues, the screen
-- edges, the countdown and the background. The settings page lists them in
-- registration order, the Sound Cues right after the Omens; MCT attaches them by
-- priority.
assert(#definitions==5)
local registered={}
for index,entry in ipairs(entries) do registered[index]=entry.path:match('mc_(%a+)%.lua$') end
assert(table.concat(registered,' ')=='omens sounds edges countdown background','registration order')
local byFile={}
for index,entry in ipairs(entries) do
    byFile[assert(entry.path:match('Preymonition/Scripts/mc_(%a+)%.lua$'),entry.path)]=definitions[index]
end
local omens,edges,countdown=assert(byFile.omens),assert(byFile.edges),assert(byFile.countdown)
local background,sounds=assert(byFile.background),assert(byFile.sounds)
-- MCT names each template after its module: <module id>_<template id>.
assert(omens.id=='Preymonition_Omens' and omens.label=='Omens'
    and edges.id=='Preymonition_Edges' and edges.label=='Edges')
assert(sounds.id=='Preymonition_Sounds' and sounds.label=='Sound Cues')
assert(countdown.id=='Preymonition_Countdown' and countdown.label=='Countdown (WIP)')
assert(background.id=='Preymonition_Background' and background.label=='Background')
-- The background first, so its layer joins the HUD under the omens'.
assert(background.priority==9 and omens.priority==10 and edges.priority==11 and countdown.priority==12
    and sounds.priority==13,'background, omens, edges, the countdown, then the sounds')
local category=dofile('ModCoreTemplates/Scripts/categories/npc_attacks.lua')
local graph=require('mc.selectors').compile(category.objects)
for _,template in ipairs(definitions) do
    assert(template.category=='npc.attacks')
    -- The Sound Cues draw nothing: they take the HUD alone, no layer.
    assert(template.objects.hud and (template==sounds)==(template.objects.cue==nil) and template.render==nil)
    assert(template.loaded==nil and type(template.attach)=='function')
    assert(type(template.events.wake)=='function' and type(template.events.sleep)=='function'
        and type(template.events.update)=='function',
        'combat reaches each template as wake and sleep, attacks as update')
    local projected=require('mc.selectors').project(graph,template.objects)
    if template.objects.cue then
        assert(projected.byName.hud_root,'cue layer must pull in its HUD root dependency')
        assert(projected.byName.cue.create==true,'each template gets its own layer')
    else
        assert(projected.byName.hud and not projected.byName.cue,'the HUD alone, no layer')
    end
end

local paths={}
for index,entry in ipairs(entries) do
    paths[index]='9_ModCore_Preymonition/Scripts/'..entry.path:match('(mc_%a+%.lua)$')
end
local model=require('mc.menu_model').build({category},definitions,paths)
local menu=require('mc.menu').generate(model.registry)
local page=assert(menu.providers['ModCoreTemplates.module.9ModCorePreymonition'])
-- The page's live preview shows over the Omens' picture: the Sound Cues declare a
-- preview for their sounds, with no picture of their own.
assert(page.preview and page.menu.preview.background:match('Preymonition/images/preview_unblockable%.jpg$'),
    'the preview shows over the Omens\' picture')
local function definitionOf(template)
    for _,candidate in pairs(menu.definitions['npc.attacks']) do
        if candidate.id==template.id then return candidate end
    end
end
local rows={}
for _,row in ipairs(page.rows) do rows[row.id]=row end
local omensDefinition,edgesDefinition=assert(definitionOf(omens)),assert(definitionOf(edges))
local countdownDefinition,soundsDefinition=assert(definitionOf(countdown)),assert(definitionOf(sounds))
local backgroundDefinition=assert(definitionOf(background))
assert(omensDefinition.enabled and edgesDefinition.enabled and countdownDefinition.enabled
    and backgroundDefinition.enabled and soundsDefinition.enabled,'all five templates are selectable together')

-- Every key a template reads is one MCT composes from the menu ids, with its default.
local function defaults(definition,expected)
    for key,default in pairs(expected) do
        local row=assert(rows[definition.settings[key]],'no settings row for '..key)
        assert(row.default==default,key..' defaults to '..tostring(row.default))
    end
end
defaults(soundsDefinition,{SoundIncoming='rumble',SoundPerfect='ding',SoundUnblockable='growl',SoundDirectional=1,
    SoundPitch='-20|20',SoundVolume=100})
for key in pairs(omensDefinition.settings) do
    assert(not key:match('^Sound'),'the omens have no sound settings: '..key)
end
defaults(omensDefinition,{ParryStyle='chevron',ParrySize='30|80',ParryMovement='40|60',
    UnblockableSize='60|100',UnblockableStyle='fiend',ParryPosition='middle',
    ParryBuildupVisibility='normal',ParryBuildupAnimation='normal'})
assert(omensDefinition.settings.ParryEdges==nil,'the omens have no edge setting')
defaults(edgesDefinition,{EdgeStyle='framed'})
defaults(countdownDefinition,{Position='middle'})
defaults(backgroundDefinition,{Position='middle',Visibility='defending',Size=50})

-- Rows are ModCoreSettings menu data.
local function labels(row)
    local list={}
    for index,choice in ipairs(row.values) do list[index]=choice.label end
    return table.concat(list,'|')
end
-- The pickers save their choice by key.
local function keys(row)
    local list={}
    for index,choice in ipairs(row.values) do list[index]=choice.key end
    return table.concat(list,'|')
end
for definition,expected in pairs({
    [omensDefinition]={ParryStyle='off|solid|chevron|perspective|fancy',ParryPosition='below|middle|above',
        ParryBuildupVisibility='hidden|faint|normal',ParryBuildupAnimation='static|partial|normal'},
    [edgesDefinition]={EdgeStyle='framed|directional'},
    [countdownDefinition]={Position='below|middle|above'},
    [backgroundDefinition]={Position='below|middle|above',Visibility='in_combat|defending|critical'}}) do
    for key,list in pairs(expected) do
        local row=assert(rows[definition.settings[key]],'no settings row for '..key)
        assert(keys(row)==list,key..' keys '..keys(row))
    end
end
assert(labels(rows[omensDefinition.settings.ParryStyle])=='Off|Solid|Chevron|Perspective|Fancy')
assert(labels(rows[omensDefinition.settings.ParryPosition])=='Below|Middle|Above')
local styleRow=rows[omensDefinition.settings.UnblockableStyle]
assert(styleRow.values[1].key=='off' and styleRow.values[2].from=='choices/unblockable_style.lua'
    and styleRow.values[2].root:match('Preymonition$') and styleRow.values[3]==nil,
    'Style: Off, then the pictures listed from the module folder')
assert(labels(rows[edgesDefinition.settings.EdgeStyle])=='Framed|Directional')
-- The shield is the Background template's: the omens have no shield settings.
assert(omensDefinition.settings.ShieldVisibility==nil and omensDefinition.settings.ShieldSize==nil,
    'the omens have no shield settings')
assert(labels(rows[backgroundDefinition.settings.Visibility])=='In Combat|Defending|Critical')
assert(labels(rows[backgroundDefinition.settings.Position])=='Below|Middle|Above')
local size=assert(rows[backgroundDefinition.settings.Size])
assert(size.type=='integer' and size.values.min==5 and size.values.max==100 and size.default==50)
-- The buildup settings always show; Prioritize Perfection is gone.
assert(omensDefinition.settings.ParryPerfection==nil,'no Prioritize Perfection setting')
assert(labels(rows[omensDefinition.settings.ParryBuildupVisibility])=='Hidden|Faint|Normal')
assert(labels(rows[omensDefinition.settings.ParryBuildupAnimation])=='Static|Partial|Normal')
for _,key in ipairs({'ParryBuildupVisibility','ParryBuildupAnimation'}) do
    local row=rows[omensDefinition.settings[key]]
    assert(not (row.conditions and row.conditions.visible) and not row.visible,key..' always shows')
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
for definition,keys in pairs({[omensDefinition]={'ParryPosition','UnblockableStyle','ParryStyle','ParrySize','ParryMovement','ParryBuildupVisibility','ParryBuildupAnimation',
    'UnblockableSize'},[soundsDefinition]={'SoundIncoming','SoundPerfect','SoundUnblockable','SoundDirectional','SoundPitch','SoundVolume'},
    [edgesDefinition]={'EdgeStyle'},
    [countdownDefinition]={'Position'},[backgroundDefinition]={'Position','Visibility','Size'}}) do
    for _,key in ipairs(keys) do
        local description=rows[definition.settings[key]].description
        assert(type(description)=='string' and #description>0,key..' has a description')
    end
end
-- Attack incoming and Perfect opportunity offer None, previewing silence, then
-- the cue sounds the menu lists from the module's sounds folder.
for _,key in ipairs({'SoundIncoming','SoundPerfect'}) do
    local parry=assert(rows[soundsDefinition.settings[key]])
    assert(parry.values[1].key=='none' and parry.values[1].sound=='none'
        and parry.values[2].from=='choices/cue_sounds.lua' and parry.values[2].root:match('Preymonition$')
        and parry.values[3]==nil,key..': None, then the cue sounds listed from the module folder')
end
local skull=assert(rows[soundsDefinition.settings.SoundUnblockable])
assert(skull.values[1].key=='none' and skull.values[2].from=='choices/unblockable_sounds.lua'
    and skull.values[2].root:match('Preymonition$') and skull.values[3]==nil,'None, then the listed unblockable sounds')
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
assert(headingOf(omensDefinition.settings.ParryPosition)~='none','Position sits under Parry & Block')
assert(headingOf(omensDefinition.settings.UnblockableSize)~='none','Unblockable keeps its heading')
assert(headingOf(edgesDefinition.settings.EdgeStyle)=='none','Screen Edges has no heading')
assert(headingOf(omensDefinition.settings.ParryStyle)~='none','Parry & Block keeps its heading')
print('PASS: Preymonition registers the Omens, Sound Cues, Edges, Countdown and Background templates in npc.attacks with their settings')
