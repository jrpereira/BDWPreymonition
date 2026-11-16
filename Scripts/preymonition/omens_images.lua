-- Pictures from the mod's images folder, loaded as textures through the engine.
local M={}

-- The mod folder, from where this file was loaded: <mod>/Scripts/preymonition/omens_images.lua.
local function folder()
    local source=debug.getinfo(1,'S').source
    local path=source:match('^@(.+)$') or source
    return path:match('^(.*)[/\\][Ss]cripts[/\\]preymonition[/\\][^/\\]+$')
end

-- Loads the named pictures, {key=file name}, context being any live object in
-- the player's world. Returns {key=texture} with every one loaded and the
-- folder, or nil and why. A relative folder is tried as is and under ue4ss/,
-- the engine reading relative paths from the game's binaries folder.
function M.load(context,files)
    local root=folder()
    if not root then return nil,'mod folder unknown' end
    local library=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
    if not (library and library:IsValid()) then return nil,'KismetRenderingLibrary unavailable' end
    local relative=not (root:match('^%a:') or root:match('^[/\\]'))
    local candidates={root}
    if relative then candidates[2]='ue4ss/'..root end
    for _,base in ipairs(candidates) do
        local textures,complete={},true
        for key,name in pairs(files) do
            local ok,texture=pcall(function() return library:ImportFileAsTexture2D(context,base..'/images/'..name) end)
            if ok and texture and texture:IsValid() then textures[key]=texture else complete=false end
        end
        if complete then return textures,base end
    end
    return nil,'images not loaded from '..table.concat(candidates,' or ')
end

return M
