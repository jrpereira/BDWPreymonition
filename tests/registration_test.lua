package.path='ModCoreTemplates/Scripts/?.lua;'..package.path
local definitions,entries=dofile('Preymonition/tests/load_templates.lua')()
assert(#definitions==1 and entries[1].path:match('Preymonition/Scripts/mc_preymonition%.lua$'))
local template=definitions[1]
assert(template.category=='player.notifications' and template.name=='Preymonition')
assert(template.objects.hud and template.objects.cue and template.render==nil)
assert(type(template.loaded)=='function' and type(template.attach)=='function')

local category=dofile('Preymonition/tests/fixtures/player_notifications.lua')
local graph=require('mc.selectors').compile(category.objects)
local projected=require('mc.selectors').project(graph,template.objects)
assert(projected.byName.hud_root,'cue layer must pull in its HUD root dependency')
assert(projected.byName.cue.create==true)

local path='_ModCore_X_Preymonition/Scripts/mc_preymonition.lua'
local model=require('mc.menu_model').build({category},{template},{path})
local menu=require('mc.menu').generate(model.registry)
local page=assert(menu.providers['ModCoreTemplates.module.Preymonition'])
local definition
for _,candidate in pairs(menu.definitions['player.notifications']) do
    if candidate.id==template.id then definition=candidate end
end
assert(definition and definition.enabled,'template must be selectable alongside other notifications')
local rows={}
for _,row in ipairs(page.rows) do rows[row.Id]=row end
local size=assert(rows[definition.settings.CueS])
assert(size.PresetLabels=='Small|Standard|Large' and tonumber(size.Default)==20)
print('PASS: Preymonition registers one player.notifications template with its size setting')
