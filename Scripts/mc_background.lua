-- MCT loads this file with its folder on package.path.
local log=require('preymonition.logging').new('Preymonition Background')
local Background=require('preymonition.background')
Background.setLog(log)

-- A shield behind the omens that lights up with the incoming attack. The
-- omens, the screen edges and the countdown are templates of their own.
local template={
    id='Background',
    label='Background Overlay',
    description='Show a shield behind the omens: yellow while an attack is shown, red once its parry window opens.',
    category='npc.attacks',
    -- Before the omens (10): its layer joins the HUD first, under theirs.
    priority=9,
    -- MCT creates a layer on the HUD for the shield.
    objects={hud={},cue={}},
    -- Awake during combat; MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Background.wake() end,
        sleep=function() Background.sleep() end,
        update=function(_,event) Background.update(event) end,
    },
    menu={
        -- The same places as the omens' Position.
        {id='Position', label='Position', values={[0]='Below',[1]='Middle',[2]='Above'}, default=1,
            description='Where the shield shows: low, in the middle, or high. Match the Omens\' Position to keep them together.'},
        {id='Visibility', label='Visibility',
            description='When the shield shows: faintly throughout combat, yellow while an attack is shown, or only once its parry window opens. It turns red while the parry window is open.',
            values={[1]='In Combat',[2]='Defending',[3]='Critical'}, default=2},
        -- Size: the shield's drawn height as a share of the screen height.
        {id='Size', label='Size', values={min=5,max=100,step=5,suffix='%'}, default=50,
            description='The shield\'s size, as a share of the screen height.'},
    },
}

template.attach=function(objects,params,original)
    Background.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
