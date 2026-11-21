-- MCT loads this file with its folder on package.path.
local log=require('preymonition.logging').new('Preymonition Countdown')
local Countdown=require('preymonition.countdown')
Countdown.setLog(log)

-- A countdown to the incoming attack's Perfect Opportunity window. The
-- omens, the screen edges and the sounds are templates of
-- their own.
local template={
    id='Countdown',
    label='Countdown',
    description='Count down to the incoming attack\'s Perfect Opportunity window, then show NOW while it is open.',
    category='npc.attacks',
    -- After the omens (10) and the edges (11).
    priority=12,
    -- ModCore Templates' live preview on the module page, over the Omens' picture.
    preview={},
    -- MCT creates a layer on the HUD for the countdown.
    objects={hud={},cue={}},
    -- Awake during combat; MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Countdown.wake() end,
        sleep=function() Countdown.sleep() end,
        update=function(_,event) Countdown.update(event) end,
    },
    menu={
        -- Position: where the bar sits, low, centre or high on the screen.
        {id='Position', label='Position',
            values={{key='below',label='Below'},{key='middle',label='Middle'},{key='above',label='Above'}}, default='middle',
            description='Where the countdown shows: below the middle of the screen, at it or above it.'},
        -- Size: the bar and the time grow together, kept inside the screen.
        {id='Size', label='Size', values={min=5,max=100,step=5,suffix='%'}, default=10,
            description='How big the countdown is: 10% is the default, 100% fills most of the screen height.'},
    },
}

template.attach=function(objects,params,original)
    Countdown.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
