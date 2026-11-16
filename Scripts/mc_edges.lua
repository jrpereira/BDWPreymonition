-- MCT loads this file with its folder on package.path.
local log=require('preymonition.logging').new('Preymonition Edges')
local Edges=require('preymonition.edges')
Edges.setLog(log)

-- The screen edges glow while an attack is incoming. The omens and the sounds
-- are templates of their own (mc_omens.lua, mc_sounds.lua).
local template={
    id='Edges',
    label='Edges',
    description='Light the screen edges while an attack is incoming.',
    category='npc.attacks',
    -- After the omens (10).
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
        {id='Edge', label='Screen Edges', style='none', fields={
            {id='.Style', label='Edge Style', values={{key='framed',label='Framed'},{key='directional',label='Directional'}}, default='framed',
                description='Framed lights every screen edge during an attack, Directional only the edge on the attack\'s side. They turn red when the perfect opportunity window opens.'},
        }},
    },
}

template.attach=function(objects,params,original)
    Edges.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
