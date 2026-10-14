-- MCT loads this file with its folder on package.path.
local source=assert(debug.getinfo(1,'S').source:match('^@(.+)$'))
local folder=assert(source:match('^(.*)[/\\][^/\\]+$'))
local root=folder:match('^(.*)[/\\][^/\\]+$') or '.'

-- Loaded by path: MCT's Scripts come first on package.path, so a require finds MCT's copy.
local Log=assert(loadfile(folder..'/vendor/mc_log.lua'))()
-- The level comes from log_level.txt in the mod folder; WARN without it.
local log=Log.new({name='Preymonition',path=root..'/log_level.txt'})
-- Developer aid: a probe.txt next to mod.json logs the game's attack-warning
-- calls and the indicator's attack queue, with the cue's own events at DEBUG or
-- finer beside them.
local probe=io.open(root..'/probe.txt','r')
if probe then
    probe:close()
    if not log.enabled('DEBUG') then log=Log.new({name='Preymonition',level='DEBUG'}) end
end
local Session=require('preymonition.session')
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
        wake=function() Session.wake() end,
        sleep=function() Session.sleep() end,
    },
    -- Percentages scale the current look; 100% is unchanged.
    -- Template menus are flat; level 3 sets the two subgroups under Parry & Block.
    menu={
        {id='Parry', label='Parry & Block', fields={
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.ARROW_LABELS,Sound.ARROW), default=0},
        }},
        {id='Overlay', label='Character Overlay Indicator', level=3, fields={
            {id='.Style', label='Style', values={[0]='Off',[1]='Arrows',[2]='Glow'}, default=1},
            {id='.Scaling', label='Scaling', values=PERCENT, default=100},
            {id='.Amplitude', label='Amplitude', values=PERCENT, default=100},
            {id='.Trail', label='Trailing effect', values={[0]='Off',[1]='Glow',[2]='Fade'}, default=1},
        }},
        {id='Edge', label='Screen Edge Effects', level=3, fields={
            {id='.Behaviour', label='Behaviour', values={[0]='Off',[1]='Frame',[2]='Directional'}, default=0},
        }},
        {id='Unblockable', label='Unblockable Attack', fields={
            {id='.Size', label='Unblockable size', values=PERCENT, default=100},
            {id='.Sound', label='Play sound', values=Sound.choices(Sound.UNBLOCKABLE_LABELS,Sound.UNBLOCKABLE), default=0},
        }},
        {id='Background', label='Background', fields={
            {id='.Size', label='Size', values={[15]='Small',[20]='Standard',[25]='Large'}, default=20},
            {id='.Shield', label='Shield watermark', values={[0]='Off',[1]='Static',[2]='Dynamic'}, default=0},
        }},
    },
}

-- Developer aid: a preview.txt next to mod.json keeps the cue on screen.
local marker=io.open(root..'/preview.txt','r')
if marker then marker:close() end
template.preview=marker~=nil
log.debug('template loaded; level ',log.level,', preview ',template.preview,', probe ',probe~=nil)
if probe then
    local Probe=require('preymonition.probe')
    Probe.start(log)
    Session.setObserver(function(indicator,event) Probe.queue(log,indicator,event) end)
end

template.attach=function(objects,params,original)
    Session.attach(objects.hud,objects.cue,params,
        assert(params.onCleanup,'managed cleanup unavailable'),template.preview)
    return original
end

return template
