package.path='ModCoreTemplates/Scripts/?.lua;ModCoreTemplates/Scripts/vendor/?.lua;'..package.path
local definitions,entries=dofile('Preymonition/tests/load_templates.lua')()
assert(#definitions==1 and entries[1].path:match('Preymonition/Scripts/mc_preymonition%.lua$'))
local template=definitions[1]
assert(template.category=='npc.attacks' and template.name=='Preymonition')
assert(template.objects.hud and template.objects.cue and template.render==nil)
assert(template.loaded==nil and type(template.attach)=='function')
assert(type(template.events.wake)=='function' and type(template.events.sleep)=='function',
    'combat reaches the template as its wake and sleep events')

local category=dofile('ModCoreTemplates/Scripts/categories/npc_attacks.lua')
local graph=require('mc.selectors').compile(category.objects)
local projected=require('mc.selectors').project(graph,template.objects)
assert(projected.byName.hud_root,'cue layer must pull in its HUD root dependency')
assert(projected.byName.cue.create==true)

local path='9_ModCore_Preymonition/Scripts/mc_preymonition.lua'
local model=require('mc.menu_model').build({category},{template},{path})
local menu=require('mc.menu').generate(model.registry)
local page=assert(menu.providers['ModCoreTemplates.module.9ModCorePreymonition'])
local definition
for _,candidate in pairs(menu.definitions['npc.attacks']) do
    if candidate.id==template.id then definition=candidate end
end
assert(definition and definition.enabled,'template must be selectable alongside other notifications')
local rows={}
for _,row in ipairs(page.rows) do rows[row.id]=row end
local size=assert(rows[definition.settings.ShieldSize])
-- Rows are ModCoreSettings menu data.
local labels={}
for index,choice in ipairs(size.choices) do labels[index]=choice.label end
assert(table.concat(labels,'|')=='Smaller|Small|Average|Large|Larger' and size.default==20)
-- Every key the cue reads is one MCT composes from the menu ids, with its default.
local DEFAULTS={ParrySound=0,ParryStyle=1,ParrySize=100,ParryMovement=100,ParryTrail=1,
    ParryEdges=0,UnblockableSize=100,UnblockableSound=0,ShieldSize=20,ShieldDisplay=0}
for key,default in pairs(DEFAULTS) do
    local row=assert(rows[definition.settings[key]],'no settings row for '..key)
    assert(row.default==default,key..' defaults to '..tostring(row.default))
end
-- Each sound choice previews its own event; None previews silence.
local parry=assert(rows[definition.settings.ParrySound])
assert(parry.choices[1].label=='None' and parry.choices[1].sound=='none'
    and parry.choices[2].sound:match('UI_Claws_Equip%.UI_Claws_Equip$')
    and parry.choices[3].sound:match('UI_Sword_Equip%.UI_Sword_Equip$'),'parry sounds preview')
local skull=assert(rows[definition.settings.UnblockableSound])
assert(skull.choices[2].label=='Growl' and skull.choices[3].sound:match('UI_PauseMenu_Resume'),'unblockable sounds preview')
print('PASS: Preymonition registers one npc.attacks template with its ten settings')
