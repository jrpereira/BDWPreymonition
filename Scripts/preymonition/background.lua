-- The Background: a shield behind the omens that follows MCT's
-- MC_NPCAttackIndicator events. preymonition.background_render draws it; its
-- timing is preymonition.omens_animation's, as the omens' is: it fades in with
-- combat and out when it ends, and a Critical shield grows when it pops in.
local Animation=require('preymonition.omens_animation')
local Combat=require('preymonition.combat')
local Render=require('preymonition.background_render')

local FRAME_MS=16
-- Each animation lasts PER_MULTIPLIER seconds times the game's parry window
-- multiplier, read when combat starts, like the omens'.
local PER_MULTIPLIER,FALLBACK=0.2,1.4

local records={}
-- Whether combat is on: events arrive only while it is.
local active=false
local M={}

local function silent() end
local log={enabled=function() return false end}
for _,name in ipairs({'trace','debug','info','warn','error','critical'}) do log[name]=silent end
function M.setLog(logger) log=logger end

-- Failures are logged once per kind; repeats are counted when combat ends.
local failures={}
local function fail(kind,why)
    local count=failures[kind]
    failures[kind]=(count or 0)+1
    if not count then log.error('background ',kind,' failed: ',why) end
end

-- Next frame when the engine tick is hooked; ExecuteWithDelay's timer is coarser.
local function later(callback)
    if rawget(_G,'EngineTickAvailable')==true and type(rawget(_G,'ExecuteInGameThreadAfterFrames'))=='function' then
        ExecuteInGameThreadAfterFrames(1,callback)
    else
        ExecuteWithDelay(FRAME_MS,function() ExecuteInGameThread(callback) end)
    end
end

-- Asks for the next frame while the record's animation still moves.
local function pump(record)
    if record.scheduled or record.detached or not record.model:has_jobs() then return end
    record.scheduled=true
    local ok,why=pcall(later,record.onFrame)
    if not ok then record.scheduled=false; record.model:cancel(); fail('schedule',why) end
end

-- The records in the indicator's world.
local function each(indicator,callback)
    for _,record in ipairs(records) do
        if Render.valid(record.ui) and Render.sameWorld(record.ui,indicator) then callback(record) end
    end
end

local function clear(record)
    record.source,record.direction,record.critical=nil,nil,nil
end

local handlers={}

-- An attack shows: the shield follows it. The game's arrow sometimes shows twice
-- for one attack; the attack already shown carries on.
function handlers.arrow(event)
    each(event.indicator,function(record)
        if record.source==event.path and record.direction==event.direction then return end
        record.source,record.direction,record.critical=event.path,event.direction,nil
        record.model:show(event.direction,event.path..':'..tostring(event.sequence))
        pump(record)
    end)
end

-- Its parry window opened: the shield turns red, once per attack. An attack
-- first seen critical shows then.
function handlers.critical(event)
    each(event.indicator,function(record)
        if record.source~=event.path or record.direction~=event.direction then
            record.source,record.direction,record.critical=event.path,event.direction,nil
            record.model:show(event.direction,event.path..':'..tostring(event.sequence))
        end
        if record.critical then return end
        record.critical=true
        record.model:critical(event.direction)
        pump(record)
    end)
end

function handlers.resolve(event)
    for _,record in ipairs(records) do
        if record.source==event.path and Render.valid(record.ui) then
            clear(record)
            if record.model:hide(false) then pump(record) end
        end
    end
end

-- The unblockable skull shows in the omens: the shield clears meanwhile.
function handlers.unblockable(event)
    each(event.indicator,function(record)
        local hidden=event.active==true
        if record.hidden==hidden then return end
        record.hidden=hidden
        record.model:step()
    end)
end

-- One MC_NPCAttackIndicator event.
function M.update(event)
    if not (active and next(records)) then return end
    local handler=handlers[event.kind]
    if not handler then return end
    local ok,why=pcall(handler,event)
    if not ok then fail(event.kind,why) end
end

-- Combat started: the shield takes the difficulty's timing and fades in.
function M.wake()
    if active then return end
    active=true
    for _,record in ipairs(records) do
        if Render.valid(record.ui) then
            local ok,why=pcall(function()
                Render.style(record.ui)
                local read,multiplier=pcall(Combat.parryWindow,Render.context(record.ui))
                if not (read and multiplier) then multiplier=FALLBACK end
                record.model:setDuration(PER_MULTIPLIER*multiplier)
                if record.model:engage() then pump(record) end
            end)
            if not ok then fail('combat start',why) end
        end
    end
end

-- Combat ended: the shield calms and fades out.
function M.sleep()
    if not active then return end
    active=false
    for _,record in ipairs(records) do
        if Render.valid(record.ui) then
            clear(record)
            record.hidden=nil
            local ok,why=pcall(function()
                record.model:hide(true)
                pump(record)
            end)
            if not ok then fail('combat end',why) end
        end
    end
    for kind,count in pairs(failures) do
        if count>1 then log.warn('background ',kind,' failed ',count-1,' more times') end
    end
    failures={}
end

function M.attach(hud,layer,params,onCleanup)
    local settings=params.settings or {}
    local record={}
    record.onFrame=function()
        record.scheduled=false
        if record.detached or not Render.valid(record.ui) then return end
        local ok,more=pcall(record.model.step,record.model)
        if not ok then record.model:cancel(); fail('frame',more) return end
        if more then pump(record) end
    end
    onCleanup(function()
        record.detached=true
        if record.model then record.model:cancel() end
        for index,current in ipairs(records) do
            if current==record then table.remove(records,index); break end
        end
        if record.ui then Render.destroy(record.ui) end
        log.debug('background detached; ',#records,' attached')
        return true
    end)
    record.ui=Render.build(hud,layer,assert(params.screen,'screen unavailable'),settings)
    local ui=record.ui
    record.model=Animation.new({
        now=function() return Combat.now(Render.context(ui)) end,
        apply=function(state) Render.apply(ui,state,record.hidden) end,
        -- Only the Critical shield grows when it pops in.
        grow=ui.visuals.visibility==3,
    })
    record.model:step()
    records[#records+1]=record
    log.info('background attached, visibility ',ui.visuals.visibility,', size ',ui.visuals.size*100,
        '%, position ',ui.visuals.position)
end

return M
