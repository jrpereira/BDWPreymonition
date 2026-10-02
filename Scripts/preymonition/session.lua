-- Native attack hooks, event coalescing and cue animation for attached HUDs.
local Animation=require('preymonition.animation')
local Cue=require('preymonition.cue')
local Events=require('preymonition.events')

local HOOKS={
    {'/Script/DogwoodUI.CombatTargetIndicatorBase:UpdateIconTypeToMatchObservedStubState','show'},
    {'/Script/DogwoodUI.CombatTargetIndicatorBase:NotifyIndicatorCleared','clear'},
    {'/Script/DogwoodCombat.PlayerCombatComponent:OnCombatEnded','combat_end'},
}
local FRAME_MS=16

local queue=Events.new(16)
local cues={}
local active=false
local pending=false
-- Invalidates deferred callbacks scheduled before the session last stopped.
local token=0
local M={}

local function log(message)
    print('[Preymonition] '..tostring(message)..'\n')
end

local function later(milliseconds,callback)
    local current=token
    ExecuteWithDelay(milliseconds,function()
        ExecuteInGameThread(function()
            if current==token then callback() end
        end)
    end)
end

local function pump(record)
    if record.scheduled or record.detached or not record.model:has_jobs() then return end
    record.scheduled=true
    local ok,why=pcall(later,FRAME_MS,function()
        record.scheduled=false
        if record.detached or not Cue.valid(record.ui) then return end
        local stepped,more=pcall(record.model.step,record.model)
        if not stepped then record.model:cancel(); log(more); return end
        if more then pump(record) end
    end)
    if not ok then record.scheduled=false; record.model:cancel(); log(why) end
end

local function cueFor(indicator)
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) and Cue.sameWorld(indicator,record.ui) then return record end
    end
end

local handlers={}

function handlers.show(event)
    local indicator=Cue.resolve(event.path)
    if not Cue.visible(indicator) then return end
    local direction=Cue.direction(indicator)
    if not direction then return end
    local record=cueFor(indicator)
    if not record then return end
    -- After combat ends, stale indicator updates need positive combat state.
    local combat=Cue.combat(indicator)
    if combat==false or (record.ended and combat~=true) then return end
    Cue.style(record.ui,indicator)
    record.ended=false
    record.source=event.path
    if record.model:show(direction,event.path..':'..event.sequence) then pump(record) end
end

function handlers.clear(event)
    for _,record in ipairs(cues) do
        if record.source==event.path then
            record.source=nil
            record.model:hide(false)
            pump(record)
        end
    end
end

function handlers.combat_end(event)
    for _,record in ipairs(cues) do
        if Cue.valid(record.ui) and Cue.combatEnded(event.path,record.ui) then
            record.ended=true
            record.source=nil
            record.model:hide(true)
            pump(record)
        end
    end
end

local function drain()
    for _,event in ipairs(queue:drain()) do
        local ok,why=pcall(handlers[event.kind],event)
        if not ok then log(why) end
    end
end

local function schedule()
    if pending or not active then return end
    pending=true
    local ok,why=pcall(later,1,function()
        pending=false
        drain()
        if #queue.items>0 then schedule() end
    end)
    if not ok then pending=false; queue:clear(); log(why) end
end

local function push(kind,path)
    if not active or not next(cues) or not path then return end
    queue:push(kind,path)
    schedule()
end

local function stop()
    active=false
    pending=false
    token=token+1
    queue:clear()
end

function M.loaded(onCleanup)
    assert(not active,'Preymonition session is already active')
    local hooks={}
    -- Register release first so a partial registration is still undone.
    onCleanup(function()
        stop()
        local failures={}
        for index=#hooks,1,-1 do
            local hook=hooks[index]
            local ok,why=pcall(UnregisterHook,hook[1],hook[2],hook[3])
            if ok then table.remove(hooks,index) else failures[#failures+1]=tostring(why) end
        end
        if #failures>0 then error('hook removal failed: '..table.concat(failures,'; '),0) end
        return true
    end)
    active=true
    token=token+1
    for _,spec in ipairs(HOOKS) do
        local path,kind=spec[1],spec[2]
        local pre,post=RegisterHook(path,function(context)
            -- Copy only the path here; widget reads wait for the deferred drain.
            local ok,value=pcall(function() return Cue.path(context:get()) end)
            if ok then push(kind,value) end
        end)
        assert(type(pre)=='number' and type(post)=='number','hook unavailable: '..path)
        hooks[#hooks+1]={path,pre,post}
    end
end

function M.attach(hud,layer,params,onCleanup)
    local record={detached=false}
    onCleanup(function()
        record.detached=true
        if record.model then record.model:cancel() end
        for index,current in ipairs(cues) do
            if current==record then table.remove(cues,index); break end
        end
        if record.ui then Cue.destroy(record.ui) end
        return true
    end)
    record.ui=Cue.build(hud,layer,assert(params.screen,'screen unavailable'),params.settings or {})
    local ui=record.ui
    record.model=Animation.new({
        now=function() return Cue.now(ui) end,
        apply=function(state) Cue.apply(ui,state) end,
    })
    record.model:step()
    cues[#cues+1]=record
    -- Catch up with an attack that was already on screen when the cue attached.
    for _,path in ipairs(Cue.visibleIndicators()) do push('show',path) end
end

return M
