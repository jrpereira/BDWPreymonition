-- MCT loads this file with its folder on package.path.
local source=assert(debug.getinfo(1,'S').source:match('^@(.+)$'))
local folder=assert(source:match('^(.*)[/\\][^/\\]+$'))
local root=folder:match('^(.*)[/\\][^/\\]+$') or '.'

-- Loaded by path: MCT's Scripts come first on package.path, so a require finds MCT's copy.
local Log=assert(loadfile(folder..'/vendor/mc_log.lua'))()
-- The level comes from log_level.txt in the mod folder; WARN without it.
local log=Log.new({name='Preymonition',path=root..'/log_level.txt'})
local Session=require('preymonition.session')
local Sound=require('preymonition.sound')
Session.setLog(log)

local ON_OFF={[0]='Off',[1]='On'}
local PERCENT={min=50,max=200,step=10,suffix='%'}

local template={
    name='Preymonition',
    description='Repeat the incoming attack direction just below the center of the screen.',

    category='player.notifications',
    -- MCT creates the cue layer on the HUD. The session builds the shield inside
    -- it and follows the game's attack indicator through its own native hooks.
    objects={hud={},cue={}},
    -- Percentages scale the current look; 100% is unchanged.
    menu={
        {id='Cue', label='Visuals', level=2, fields={
            {id='.S', label='Size', values={[15]='Small',[20]='Standard',[25]='Large'}, default=20},
        }},
        {id='Background', label='Background', level=3, fields={
            {id='.Shield', label='Show background shield', values=ON_OFF, default=0},
        }},
        {id='Arrows', label='Parry & Block Indicator', level=3, fields={
            {id='.Move', label='Arrow Movement', values=PERCENT, default=100},
            {id='.Size', label='Arrow Size', values=PERCENT, default=100},
            {id='.Glow', label='Show trailing glow', values=ON_OFF, default=1},
            {id='.Sound', label='Play sound', values=Sound.ARROW_LABELS, default=0},
        }},
        {id='Unblockable', label='Unblockable Attack', level=3, fields={
            {id='.Size', label='Unblockable size', values=PERCENT, default=100},
            {id='.Sound', label='Play sound', values=Sound.UNBLOCKABLE_LABELS, default=0},
        }},
    },
}

-- Developer aid: a preview.txt next to mod.json keeps the cue on screen.
local marker=io.open(root..'/preview.txt','r')
if marker then marker:close() end
template.preview=marker~=nil
log.debug('template loaded; level ',log.level,', preview ',template.preview)

template.loaded=Session.loaded

template.attach=function(objects,params,original)
    Session.attach(objects.hud,objects.cue,params,
        assert(params.onCleanup,'managed cleanup unavailable'),template.preview)
    return original
end

return template
