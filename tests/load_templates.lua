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
        -- Load the template as MCT does, with its folder appended to package.path.
        local definition=Defaults.apply(require('mc.bootstrap').executeTemplate(entry.path))
        definitions[#definitions+1]=Metadata.apply(definition,entry.path)
    end
    return definitions,entries
end
