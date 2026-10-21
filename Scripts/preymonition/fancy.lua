-- The Fancy arrow: two pictures from the mod's images folder, a yellow one and
-- a red one for critical attacks, each an arrow pointing right on a transparent
-- background. The game loads them as textures when the cue attaches.
local M={}

M.FILES={normal='fancy_normal.png',critical='fancy_critical.png'}
-- The pictures' size in pixels, and the columns their arrow spans (alpha above
-- 8, both pictures): the rest is transparent margin. The arrow box is that span,
-- the full height; its tip is the right edge.
local ART={width=887,height=1774,left=259,right=687}
M.SIZE={X=ART.right-ART.left,Y=ART.height}

-- The mod folder, from where this file was loaded: <mod>/Scripts/preymonition/fancy.lua.
local function folder()
    local source=debug.getinfo(1,'S').source
    local path=source:match('^@(.+)$') or source
    return path:match('^(.*)[/\\][Ss]cripts[/\\]preymonition[/\\][^/\\]+$')
end

-- Loads both pictures as textures through the engine, context being any live
-- object in the player's world. Returns normal, critical and the folder, or
-- nil and why. A relative folder is tried as is and under ue4ss/, the engine
-- reading relative paths from the game's binaries folder.
function M.load(context)
    local root=folder()
    if not root then return nil,'mod folder unknown' end
    local library=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
    if not (library and library:IsValid()) then return nil,'KismetRenderingLibrary unavailable' end
    local relative=not (root:match('^%a:') or root:match('^[/\\]'))
    local candidates={root}
    if relative then candidates[2]='ue4ss/'..root end
    for _,base in ipairs(candidates) do
        local textures={}
        for key,name in pairs(M.FILES) do
            local ok,texture=pcall(function() return library:ImportFileAsTexture2D(context,base..'/images/'..name) end)
            if ok and texture and texture:IsValid() then textures[key]=texture end
        end
        if textures.normal and textures.critical then return textures.normal,textures.critical,base end
    end
    return nil,'images not loaded from '..table.concat(candidates,' or ')
end

-- The turn that points the right-pointing picture in a screen direction.
function M.angle(direction)
    return math.deg(math.atan(direction.Y,direction.X))%360
end

-- Builds one Fancy arrow from construct(classPath,name): a SizeBox the arrow's
-- span, holding a canvas with both pictures placed so the span fills the box;
-- the red one starts clear. Returns the box and its pictures as {image,role}.
function M.build(construct,name,normal,critical)
    local box=construct('/Script/UMG.SizeBox',name)
    local canvas=construct('/Script/UMG.CanvasPanel',name..'Canvas')
    box:SetContent(canvas)
    box:SetWidthOverride(M.SIZE.X)
    box:SetHeightOverride(M.SIZE.Y)
    box:SetRenderTransformPivot({X=0.5,Y=0.5})
    local images={}
    for _,entry in ipairs({{normal,'normal'},{critical,'critical'}}) do
        local image=construct('/Script/UMG.Image',name..entry[2])
        image:SetBrushFromTexture(entry[1],false)
        local slot=canvas:AddChildToCanvas(image)
        slot:SetAlignment({X=0,Y=0})
        slot:SetPosition({X=-ART.left,Y=0})
        slot:SetSize({X=ART.width,Y=ART.height})
        images[#images+1]={image,entry[2]}
    end
    return box,images
end

-- The colour a picture takes: the yellow one shows unless the arrow is
-- critical, the red one only then. Pictures keep their own colours.
function M.color(role,critical)
    local shown=(role=='critical')==critical
    return {R=1,G=1,B=1,A=shown and 1 or 0}
end

return M
