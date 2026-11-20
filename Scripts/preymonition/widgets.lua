-- What every template's renderer does with its widgets alike: constructs and
-- keeps them, names them, and tells whether an object shares their world.
local MC=require('mc')
local Combat=require('preymonition.combat')

local M={}

-- A widget of the class at classPath under outer, hidden from hit tests. A
-- widget class is found once: the engine never frees it.
function M.construct(classPath,outer,name)
    local class=assert(Combat.default(classPath),'missing widget class: '..classPath)
    local object=StaticConstructObject(class,outer,FName(name),0x40)
    assert(MC.valid(object),'widget construction failed: '..name)
    object:SetVisibility(3)
    return object
end

-- A weak handle on object; owner and what name it in the error.
function M.hold(object,owner,what)
    return assert(MC.hold(object),owner..' cannot keep '..what)
end

-- Widget names stay unique across Lua reloads: generation restarts with the
-- Lua state, while a HUD that survives the reload still holds the old names.
-- Each build appends one suffix to every name it gives.
local generation=0
local nonce=string.format('%06x',math.random(0,0xffffff))
function M.suffix()
    generation=generation+1
    return nonce..'_'..generation
end

-- The full name of object's world, or nil without one.
function M.worldName(object)
    local world=MC.call(object,'GetWorld')
    local name=MC.valid(world) and MC.call(world,'GetFullName')
    return type(name)=='string' and name~='' and name or nil
end

-- Whether object is in the same world as hud, a template's live HUD.
function M.sameWorld(hud,object)
    if not (hud and MC.valid(object)) then return false end
    local own=M.worldName(hud)
    return own~=nil and own==M.worldName(object)
end

return M
