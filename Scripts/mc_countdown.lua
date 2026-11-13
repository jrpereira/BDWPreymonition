-- MCT loads this file with its folder on package.path.
local log=require('preymonition.logging').new('Preymonition Countdown')
local Countdown=require('preymonition.countdown')
Countdown.setLog(log)

-- A countdown to the incoming attack's parry window, below the Background's
-- shield. The background, the omens and the screen edges are templates of their own.
local template={
    id='Countdown',
    label='Countdown Overlay',
    description='Count down to the incoming attack\'s parry window, then show NOW while it is open.',
    category='npc.attacks',
    -- After the omens (10) and the edges (11).
    priority=12,
    -- MCT creates a layer on the HUD for the countdown.
    objects={hud={},cue={}},
    -- Awake during combat; MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Countdown.wake() end,
        sleep=function() Countdown.sleep() end,
        update=function(_,event) Countdown.update(event) end,
    },
    menu={
        -- The same places as the omens' Position, below a shield at its default size.
        {id='Position', label='Position', values={[0]='Below',[1]='Middle',[2]='Above'}, default=1,
            description='Where the countdown shows: under the Background\'s shield at the same Position, at its default size.'},
    },
}

template.attach=function(objects,params,original)
    Countdown.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
