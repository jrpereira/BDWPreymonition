-- MCT loads this file with its folder on package.path.
local Logging=require('preymonition.logging')
local log=Logging.new('Preymonition')
local Session=require('preymonition.omens')
Session.setLog(log)

-- The omens: the incoming attack shown as symbols, an arrow for its direction,
-- centred where the Background template draws its shield at the arrows'
-- Position, or a picture at the screen's centre, a skull by default, when it
-- cannot be blocked. The shield, the screen edges, the countdown and the sounds
-- are templates of their own (mc_background.lua, mc_edges.lua, mc_countdown.lua,
-- mc_sounds.lua).
local template={
    id='Omens',
    label='Omens',
    description='Show the incoming attack as symbols: an arrow for its direction, or a picture when it cannot be blocked.',
    category='npc.attacks',
    -- Before the edges (11): MCT attaches, wakes and updates it first.
    priority=10,
    -- ModCore Templates' live preview on the module page, over this picture.
    preview={background='images/preview_unblockable.jpg'},
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
            {id='.Style', label='Style', values={{key='off',label='Off'},{key='solid',label='Solid'},{key='chevron',label='Chevron'},
                {key='perspective',label='Perspective'},{key='fancy',label='Fancy'}}, default='chevron',
                description='How the arrow is drawn. Perspective lays it flat on the ground around your character, and Fancy uses glowing painted arrows.'},
            {id='.Position', label='Position',
                values={{key='below',label='Below'},{key='middle',label='Middle'},{key='above',label='Above'}}, default='middle',
                description='Where the arrows show on the screen: low, in the middle, or high.'},
            -- Size: where the arrow starts and how large it grows, on one scale from
            -- 1 unit of the screen height (0%) to 10 (100%).
            {id='.Size', label='Size', type='range',
                description='Define the size of the indicator when it shows up, and the size it grows to.',
                values={min=0,max=100,step=10,suffix='%',delta={10}}, default={30,80}},
            -- Movement from Center: where the arrow's tip appears (low) and stops
            -- (high), as a share of the space the arrow has: 0% puts its back edge,
            -- at its starting size, on the cue's centre; 100% its tip on the screen edge.
            {id='.Movement', label='Movement from Center', type='range',
                description='Define where the indicator shows up, and how far it travels: at 0% its back edge is on the center, at 100% its tip reaches the screen edge.',
                values={min=0,max=100,step=5,suffix='%'}, default={40,60}},
            -- The buildup: the yellow arrow before the perfect opportunity window
            -- opens. Normal and Normal show and move it from the first sighting, and
            -- when the perfect opportunity window opens it jumps to its full size; any
            -- other pair holds it back, and that window carries its growth and travel
            -- on from where it was.
            {id='.BuildupVisibility', label='Buildup visibility',
                values={{key='hidden',label='Hidden'},{key='faint',label='Faint'},{key='normal',label='Normal'}}, default='normal',
                description='How the yellow arrow shows before the perfect opportunity window opens: not at all, see-through, or as usual.'},
            {id='.BuildupAnimation', label='Buildup animation',
                values={{key='static',label='Static'},{key='partial',label='Partial'},{key='normal',label='Normal'}}, default='normal',
                description='How the yellow arrow moves before the perfect opportunity window opens: it stays where it starts, grows and travels 30% of the way, or grows and travels as usual. At Normal it keeps going and grows to full size when that window opens.'},
        }},
        {id='Unblockable', label='Unblockable Attack Indicator', fields={
            -- Style: how an unblockable attack shows at the screen's centre.
            -- Off, then the pictures listed from images/unblockable_*.png each time the
            -- menu opens, saved by name.
            {id='.Style', label='Style', values={{key='off',label='Off'},{from='choices/unblockable_style.lua'}}, default='fiend',
                description='The picture an unblockable attack shows at the center of the screen, from the unblockable pictures in the mod\'s images folder.'},
            -- Size: the skull's starting (low) and grown (high) size, from 1 unit of
            -- 5% of the screen height (0%) to the full screen height (100%).
            {id='.Size', label='Size', type='range',
                description='Define the size of the indicator when it shows up, and the size it grows to.',
                values={min=0,max=100,step=10,suffix='%'}, default={60,100}},
        }},
    },
}

log.debug('template loaded; level ',log.level)

template.attach=function(objects,params,original)
    Session.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
