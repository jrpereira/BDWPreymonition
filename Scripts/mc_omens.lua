-- MCT loads this file with its folder on package.path.
local Logging=require('preymonition.logging')
local log=Logging.new('Preymonition')
local Session=require('preymonition.omens')
local Sound=require('preymonition.omens_sound')
Session.setLog(log)

-- The omens: the incoming attack shown as symbols, an arrow for its direction
-- or a skull when it cannot be blocked, centred where the Background template
-- draws its shield. The shield, the screen edges and the countdown are
-- templates of their own (mc_background.lua, mc_edges.lua, mc_countdown.lua).
local template={
    id='Omens',
    label='Omens Overlay',
    description='Show the incoming attack as symbols: an arrow for its direction, or a skull when it cannot be blocked.',
    category='npc.attacks',
    -- Before the edges (11): MCT attaches, wakes and updates it first.
    priority=10,
    -- MCT creates the cue layer on the HUD. The session builds the arrows and
    -- the skull inside it and follows the game's attack indicator through MCT's events.
    objects={hud={},cue={}},
    -- npc.attacks wakes its templates when combat starts and puts them to sleep
    -- when it ends; in between, MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Session.wake() end,
        sleep=function() Session.sleep() end,
        update=function(_,event) Session.update(event) end,
    },
    menu={
        {id='GeneralPosition', label='Position', values={[0]='Below',[1]='Middle',[2]='Above'}, default=1,
            description='Where the omens show on the screen: low, in the middle, or high.'},
        {id='Parry', label='Parry & Block Indicator', fields={
            {id='.Style', label='Style', values={[0]='Off',[1]='Solid',[2]='Chevron',[3]='Perspective',[4]='Fancy'}, default=2,
                description='How the arrow is drawn. Perspective lays it flat on the ground around your character, and Fancy uses glowing painted arrows.'},
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
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.ARROW_LABELS,Sound.ARROW), default=1,
                description='The sound played at the attacker when an arrow shows up.'},
            -- Prioritize Perfection over Buildup: the arrow's animation belongs to
            -- the parry window, red; the buildup before it shows and moves as chosen.
            {id='.Perfection', label='Prioritize Perfection over Buildup', values={[0]='Off',[1]='On'}, default=0,
                widget='switch',
                description='The arrow animates, red, once the parry window opens. Before then the yellow buildup shows and moves as chosen below.'},
            {id='.BuildupVisibility', label='Buildup visibility', values={[0]='Hidden',[1]='Faint',[2]='Normal'}, default=0,
                conditions={visible={field='.Perfection', values={1}}},
                description='How the yellow arrow shows before the parry window opens: not at all, see-through, or as usual.'},
            {id='.BuildupAnimation', label='Buildup animation', values={[0]='Static',[1]='Partial',[2]='Normal'}, default=0,
                conditions={visible={field='.Perfection', values={1}}},
                description='How the yellow arrow moves before the parry window opens: it stays where it starts, grows and travels 30% of the way, or grows and travels as usual. The parry window carries it on from there.'},
        }},
        {id='Unblockable', label='Unblockable Attack Indicator', fields={
            -- Size: the skull's starting (low) and grown (high) size, from 1 unit of
            -- 5% of the screen height (0%) to the full screen height (100%).
            {id='.Size', label='Size', type='range',
                description='Define the size of the indicator when it shows up, and the size it grows to.',
                values={min=0,max=100,step=10,suffix='%'}, default={60,100}},
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.UNBLOCKABLE_LABELS,Sound.UNBLOCKABLE), default=1,
                description='The sound played at the attacker when the skull shows up.'},
        }},
    },
}

log.debug('template loaded; level ',log.level)

template.attach=function(objects,params,original)
    Session.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
