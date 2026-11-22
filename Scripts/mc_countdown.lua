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
    description='Count down to the incoming attack\'s Perfect Opportunity window, then show NOW, or its direction, while it is open.',
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
        -- Style: the time above the bar, the bar alone or the time alone.
        {id='Style', label='Style',
            values={{key='full',label='Full'},{key='bar',label='Bar only'},{key='label',label='Label only'}}, default='full',
            description='What the countdown shows: the time above the bar, only the bar, or only the time.'},
        -- Show direction in label: the attack's direction instead of NOW, as the
        -- Omens' arrow points; hidden while there is no label.
        {id='Direction', label='Show direction in label', values={[0]='Off',[1]='On'}, widget='switch', default=0,
            conditions={visible={field='Style',values={'full','label'}}},
            description='Shows the attack\'s direction (UP, DOWN, LEFT or RIGHT) instead of NOW during the Perfect Opportunity window.'},
        -- Position: where the countdown sits, low, centre or high on the screen.
        {id='Position', label='Position',
            values={{key='below',label='Below'},{key='middle',label='Middle'},{key='above',label='Above'}}, default='middle',
            description='Where the countdown shows: below the middle of the screen, at it or above it.'},
        -- Size: the size as the count starts (low) and as it reaches the Perfect
        -- Opportunity window (high), animated with the count; the bar and the time
        -- grow together, kept inside the screen. 10% is the size it had before.
        {id='Size', label='Size', type='range', values={min=5,max=100,step=5,suffix='%',delta={0}}, default={10,10},
            description='The size when it appears, and the size it reaches at the Perfect Opportunity window: 10% is the default, 100% fills most of the screen height.'},
        -- Opacity: the countdown's opacity as the count starts (low) and at the
        -- window (high), animated with the count; the time, the bar and its outline alike.
        {id='Opacity', label='Opacity', type='range', values={min=0,max=100,step=10,suffix='%',delta={0}}, default={50,70},
            description='The opacity when it appears, and the opacity it reaches at the Perfect Opportunity window.'},
    },
}

template.attach=function(objects,params,original)
    Countdown.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
