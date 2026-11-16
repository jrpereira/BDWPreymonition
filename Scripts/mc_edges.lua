-- MCT loads this file with its folder on package.path.
local log=require('preymonition.logging').new('Preymonition Edges')
local Edges=require('preymonition.edges')
Edges.setLog(log)

-- The screen edges glow while an attack is incoming. The omens and the audio cues
-- are templates of their own (mc_omens.lua, mc_audio.lua).
local template={
    id='Edges',
    label='Edges Flash',
    description='Light the screen edges while an attack is incoming.',
    category='npc.attacks',
    -- After the omens (10).
    priority=11,
    -- ModCore Templates' live preview on the module page, over the Omens' picture.
    preview={},
    -- MCT creates a full-screen layer on the HUD for the edges.
    objects={hud={},cue={}},
    -- Awake during combat; MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Edges.wake() end,
        sleep=function() Edges.sleep() end,
        update=function(_,event) Edges.update(event) end,
    },
    menu={
        -- Activate Edges: what lights the edges. The attacked side's edge lights
        -- yellow as an attack's parry window opens (the yellow arrow) and red as
        -- its Perfect Opportunity window opens (the red arrow); an unblockable
        -- attack lights every edge red while it shows.
        {id='Activate', label='Activate Edges', fields={
            {id='.Incoming', label='Attack incoming', values={[0]='Off',[1]='On'}, widget='switch', default=1,
                description='Lights the edge on the attack\'s side, yellow, when an attack\'s parry window opens.'},
            {id='.Perfect', label='Perfect Opportunity', values={[0]='Off',[1]='On'}, widget='switch', default=1,
                description='Lights the edge on the attack\'s side, red, when its Perfect Opportunity window opens.'},
            {id='.Unblockable', label='Unblockable Attack', values={[0]='Off',[1]='On'}, widget='switch', default=1,
                description='Lights every edge, red, while an unblockable attack shows.'},
        }},
        -- Visuals: how the glow looks.
        {id='Visuals', label='Visuals', fields={
            -- Style: Bands, then the gradients listed from images/edge_<key>_v.png
            -- and _h.png pairs each time the menu opens, saved by name.
            {id='.Style', label='Style', values={{key='bands',label='Bands'},{from='choices/edge_gradients.lua'}}, default='soft',
                description='How the glow fades inward: Bands, or a smooth gradient from the mod\'s images folder.'},
            -- Thickness: how deep the glow reaches, as a share of the shorter screen side.
            {id='.Thickness', label='Thickness', values={min=2,max=20,step=1,suffix='%'}, default=8,
                description='How far the glow reaches in from the screen edge.'},
            -- Intensity: the glow's opacity at the screen edge.
            {id='.Intensity', label='Intensity', values={min=10,max=100,step=5,suffix='%'}, default=50,
                description='How strong the glow is at the screen edge.'},
        }},
    },
}

template.attach=function(objects,params,original)
    Edges.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
