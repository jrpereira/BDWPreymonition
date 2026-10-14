-- MCT loads this file with its folder on package.path.
local log=require('preymonition.logging').new('Preymonition Edges')
local Edges=require('preymonition.edges')
Edges.setLog(log)

-- The screen edges glow while an attack is incoming. The center cue is a
-- template of its own (mc_center.lua).
local template={
    name='Edges',
    description='Light the screen edges while an attack is incoming.',
    category='npc.attacks',
    -- After the center cue (10).
    priority=11,
    -- MCT creates a full-screen layer on the HUD for the edges.
    objects={hud={},cue={}},
    -- Awake during combat; MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Edges.wake() end,
        sleep=function() Edges.sleep() end,
        update=function(_,event) Edges.update(event) end,
    },
    menu={
        {id='Edge', label='Screen Edges', fields={
            {id='.Style', label='Edge Style', values={[1]='Framed',[2]='Directional'}, default=1},
        }},
    },
}

template.attach=function(objects,params,original)
    Edges.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
