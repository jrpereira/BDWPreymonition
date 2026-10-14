-- Developer probe: logs native calls that may announce an attack, next to the
-- cue's own events, to compare their timing in UE4SS.log. Off unless a
-- probe.txt sits next to mod.json; registered once and never removed.
local Cue=require('preymonition.cue')

local M={}

local function value(param)
    if param==nil then return nil end
    local ok,result=pcall(function() return param:get() end)
    if ok then return result end
    return param
end

local function path(param)
    local object=value(param)
    return object and Cue.path(object) or 'none'
end

local function fname(param)
    local name=value(param)
    local ok,text=pcall(function() return name:ToString() end)
    return ok and text or tostring(name)
end

local HOOKS={
    {path='/Script/Dawnwalker.DawnwalkerPlayerCharacter:UpdateAttackWarning',
        describe=function(context,started,socket)
            return 'started ',tostring(value(started)),', socket ',fname(socket),', on ',path(context)
        end},
    {path='/Script/DogwoodUI.CombatWarningAttackBase:ShouldShowWarning',
        describe=function(context,active)
            local widget=value(context)
            local ok,visible=pcall(function() return widget:IsVisible() end)
            return 'active ',tostring(value(active)),', visible ',ok and tostring(visible) or 'unknown',
                ', on ',path(context)
        end},
}

-- One queued attack, for the log: enums as numbers, objects by short name.
local function short(object)
    local full=object and Cue.path(object)
    return full and (full:match('[.:]([^.:]+)$') or full) or 'none'
end
local function attack(data)
    local owner
    local component=data.Instigator
    if component and component:IsValid() then owner=component:GetOwner() end
    return string.format('direction %s, type %s, unblockable %s, chain %s, at %.2f, by %s, montage %s, action %s',
        tostring(data.Direction),tostring(data.AttackType),tostring(data.bIsUnblockable),tostring(data.ChainCount),
        tonumber(data.TimePerformed) or -1,short(owner),short(data.PlayedAttackMontage),short(data.Action))
end

-- Logs an indicator's AttackQueue at a cue event, newest last.
function M.queue(log,indicator,event)
    if not indicator then log.debug('probe queue at ',event,': no indicator') return end
    local queue=indicator.AttackQueue
    local count=queue and queue:GetArrayNum() or 0
    log.debug('probe queue at ',event,': ',count,' attack(s) on ',short(indicator))
    for index=1,count do
        local ok,text=pcall(attack,queue[index])
        log.debug('probe queue  #',index,': ',ok and text or 'unreadable: '..tostring(text))
    end
end

-- Registers every probe hook and logs each outcome; a hook that fails to
-- register leaves the others and the cue untouched.
function M.start(log)
    for _,hook in ipairs(HOOKS) do
        local name=hook.path:match('[^.]+$')
        local calls=0
        local registered,pre,post=pcall(RegisterHook,hook.path,function(context,...)
            calls=calls+1
            local ok,why=Cue.pass(function(...)
                log.debug('probe ',name,' #',calls,': ',hook.describe(context,...))
            end,...)
            if not ok then log.warn('probe ',name,' #',calls,' unreadable: ',why) end
        end)
        if registered and type(pre)=='number' then
            log.info('probe hooked ',hook.path,' (ids ',pre,', ',post,')')
        else
            log.warn('probe could not hook ',hook.path,': ',registered and 'no hook id' or pre)
        end
    end
end

return M
