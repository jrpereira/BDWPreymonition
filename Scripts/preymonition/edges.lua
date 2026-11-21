-- Takes MCT's MC_NPCAttackIndicator requests and decides which screen edges
-- glow; preymonition.edges_render draws them. Only the attacked side's edge
-- lights: yellow from the attack's parry window (Activate Edges → Attack
-- incoming), red from its Perfect Opportunity window (→ Perfect Opportunity),
-- out as soon as it resolves. An unblockable attack lights every edge red while
-- it shows (→ Unblockable Attack), over any directional attack.
local Render=require('preymonition.edges_render')
local Widgets=require('preymonition.widgets')
local Controller=require('preymonition.controller')

local ALL={}
for index=1,Render.EDGES do ALL[index]=true end
local NONE={}

local records={}
-- Whether combat is on: requests arrive only while it is.
local active=false
local M={}

local log=Controller.silentLog()
function M.setLog(logger) log=logger end

-- Failures are logged once per kind; repeats are counted when combat ends.
local fail,reportFailures=Controller.failures('edges ',function() return log end)

-- Renders a record: every edge red while an unblockable attack shows, else its
-- attack's side, red once critical with Perfect Opportunity on, yellow with
-- Attack incoming on, or nothing.
local function render(record)
    if record.unblockable then return Render.show(record.ui,ALL,true) end
    local direction=record.direction
    if direction and record.critical and record.activate.perfect then
        Render.show(record.ui,{[direction]=true},true)
    elseif direction and record.activate.incoming then
        Render.show(record.ui,{[direction]=true},false)
    else
        Render.show(record.ui,NONE,false)
    end
end

local function forget(record)
    record.source,record.direction,record.critical,record.paths=nil,nil,nil,nil
end

local function clear(record)
    forget(record)
    record.unblockable=nil
    render(record)
end

-- The records an event reaches. A preview event (ModCore Templates' live preview
-- in the mod menu, the menu's widget as its indicator) reaches only the preview
-- records, a game event only the others in the indicator's world.
local function each(event,callback)
    local preview=event.preview==true
    for _,record in ipairs(records) do
        if record.preview==preview then
            local hud=Render.root(record.ui)
            if hud and (preview or Widgets.sameWorld(hud,event.indicator)) then callback(record) end
        end
    end
end

local handlers={}

-- An attack is first seen: its parry window opens. The same attack reported
-- again, from any indicator, changes nothing (preymonition.controller's joins).
function handlers.arrow(event)
    each(event,function(record)
        if Controller.joins(record,event) then return end
        Controller.open(record,event)
        record.critical=nil
        render(record)
    end)
end

-- Its Perfect Opportunity window opens. An attack first seen here is tracked
-- from now on.
function handlers.critical(event)
    each(event,function(record)
        if Controller.joins(record,event) then
            if record.critical then return end
        else
            Controller.open(record,event)
        end
        record.critical=true
        render(record)
    end)
end

-- The edge goes out once every indicator of its attack resolved.
function handlers.resolve(event)
    each(event,function(record)
        if Controller.resolves(record,event.path) then
            forget(record)
            render(record)
        end
    end)
end

-- An unblockable attack shows (active) or goes. While it shows it wins over the
-- directional attack, which shows again once it goes.
function handlers.unblockable(event)
    each(event,function(record)
        local on=event.active==true and record.activate.unblockable or nil
        if record.unblockable~=on then
            record.unblockable=on
            render(record)
        end
    end)
end

-- One MC_NPCAttackIndicator request.
function M.update(event)
    if not next(records) or not (active or event.preview) then return end
    local handler=handlers[event.kind]
    if not handler then return end
    local ok,why=pcall(handler,event)
    if not ok then fail(event.kind,why) end
end

function M.wake()
    active=true
end

-- Combat ended: every edge goes out, but the preview's.
function M.sleep()
    if not active then return end
    active=false
    for _,record in ipairs(records) do
        if not record.preview and Render.root(record.ui) then
            local ok,why=pcall(clear,record)
            if not ok then fail('combat end',why) end
        end
    end
    reportFailures()
end

-- A slider's saved percentage within its range, or its default.
local function percent(value,low,high,default)
    if type(value)~='number' or value~=value then return default/100 end
    return math.max(low,math.min(high,value))/100
end

-- An Activate Edges switch: On unless saved Off.
local function switch(value) return value~=0 and value~=false end

-- The Visuals' Style, Thickness and Intensity as the renderer takes them.
-- An unknown or unsafe Style key draws bands.
local function look(settings)
    local style=settings.VisualsStyle
    if type(style)~='string' or not style:match('^[%w_]+$') then style=nil end
    return {gradient=style and style:lower() or 'soft',
        thickness=percent(settings.VisualsThickness,2,20,8),intensity=percent(settings.VisualsIntensity,10,100,50)}
end

-- Gradients whose pictures failed to load, warned about once each.
local warned={}

function M.attach(hud,layer,params,onCleanup)
    local settings=params.settings or {}
    local record={preview=params.preview==true,activate={incoming=switch(settings.ActivateIncoming),
        perfect=switch(settings.ActivatePerfect),unblockable=switch(settings.ActivateUnblockable)}}
    local options=look(settings)
    onCleanup(function()
        for index,current in ipairs(records) do
            if current==record then table.remove(records,index); break end
        end
        if record.ui then Render.destroy(record.ui) end
        log.debug('edges detached; ',#records,' attached')
        return true
    end)
    record.ui=Render.build(hud,layer,assert(params.screen,'screen unavailable'),options)
    if record.ui.fallback and not warned[options.gradient] then
        warned[options.gradient]=true
        log.warn('edge style ',options.gradient,' unavailable, drawing bands: ',record.ui.fallback)
    end
    records[#records+1]=record
    local on={}
    for _,name in ipairs({'incoming','perfect','unblockable'}) do if record.activate[name] then on[#on+1]=name end end
    log.info(record.preview and 'preview edges attached, ' or 'edges attached, ',#on>0 and table.concat(on,'+') or 'none',', ',record.ui.gradient)
end

return M
