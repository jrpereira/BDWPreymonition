-- MCT loads this file with its folder on package.path.
local Logging=require('preymonition.logging')
local log=Logging.new('Preymonition')
local Session=require('preymonition.omens')
Session.setLog(log)

-- The omens: the incoming attack shown as symbols, an arrow for its direction,
-- centred at the arrows' Position (preymonition.placement), or a picture at the
-- screen's centre, a skull by default, when it cannot be blocked. The screen
-- edges, the countdown and the audio cues are templates of their own
-- (mc_edges.lua, mc_countdown.lua, mc_audio.lua).
local template={
    id='Omens',
    label='Omens Overlay',
    -- On out of the box.
    defaultEnabled=true,
    description='Show the incoming attack as symbols: an arrow for its direction, or a picture when it cannot be blocked.',
    category='npc.attacks',
    -- Before the edges (11): MCT attaches, wakes and updates it first.
    priority=10,
    -- ModCore Templates' live preview on the module page, over this picture.
    preview={background='images/preview_background.jpg'},
    -- MCT creates the cue layer on the HUD. The session builds the arrows and
    -- the unblockable picture inside it and follows the game's attack indicator through MCT's events.
    objects={hud={},cue={}},
    -- npc.attacks wakes its templates when combat starts and puts them to sleep
    -- when it ends; in between, MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Session.wake() end,
        sleep=function() Session.sleep() end,
        update=function(_,event) Session.update(event) end,
    },
    menu={
        {id='Parry', label='Parry & Block Indicator', fields={
            {id='.Style', label='Style', values={{key='off',label='Off'},{from='choices/parry_style.lua'}}, default='chevron',
                description='How the arrow looks: one of the pictures in the mod\'s images folder.'},
            {id='.Position', label='Position',
                values={{key='below',label='Below'},{key='middle',label='Middle'},{key='above',label='Above'}}, default='middle',
                description='Where the arrows show on the screen.'},
            -- Size: where the arrow starts and how large it grows, on one scale from
            -- 1 unit of the screen height (0%) to 10 (100%).
            {id='.Size', label='Size', type='range',
                description='The size when it appears, and the size it grows to.',
                values={min=0,max=100,step=10,suffix='%',delta={10}}, default={30,80}},
            -- Opacity: the arrow's own opacity as it appears (low) and once it has
            -- travelled (high), animated over the travel; the cue adds none of its own.
            {id='.Opacity', label='Opacity', type='range',
                description='The opacity when it appears, and the opacity it reaches as it travels.',
                values={min=0,max=100,step=10,suffix='%',delta={10}}, default={50,70}},
            -- Travel: where the arrow's tip appears (low) and stops
            -- (high), as a share of the space the arrow has: 0% puts its back edge,
            -- at its starting size, on the cue's centre; 100% its tip on the screen edge.
            {id='.Travel', label='Travel', type='range',
                description='Where the arrow appears and how far it travels: 0% from the center, 100% to the screen edge.',
                values={min=0,max=100,step=5,suffix='%'}, default={40,60}},
            -- The arrow's two phases (preymonition.omens_render's phases): the yellow
            -- arrow before the Perfect Opportunity window, then the red arrow taking over.
            {id='.Incoming', label='Attack Incoming',
                values={{key='normal',label='Normal'},{key='faint',label='Faint'},{key='off',label='Off'}}, default='normal',
                description='How the Yellow arrow shows before the Perfect Opportunity window: normal, faint or off.'},
            {id='.Perfect', label='Perfect Opportunity',
                values={{key='end',label='End'},{key='start',label='Start'},{key='halfway',label='Halfway'},
                    {key='off',label='Off'}}, default='end',
                description='How the Perfect Opportunity arrow takes over: end (yellow runs its course first, red comes in at the end), start (yellow doesn\'t move), halfway (yellow moves 50%) or off.'},
        }},
        {id='Unblockable', label='Unblockable Attack Indicator', fields={
            -- Style: how an unblockable attack shows at the screen's centre.
            -- Off, then the pictures listed from images/unblockable_*.png each time the
            -- menu opens, saved by name.
            {id='.Style', label='Style', values={{key='off',label='Off'},{from='choices/unblockable_style.lua'}}, default='fiend',
                description='The picture shown at the center for an unblockable attack.'},
            -- Size: the skull's starting (low) and grown (high) size, from 1 unit of
            -- 5% of the screen height (0%) to the full screen height (100%).
            {id='.Size', label='Size', type='range',
                description='The size when it appears, and the size it grows to.',
                values={min=0,max=100,step=10,suffix='%'}, default={60,100}},
            -- Opacity: the picture's opacity as it appears (low) and once grown
            -- (high), animated with Size.
            {id='.Opacity', label='Opacity', type='range',
                description='The opacity when it appears, and the opacity it reaches as it grows.',
                values={min=0,max=100,step=10,suffix='%',delta={10}}, default={50,80}},
        }},
    },
}

log.debug('template loaded; level ',log.level)

template.attach=function(objects,params,original)
    Session.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
