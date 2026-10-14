-- Takes MCT's MC_NPCAttackIndicator requests and decides which screen edges
-- glow; preymonition.edges_render draws them. Framed lights every edge during
-- an attack, Directional only the attacked side's; a critical attack turns them
-- red, and they go out as soon as it resolves.
local Render=require('preymonition.edges_render')

-- An early warning nothing takes over goes after this, as the center cue's does.
local EARLY_TIMEOUT_MS=1200
local FRAMED,DIRECTIONAL=1,2
local ALL={}
for index=1,Render.EDGES do ALL[index]=true end

local records={}
-- Whether combat is on: requests arrive only while it is.
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
    if not count then log.error('edges ',kind,' failed: ',why) end
end

-- Renders a record's attack: its edges lit by style, red while critical.
local function render(record)
    local lit={}
    if record.direction then
        if record.style==DIRECTIONAL then lit[record.direction]=true else lit=ALL end
    end
    Render.show(record.ui,lit,record.critical)
end

local function clear(record)
    record.source,record.direction,record.critical,record.early=nil,nil,nil,nil
    render(record)
end

-- The records in the indicator's world, or every record without one.
local function each(indicator,callback)
    for _,record in ipairs(records) do
        if Render.valid(record.ui) and (indicator==nil or Render.sameWorld(record.ui,indicator)) then
            callback(record)
        end
    end
end

local function expire(record,token)
    if record.earlyToken~=token or not record.early or not Render.valid(record.ui) then return end
    clear(record)
end

local handlers={}

-- An attack shows: its edges light. The cue's own attack styled again, or any
-- critical request, turns them red.
function handlers.arrow(event)
    each(event.indicator,function(record)
        record.source,record.direction,record.critical,record.early=event.path,event.direction,nil,nil
        render(record)
    end)
end

function handlers.critical(event)
    each(event.indicator,function(record)
        if record.source~=event.path or record.direction~=event.direction then
            record.source,record.direction,record.early=event.path,event.direction,nil
        end
        record.critical=true
        render(record)
    end)
end

function handlers.resolve(event)
    each(event.indicator,function(record)
        if record.source==event.path and (event.reason~='dark' or record.direction==event.direction) then
            clear(record)
        end
    end)
end

-- The game's early warning lights the edges before the indicator does; the
-- attack takes them over when it shows, or they go after EARLY_TIMEOUT_MS.
function handlers.early(event)
    if not event.direction then return end
    each(nil,function(record)
        if record.source then return end
        record.direction,record.critical,record.early=event.direction,nil,true
        render(record)
        record.earlyToken=(record.earlyToken or 0)+1
        local token=record.earlyToken
        local ok,why=pcall(ExecuteWithDelay,EARLY_TIMEOUT_MS,function()
            ExecuteInGameThread(function()
                local done,failure=pcall(expire,record,token)
                if not done then fail('early expiry',failure) end
            end)
        end)
        if not ok then fail('early schedule',why) end
    end)
end

-- One MC_NPCAttackIndicator request, inside the game's call.
function M.update(event)
    if not (active and next(records)) then return end
    local handler=handlers[event.kind]
    if not handler then return end
    local ok,why=pcall(handler,event)
    if not ok then fail(event.kind,why) end
end

function M.wake()
    active=true
end

-- Combat ended: every edge goes out.
function M.sleep()
    if not active then return end
    active=false
    for _,record in ipairs(records) do
        if Render.valid(record.ui) then
            local ok,why=pcall(clear,record)
            if not ok then fail('combat end',why) end
        end
    end
    for kind,count in pairs(failures) do
        if count>1 then log.warn('edges ',kind,' failed ',count-1,' more times') end
    end
    failures={}
end

function M.attach(hud,layer,params,onCleanup)
    local settings=params.settings or {}
    local record={style=settings.EdgeStyle==DIRECTIONAL and DIRECTIONAL or FRAMED}
    onCleanup(function()
        for index,current in ipairs(records) do
            if current==record then table.remove(records,index); break end
        end
        if record.ui then Render.destroy(record.ui) end
        log.debug('edges detached; ',#records,' attached')
        return true
    end)
    record.ui=Render.build(hud,layer,assert(params.screen,'screen unavailable'))
    records[#records+1]=record
    log.info('edges attached, ',record.style==DIRECTIONAL and 'directional' or 'framed')
end

return M
