package.path='ModCoreTemplates/Scripts/?.lua;'..package.path
local definitions,entries=dofile('Preymonition/tests/load_templates.lua')()
assert(#definitions==1 and entries[1].path:match('Preymonition/Scripts/mc_preymonition%.lua$'))
local template=definitions[1]
assert(template.category=='player.notifications' and template.name=='Preymonition')
assert(template.objects.hud and template.objects.cue and template.render==nil)
assert(type(template.loaded)=='function' and type(template.attach)=='function')

local category=dofile('ModCoreTemplates/Scripts/categories/player_notifications.lua')
local graph=require('mc.selectors').compile(category.objects)
local projected=require('mc.selectors').project(graph,template.objects)
assert(projected.byName.hud_root,'cue layer must pull in its HUD root dependency')
assert(projected.byName.cue.create==true)

local path='9_ModCore_Preymonition/Scripts/mc_preymonition.lua'
local model=require('mc.menu_model').build({category},{template},{path})
local menu=require('mc.menu').generate(model.registry)
local page=assert(menu.providers['ModCoreTemplates.module.9ModCorePreymonition'])
local definition
for _,candidate in pairs(menu.definitions['player.notifications']) do
    if candidate.id==template.id then definition=candidate end
end
assert(definition and definition.enabled,'template must be selectable alongside other notifications')
local rows={}
for _,row in ipairs(page.rows) do rows[row.id]=row end
local size=assert(rows[definition.settings.CueS])
-- Rows are ModCoreSettings menu data.
local labels={}
for index,choice in ipairs(size.choices) do labels[index]=choice.label end
assert(table.concat(labels,'|')=='Small|Standard|Large' and size.default==20)
print('PASS: Preymonition registers one player.notifications template with its size setting')
