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
    name='Center',
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
        -- Scale resizes the shield only: 0% is 40% of the shorter screen side.
        {id='General', label='General Options', fields={
            {id='.Scale', label='Scale', values={min=-50,max=200,step=10,suffix='%'}, default=0},
            {id='.Position', label='Position', values={[0]='Below',[1]='Middle',[2]='Above'}, default=1},
            {id='.Shield', label='Display Shield',
                values={[0]='Off',[1]='In Combat',[2]='Defending',[3]='Opportunity'}, default=0},
        }},
        {id='Parry', label='Parry & Block', fields={
            {id='.Style', label='Indicator Style', values={[0]='Off',[1]='Arrows',[2]='Glow'}, default=1},
            {id='.Size', label='Size', values=PERCENT, default=100},
            {id='.Movement', label='Indicator Movement', values=PERCENT, default=100},
            {id='.Trail', label='Trailing effect', values={[0]='Off',[1]='Glow',[2]='Fade'}, default=1},
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.ARROW_LABELS,Sound.ARROW), default=0},
        }},
        {id='Unblockable', label='Unblockable Attack', fields={
            {id='.Size', label='Unblockable size', values=PERCENT, default=100},
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.UNBLOCKABLE_LABELS,Sound.UNBLOCKABLE), default=0},
        }},
    },
}

log.debug('template loaded; level ',log.level)

template.attach=function(objects,params,original)
    Session.attach(objects.hud,objects.cue,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
