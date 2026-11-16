-- MCT loads this file with its folder on package.path.
local log=require('preymonition.logging').new('Preymonition Countdown')
local Countdown=require('preymonition.countdown')
Countdown.setLog(log)

-- A countdown to the incoming attack's Perfect Opportunity window, below the
-- omens' arrows. The omens, the screen edges and the sounds are templates of
-- their own.
local template={
    id='Countdown',
    label='Countdown (WIP)',
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
        -- The same places as the omens' Position, below their arrows.
        {id='Position', label='Position',
            values={{key='below',label='Below'},{key='middle',label='Middle'},{key='above',label='Above'}}, default='middle',
            description='Where the countdown shows, under the omens\' arrows at the same Position.'},
    },
}

template.attach=function(objects,params,original)
    Countdown.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
