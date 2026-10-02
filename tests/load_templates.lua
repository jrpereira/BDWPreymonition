local Defaults=require('mc.template_defaults')
local Metadata=require('mc.module_metadata')

return function()
    local entries={}
    require('mc')._setTemplateRegistrar(function(path)
        entries[#entries+1]={path=path};return true
    end)
    dofile('Preymonition/Scripts/main.lua')
    local definitions={}
    for _,entry in ipairs(entries) do
        local definition=Defaults.apply(assert(loadfile(entry.path))())
        definitions[#definitions+1]=Metadata.apply(definition,entry.path)
    end
    return definitions,entries
end
