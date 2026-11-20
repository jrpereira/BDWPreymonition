package.path='ModCoreTemplates/Scripts/?.lua;ModCoreTemplates/Scripts/vendor/?.lua;'..package.path
local definitions,entries=dofile('Preymonition/tests/load_templates.lua')()
-- Four templates, all in npc.attacks: the omens, the audio cues, the screen
-- edges and the countdown. The settings page lists them in
-- registration order, the Audio Cues right after the Omens; MCT attaches them by
-- priority.
assert(#definitions==4)
local registered={}
for index,entry in ipairs(entries) do registered[index]=entry.path:match('mc_(%a+)%.lua$') end
assert(table.concat(registered,' ')=='omens audio edges countdown','registration order')
local byFile={}
for index,entry in ipairs(entries) do
    byFile[assert(entry.path:match('Preymonition/Scripts/mc_(%a+)%.lua$'),entry.path)]=definitions[index]
end
local omens,edges,countdown=assert(byFile.omens),assert(byFile.edges),assert(byFile.countdown)
local audio=assert(byFile.audio)
-- MCT names each template after its module: <module id>_<template id>.
assert(omens.id=='Preymonition_Omens' and omens.label=='Omens Overlay'
    and edges.id=='Preymonition_Edges' and edges.label=='Edges Flash')
assert(audio.id=='Preymonition_Audio' and audio.label=='Audio Cues')
assert(countdown.id=='Preymonition_Countdown' and countdown.label=='Countdown (WIP)')
assert(omens.priority==10 and edges.priority==11 and countdown.priority==12
    and audio.priority==13,'omens, edges, the countdown, then the audio cues')
local category=dofile('ModCoreTemplates/Scripts/categories/npc_attacks.lua')
local graph=require('mc.selectors').compile(category.objects)
for _,template in ipairs(definitions) do
    assert(template.category=='npc.attacks')
    -- The Audio Cues draw nothing: they take the HUD alone, no layer.
    assert(template.objects.hud and (template==audio)==(template.objects.cue==nil) and template.render==nil)
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
-- The page's live preview shows over the Omens' picture: every template takes part,
-- the Audio Cues with their sounds, none with a picture of its own.
for _,template in ipairs(definitions) do
    assert(type(template.preview)=='table',template.id..' takes part in the live preview')
    assert(template==omens or template.preview.background==nil,template.id..' leaves the picture to the Omens')
end
assert(page.preview and page.menu.preview.background:match('Preymonition/images/preview_background%.jpg$'),
    'the preview shows over the Omens\' picture')
local function definitionOf(template)
    for _,candidate in pairs(menu.definitions['npc.attacks']) do
        if candidate.id==template.id then return candidate end
    end
end
local rows={}
for _,row in ipairs(page.rows) do rows[row.id]=row end
-- The Omens Overlay and Audio Cues are on out of the box; the others start off.
for name,on in pairs({Omens=1,Audio=1,Edges=0,Countdown=0}) do
    local row=assert(rows['MCT_Preymonition_'..name..'_Enabled'],name..' Enabled row')
    assert(row.default==on,name..' Enabled defaults to '..tostring(row.default))
end
local omensDefinition,edgesDefinition=assert(definitionOf(omens)),assert(definitionOf(edges))
local countdownDefinition,audioDefinition=assert(definitionOf(countdown)),assert(definitionOf(audio))
assert(omensDefinition.enabled and edgesDefinition.enabled and countdownDefinition.enabled
    and audioDefinition.enabled,'all four templates are selectable together')

-- Every key a template reads is one MCT composes from the menu ids, with its default.
local function defaults(definition,expected)
    for key,default in pairs(expected) do
        local row=assert(rows[definition.settings[key]],'no settings row for '..key)
        assert(row.default==default,key..' defaults to '..tostring(row.default))
    end
end
defaults(audioDefinition,{SoundIncoming='rumble',SoundPerfect='ding',SoundUnblockable='growl',OptionsDirectional=1,
    OptionsPitch='-20|20',OptionsVolume=100})
-- The pitch row's condition is group-relative: it names Options' own switch.
local pitchRow=rows[audioDefinition.settings.OptionsPitch]
assert(pitchRow.visible.field=='MCT_Preymonition_Audio_OptionsDirectional'
    and pitchRow.group=='MCT_Preymonition_Audio_Options','pitch shows with Options -> Enable directional sound')
for key in pairs(omensDefinition.settings) do
    assert(not key:match('^Sound'),'the omens have no sound settings: '..key)
end
defaults(omensDefinition,{ParryStyle='chevron',ParrySize='30|80',ParryMovement='40|60',ParryOpacity='50|70',
    UnblockableSize='60|100',UnblockableStyle='fiend',ParryPosition='middle',
    ParryIncoming='normal',ParryPerfect='end'})
assert(omensDefinition.settings.ParryEdges==nil,'the omens have no edge setting')
defaults(edgesDefinition,{ActivateIncoming=1,ActivatePerfect=1,ActivateUnblockable=1,
    VisualsStyle='soft',VisualsThickness=8,VisualsIntensity=50})
defaults(countdownDefinition,{Position='middle'})

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
    [omensDefinition]={ParryStyle='off',ParryPosition='below|middle|above',
        ParryIncoming='normal|faint|off',ParryPerfect='end|start|halfway|off'},
    [countdownDefinition]={Position='below|middle|above'}}) do
    for key,list in pairs(expected) do
        local row=assert(rows[definition.settings[key]],'no settings row for '..key)
        assert(keys(row)==list,key..' keys '..keys(row))
    end
end
assert(labels(rows[omensDefinition.settings.ParryPosition])=='Below|Middle|Above')
-- Parry Style: Off, then the pictures listed from images/ (Chevron, the default, among them).
local parryStyle=rows[omensDefinition.settings.ParryStyle]
assert(#parryStyle.values==2 and parryStyle.values[2].from=='choices/parry_style.lua' and parryStyle.default=='chevron',
    'Parry Style lists the pictures after Off')
local styleRow=rows[omensDefinition.settings.UnblockableStyle]
assert(styleRow.values[1].key=='off' and styleRow.values[2].from=='choices/unblockable_style.lua'
    and styleRow.values[2].root:match('Preymonition$') and styleRow.values[3]==nil,
    'Style: Off, then the pictures listed from the module folder')
-- Activate Edges: three On/Off switches.
for _,key in ipairs({'ActivateIncoming','ActivatePerfect','ActivateUnblockable'}) do
    local row=assert(rows[edgesDefinition.settings[key]],key)
    assert(row.widget=='switch' and #row.values==2 and row.values[1].value==0 and row.values[1].label=='Off'
        and row.values[2].value==1 and row.values[2].label=='On',key..' is an On/Off switch')
end
for key,label in pairs({ActivateIncoming='Attack incoming',ActivatePerfect='Perfect Opportunity',
    ActivateUnblockable='Unblockable Attack',VisualsStyle='Style',VisualsThickness='Thickness',VisualsIntensity='Intensity'}) do
    assert(rows[edgesDefinition.settings[key]].label==label,key..' label '..tostring(rows[edgesDefinition.settings[key]].label))
end
local gradientRow=rows[edgesDefinition.settings.VisualsStyle]
assert(gradientRow.values[1].key=='bands' and gradientRow.values[1].label=='Bands'
    and gradientRow.values[2].from=='choices/edge_gradients.lua' and gradientRow.values[2].root:match('Preymonition$')
    and gradientRow.values[3]==nil,'Style: Bands, then the gradients listed from the module folder')
for key,range in pairs({VisualsThickness={2,20,1},VisualsIntensity={10,100,5}}) do
    local row=assert(rows[edgesDefinition.settings[key]],key)
    assert(row.type=='integer' and row.values.min==range[1] and row.values.max==range[2] and row.values.step==range[3]
        and row.values.suffix=='%',key..' slider')
end
-- Edges Flash: Activate Edges (Attack incoming, Perfect Opportunity, Unblockable Attack),
-- then Visuals (Style, Thickness, Intensity), in that order.
local activateGroup=rows[edgesDefinition.settings.ActivateIncoming].group
local visualsGroup=rows[edgesDefinition.settings.VisualsStyle].group
assert(activateGroup=='MCT_Preymonition_Edges_Activate' and visualsGroup=='MCT_Preymonition_Edges_Visuals',
    'groups '..tostring(activateGroup)..' '..tostring(visualsGroup))
local order={}
for _,row in ipairs(page.rows) do
    if row.group==activateGroup or row.group==visualsGroup then order[#order+1]=row.id end
end
local expectOrder={}
for index,key in ipairs({'ActivateIncoming','ActivatePerfect','ActivateUnblockable','VisualsStyle','VisualsThickness','VisualsIntensity'}) do
    expectOrder[index]=edgesDefinition.settings[key]
    assert(expectOrder[index]=='MCT_Preymonition_Edges_'..key,key..' saved as '..tostring(expectOrder[index]))
end
assert(table.concat(order,' ')==table.concat(expectOrder,' '),'Edges Flash order '..table.concat(order,' '))
for key in pairs(edgesDefinition.settings) do
    assert(not key:match('^Edge'),'no Screen Edges setting is left: '..key)
end
-- The omens have no shield settings.
assert(omensDefinition.settings.ShieldVisibility==nil and omensDefinition.settings.ShieldSize==nil,
    'the omens have no shield settings')
-- Attack Incoming and Perfect Opportunity always show; Prioritize Perfection,
-- Buildup visibility and Buildup animation are gone.
assert(omensDefinition.settings.ParryPerfection==nil,'no Prioritize Perfection setting')
assert(omensDefinition.settings.ParryBuildupVisibility==nil and omensDefinition.settings.ParryBuildupAnimation==nil,
    'no Buildup visibility or Buildup animation setting')
local incomingRow=rows[omensDefinition.settings.ParryIncoming]
local perfectRow=rows[omensDefinition.settings.ParryPerfect]
assert(omensDefinition.settings.ParryIncoming=='MCT_Preymonition_Omens_ParryIncoming'
    and omensDefinition.settings.ParryPerfect=='MCT_Preymonition_Omens_ParryPerfect','saved under the Omens')
assert(incomingRow.label=='Attack Incoming' and perfectRow.label=='Perfect Opportunity','row labels')
assert(labels(incomingRow)=='Normal|Faint|Off')
assert(labels(perfectRow)=='End|Start|Halfway|Off')
assert(incomingRow.description=='How the Yellow arrow shows before the Perfect Opportunity window: normal, faint or off.',
    'Attack Incoming description')
assert(perfectRow.description=='How the Perfect Opportunity arrow takes over: end (yellow runs its course first, red '
    ..'comes in at the end), start (yellow doesn\'t move), halfway (yellow moves 50%) or off.','Perfect Opportunity description')
for _,key in ipairs({'ParryIncoming','ParryPerfect'}) do
    local row=rows[omensDefinition.settings[key]]
    assert(not (row.conditions and row.conditions.visible) and not row.visible,key..' always shows')
end
assert(labels(rows[countdownDefinition.settings.Position])=='Below|Middle|Above')
-- Both Size rows give their own description.
for _,key in ipairs({'ParrySize','UnblockableSize'}) do
    assert(rows[omensDefinition.settings[key]].description
        =='The size when it appears, and the size it grows to.',key..' description')
end
assert(rows[omensDefinition.settings.ParryMovement].description=='Where the arrow appears and how far it travels: '
    ..'0% from the center, 100% to the screen edge.','ParryMovement description')
assert(rows[omensDefinition.settings.ParryOpacity].description
    =='The opacity when it appears, and the opacity it reaches as it travels.','ParryOpacity description')
-- Every setting explains itself.
for definition,keys in pairs({[omensDefinition]={'ParryPosition','UnblockableStyle','ParryStyle','ParrySize','ParryMovement','ParryOpacity','ParryIncoming','ParryPerfect',
    'UnblockableSize'},[audioDefinition]={'SoundIncoming','SoundPerfect','SoundUnblockable','OptionsDirectional','OptionsPitch','OptionsVolume'},
    [edgesDefinition]={'ActivateIncoming','ActivatePerfect','ActivateUnblockable','VisualsStyle','VisualsThickness','VisualsIntensity'},
    [countdownDefinition]={'Position'}}) do
    for _,key in ipairs(keys) do
        local description=rows[definition.settings[key]].description
        assert(type(description)=='string' and #description>0,key..' has a description')
    end
end
-- Attack incoming and Perfect Opportunity offer None, previewing silence, then
-- the cue sounds the menu lists from the module's sounds folder.
for _,key in ipairs({'SoundIncoming','SoundPerfect'}) do
    local parry=assert(rows[audioDefinition.settings[key]])
    assert(parry.values[1].key=='none' and parry.values[1].sound=='none'
        and parry.values[2].from=='choices/cue_sounds.lua' and parry.values[2].root:match('Preymonition$')
        and parry.values[3]==nil,key..': None, then the cue sounds listed from the module folder')
end
local skull=assert(rows[audioDefinition.settings.SoundUnblockable])
assert(skull.values[1].key=='none' and skull.values[2].from=='choices/unblockable_sounds.lua'
    and skull.values[2].root:match('Preymonition$') and skull.values[3]==nil,'None, then the listed unblockable sounds')
-- The omens' standalone settings show no heading: their rows sit under the template's toggle.
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
assert(headingOf(edgesDefinition.settings.ActivateIncoming)~='none' and headingOf(edgesDefinition.settings.VisualsStyle)~='none',
    'Activate Edges and Visuals keep their headings')
local activateMenu=groupOf(page.menu.groups,rows[edgesDefinition.settings.ActivateIncoming].group)
local visualsMenu=groupOf(page.menu.groups,rows[edgesDefinition.settings.VisualsStyle].group)
assert(activateMenu.label=='Activate Edges' and visualsMenu.label=='Visuals',
    'group labels '..tostring(activateMenu.label)..' '..tostring(visualsMenu.label))
assert(headingOf(omensDefinition.settings.ParryStyle)~='none','Parry & Block keeps its heading')
print('PASS: Preymonition registers the Omens Overlay, Audio Cues, Edges Flash and Countdown templates in npc.attacks with their settings')
