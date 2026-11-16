-- MCT loads this file with its folder on package.path.
local log=require('preymonition.logging').new('Preymonition Audio')
local Audio=require('preymonition.audio')
local Sound=require('preymonition.sound')
Audio.setLog(log)

-- The Audio Cues: a sound for each attack, played whatever the omens, the
-- screen edges or the other templates show, or with none of them on.
local template={
    id='Audio',
    label='Audio Cues',
    description='Play a sound when an attack comes: as its parry window opens, as its Perfect Opportunity window opens, and for an unblockable attack.',
    category='npc.attacks',
    -- After the countdown (12). Priorities set the attach order only; the menu
    -- lists templates in the order main.lua registers them.
    priority=13,
    -- ModCore Templates' live preview on the module page. With its sound button on
    -- auto, the preview sounds while any Audio Cues setting is selected.
    preview={sound=true},
    -- On out of the box.
    defaultEnabled=true,
    -- Nothing is drawn: MCT attaches the sounds with the game's HUD, once the
    -- player is in the game.
    objects={hud={}},
    -- Awake during combat; MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Audio.wake() end,
        sleep=function() Audio.sleep() end,
        update=function(_,event) Audio.update(event) end,
    },
    menu={
        -- Sounds: a sound when the parry window opens (the yellow arrow), when the
        -- Perfect Opportunity window opens (the red arrow), and when an unblockable
        -- attack comes: the mod's own sounds, listed from sounds/cue_*.wav and
        -- sounds/unblockable_*.wav each time the menu opens, played through
        -- UE4SSLuaSoundBridge.
        {id='Sound', label='Sounds', fields={
            {id='.Incoming', label='Attack incoming', values=Sound.ARROW_CHOICES, default='rumble',
                description='Plays when the parry window opens (yellow arrow).'},
            {id='.Perfect', label='Perfect Opportunity', values=Sound.ARROW_CHOICES, default='ding',
                description='Plays when the Perfect Opportunity window opens (red arrow).'},
            {id='.Unblockable', label='Unblockable Attack', values=Sound.UNBLOCKABLE_CHOICES, default='growl',
                description='Plays when an unblockable attack shows.'},
        }},
        -- Options: directional sound pans a side attack's sound to the side its
        -- arrow shows on and sets ahead and behind apart by pitch, behind also
        -- muffled; and the volume of all three sounds.
        {id='Options', label='Options', fields={
            {id='.Directional', label='Enable directional sound', values={[0]='Off',[1]='On'}, widget='switch', default=1,
                description='Plays side attacks on their side, and sets ahead and behind apart by pitch.'},
            {id='.Pitch', label='Differentiate back/front by pitch', type='range',
                values={min=-50,max=50,step=5,suffix='%'}, default={-20,20},
                conditions={visible={field='.Directional',values={1}}},
                description='How much lower attacks from behind and higher attacks from ahead sound. Behind is also muffled.'},
            {id='.Volume', label='Sound volume', values={min=0,max=200,step=10,suffix='%'}, default=100,
                description='Loudness, relative to the game\'s Effects volume.'},
        }},
    },
}

log.debug('template loaded; level ',log.level)

template.attach=function(objects,params,original)
    Audio.attach(objects.hud,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
