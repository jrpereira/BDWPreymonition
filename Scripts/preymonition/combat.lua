-- The game's combat state the templates read: the parry window, an attack's
-- attacker and hit window, and the game's clocks, plus the class defaults those
-- reads go through.
local MC=require('mc')

local GAMEPLAY_STATICS='/Script/Engine.Default__GameplayStatics'
local COMBAT_LIBRARY='/Script/DogwoodCombat.Default__CombatBlueprintFunctionLibrary'
local M={}

-- A class default object, kept between calls: the engine never frees one.
local defaults={}
function M.default(path)
    local object=defaults[path]
    if object and MC.valid(object) then return object end
    object=StaticFindObject(path)
    object=MC.valid(object) and object or nil
    defaults[path]=object
    return object
end

-- Where an indicator's attack comes from: the owner of the latest queued
-- attack's instigator, a combat component. Nil when the queue names none.
function M.attacker(indicator)
    local queue=indicator.AttackQueue
    local count=queue and MC.call(queue,'GetArrayNum') or 0
    for index=count,1,-1 do
        local component=queue[index].Instigator
        local actor=MC.valid(component) and MC.call(component,'GetOwner')
        if actor and MC.valid(actor) then return actor end
    end
end

-- The current difficulty's parry window multiplier on this platform, or nil
-- when the game's combat subsystem cannot be read. The world subsystem lookup
-- needs no object scan; context is any live object in the player's world.
local SUBSYSTEMS='/Script/Engine.Default__SubsystemBlueprintLibrary'
local COMBAT='/Script/DogwoodCombat.CombatSubsystem'
local PLATFORM='Windows'
function M.parryWindow(context)
    local library,class=M.default(SUBSYSTEMS),M.default(COMBAT)
    if not (library and class) then return nil end
    local subsystem=MC.call(library,'GetWorldSubsystem',context,class)
    if not MC.valid(subsystem) then return nil end
    local level=subsystem.ActionDifficultyLevel
    local found
    subsystem.DifficultyConfig.ActionDifficulties:ForEach(function(key,value)
        if key:get()~=level then return end
        value:get().ParryWindowMultipliers:ForEach(function(name,multiplier)
            if name:get():ToString()==PLATFORM then found=multiplier:get() end
        end)
    end)
    return type(found)=='number' and found>0 and found or nil
end

-- Real time in seconds, running through pauses; context is any live object in
-- the world. Animations run on it.
function M.now(context)
    local clock=assert(M.default(GAMEPLAY_STATICS),'GameplayStatics unavailable')
    return clock:GetRealTimeSeconds(context)
end

-- Game time in seconds, stopped while paused: the clock an attack's hit window
-- is in.
function M.gameTime(context)
    local clock=assert(M.default(GAMEPLAY_STATICS),'GameplayStatics unavailable')
    return clock:GetTimeSeconds(context)
end

-- An attack's hit window in game time, from its attacker's AI stub (a path, as MCT
-- gives it): its start and end, or nil when the stub is gone or the game has
-- none for its current attack (it reports -1). The game fixes it as the attack
-- starts, in the frame its arrow shows.
function M.hitWindow(stubPath)
    if type(stubPath)~='string' then return nil end
    local stub=StaticFindObject(stubPath)
    local library=M.default(COMBAT_LIBRARY)
    if not (MC.valid(stub) and library) then return nil end
    local from=library:GetHitWindowTime(stub,false)
    local to=library:GetHitWindowTime(stub,true)
    if type(from)~='number' or type(to)~='number' or from<0 or to<from then return nil end
    return from,to
end

return M
