-- MCT loads this file with its folder on package.path.
local Logging=require('preymonition.logging')
local log=Logging.new('Preymonition')
local Session=require('preymonition.session')
local Sound=require('preymonition.sound')
Session.setLog(log)

local PERCENT={min=50,max=200,step=10,suffix='%'}

-- The center cue: the incoming attack's direction near the screen's center.
-- The screen edges are a template of their own (mc_edges.lua).
local template={
    id='Center',
    label='Center Overlay',
    description='Repeat the incoming attack direction near the center of the screen.',
    category='npc.attacks',
    -- Before the edges (11): MCT attaches, wakes and updates it first.
    priority=10,
    -- MCT creates the cue layer on the HUD. The session builds the shield inside
    -- it and follows the game's attack indicator through MCT's events.
    objects={hud={},cue={}},
    -- npc.attacks wakes its templates when combat starts and puts them to sleep
    -- when it ends; in between, MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Session.wake() end,
        sleep=function() Session.sleep() end,
        update=function(_,event) Session.update(event) end,
    },
    -- Percentages scale the current look; 100% is unchanged. Scale adds to it: 0% is unchanged.
    menu={
        {id='GeneralPosition', label='Position', values={[0]='Below',[1]='Middle',[2]='Above'}, default=1},
        {id='GeneralShield', label='Shield Visible',
            values={[0]='Off',[1]='In Combat',[2]='Defending',[3]='Critical'}, default=2},
        -- Scale resizes the shield only: 0% is 40% of the shorter screen side.
        {id='GeneralScale', label='Shield Scale', values={min=-50,max=200,step=10,suffix='%'}, default=0},
        {id='Parry', label='Parry & Block', fields={
            {id='.Style', label='Indicator Style', values={[0]='Off',[1]='Solid',[2]='Chevron',[3]='Perspective',[4]='Fancy'}, default=2},
            -- Indicator Size: where the arrow starts and how large it grows, on one scale from
            -- 1 unit of the screen height (0%) to 5 (100%).
            {id='.Size', label='Indicator Size', type='range',
                values={min=0,max=100,step=10,suffix='%',delta={10}}, default={10,50}},
            -- Movement: the share of the way from where the arrow appears to 35% of the screen.
            {id='.Movement', label='Indicator Movement', values={min=0,max=100,step=10,suffix='%'}, default=70},
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.ARROW_LABELS,Sound.ARROW), default=1},
        }},
        {id='Unblockable', label='Unblockable Attack', fields={
            {id='.Size', label='Indicator Size', values=PERCENT, default=120},
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.UNBLOCKABLE_LABELS,Sound.UNBLOCKABLE), default=1},
        }},
    },
}

log.debug('template loaded; level ',log.level)

template.attach=function(objects,params,original)
    Session.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
