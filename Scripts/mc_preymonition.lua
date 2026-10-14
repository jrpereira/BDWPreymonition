-- MCT loads this file with its folder on package.path.
local source=assert(debug.getinfo(1,'S').source:match('^@(.+)$'))
local folder=assert(source:match('^(.*)[/\\][^/\\]+$'))
local root=folder:match('^(.*)[/\\][^/\\]+$') or '.'

-- Loaded by path: MCT's Scripts come first on package.path, so a require finds MCT's copy.
local Log=assert(loadfile(folder..'/vendor/mc_log.lua'))()
-- The level comes from log_level.txt in the mod folder; WARN without it.
local log=Log.new({name='Preymonition',path=root..'/log_level.txt'})
-- Developer aid: a probe.txt next to mod.json logs the game's attack calls,
-- with the cue's own events at DEBUG or finer beside them.
local probe=io.open(root..'/probe.txt','r')
if probe then
    probe:close()
    if not log.enabled('DEBUG') then log=Log.new({name='Preymonition',level='DEBUG'}) end
end
local Session=require('preymonition.session')
local Probe=probe and require('preymonition.probe')
-- Developer aid: an acceptance.txt next to mod.json logs detections and the
-- event bridge's indicator hook side by side (preymonition/acceptance.lua).
local acceptance=io.open(root..'/acceptance.txt','r')
if acceptance then acceptance:close() end
local Acceptance=acceptance and require('preymonition.acceptance')
local Sound=require('preymonition.sound')
Session.setLog(log)

local PERCENT={min=50,max=200,step=10,suffix='%'}

local template={
    name='Preymonition',
    description='Repeat the incoming attack direction just below the center of the screen.',

    category='npc.attacks',
    
    -- MCT creates the cue layer on the HUD. The session builds the shield inside
    -- it and follows the game's attack indicator through its own native hook.
    objects={hud={},cue={}},
    -- npc.attacks wakes its templates when combat starts and puts them to sleep
    -- when it ends; the session hooks the indicator only in between.
    events={
        wake=function()
            -- Blueprint probe hooks may only be found once combat has loaded them.
            if Probe then Probe.start(log) end
            if Acceptance then Acceptance.start(log) end
            Session.wake()
        end,
        sleep=function() Session.sleep() end,
    },
    -- Percentages scale the current look; 100% is unchanged.
    menu={
        {id='Parry', label='Parry & Block', fields={
            {id='.Style', label='Indicator Style', values={[0]='Off',[1]='Arrows',[2]='Glow'}, default=1},
            {id='.Size', label='Size', values=PERCENT, default=100},
            {id='.Movement', label='Indicator Movement', values=PERCENT, default=100},
            {id='.Trail', label='Trailing effect', values={[0]='Off',[1]='Glow',[2]='Fade'}, default=1},
            {id='.Edges', label='Screen Edge Effect', values={[0]='Off',[1]='Frame',[2]='Directional'}, default=0},
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.ARROW_LABELS,Sound.ARROW), default=0},
        }},
        {id='Unblockable', label='Unblockable Attack', fields={
            {id='.Size', label='Unblockable size', values=PERCENT, default=100},
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.UNBLOCKABLE_LABELS,Sound.UNBLOCKABLE), default=0},
        }},
        -- Sizes are shares of the shorter screen side: -30%, +0%, +30%, +60% and
        -- +100% of the original 20%.
        {id='Shield', label='Shield Indicator', fields={
            {id='.Display', label='Display Shield',
                values={[0]='Off',[1]='In Combat',[2]='Defending',[3]='Opportunity'}, default=0},
            {id='.Size', label='Size',
                values={[14]='Smaller',[20]='Small',[26]='Average',[32]='Large',[40]='Larger'}, default=20},
        }},
    },
}

-- Developer aid: a preview.txt next to mod.json keeps the cue on screen.
local marker=io.open(root..'/preview.txt','r')
if marker then marker:close() end
template.preview=marker~=nil
log.debug('template loaded; level ',log.level,', preview ',template.preview,', probe ',probe~=nil,
    ', acceptance ',acceptance~=nil)
if Probe then Probe.start(log) end
if Acceptance then Acceptance.start(log) end

template.attach=function(objects,params,original)
    Session.attach(objects.hud,objects.cue,params,
        assert(params.onCleanup,'managed cleanup unavailable'),template.preview)
    return original
end

return template
