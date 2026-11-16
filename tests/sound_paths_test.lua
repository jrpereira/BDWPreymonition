-- Preymonition's sound paths name its own folder, so the Sound Bridge finds them from
-- ModCore Templates' Lua state, where the template code runs.
local path='Preymonition/Scripts/preymonition/sound.lua'
local function load(source)
    local getinfo=debug.getinfo
    debug.getinfo=function(level,what)
        local info=getinfo(level+1,what)
        if info and info.source and info.source:find("preymonition[/\\\\]sound%.lua$") and source then info.source=source end
        return info
    end
    local ok,Sound=pcall(dofile,path)
    debug.getinfo=getinfo
    assert(ok,Sound)
    return Sound
end
local absolute=load('@C:\\Games\\Dawnwalker\\ue4ss\\Mods\\9_ModCore_Preymonition\\Scripts\\preymonition\\sound.lua')
assert(absolute.ROOT=='C:/Games/Dawnwalker/ue4ss/Mods/9_ModCore_Preymonition','an absolute source is used as it is')
assert(absolute.arrow('Ding')=='C:/Games/Dawnwalker/ue4ss/Mods/9_ModCore_Preymonition/sounds/cue_ding.wav'
    and absolute.unblockable('growl')=='C:/Games/Dawnwalker/ue4ss/Mods/9_ModCore_Preymonition/sounds/unblockable_growl.wav',
    'cue and unblockable files under the mod folder')
assert(absolute.arrow('none')==nil and absolute.arrow('a b')==nil,'None and malformed keys play nothing')
local relative=load('@Mods/9_ModCore_Preymonition/Scripts/preymonition/sound.lua')
assert(relative.ROOT=='../9_ModCore_Preymonition','a relative source goes up from the caller\'s folder to this mod\'s')
local dotted=load('@.\\Mods\\9_ModCore_Preymonition\\Scripts\\preymonition\\sound.lua')
assert(dotted.ROOT=='../9_ModCore_Preymonition','a source relative to the working directory goes up from the caller\'s folder')
local rooted=load('@/Mods/9_ModCore_Preymonition/Scripts/preymonition/sound.lua')
assert(rooted.ROOT=='../9_ModCore_Preymonition','only a drive letter makes a source absolute')
print('PASS: Preymonition\'s sound paths name its own folder, absolute or from a sibling')
