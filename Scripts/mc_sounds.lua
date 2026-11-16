-- MCT loads this file with its folder on package.path.
local log=require('preymonition.logging').new('Preymonition Sounds')
local Sounds=require('preymonition.sounds')
local Sound=require('preymonition.sound')
Sounds.setLog(log)

-- The Sound Cues: a sound for each attack, played whatever the omens, the
-- screen edges or the other templates show, or with none of them on.
local template={
    id='Sounds',
    label='Sound Cues',
    description='Play a sound when an attack comes: as its parry window opens, as its perfect opportunity window opens, and for an unblockable attack.',
    category='npc.attacks',
    -- After the countdown (12). Priorities set the attach order only; the menu
    -- lists templates in the order main.lua registers them.
    priority=13,
    -- ModCore Templates' live preview on the module page. With its sound button on
    -- auto, the preview sounds while a Sound Notifications setting is selected.
    preview={sound='Sound'},
    -- Nothing is drawn: MCT attaches the sounds with the game's HUD, once the
    -- player is in the game.
    objects={hud={}},
    -- Awake during combat; MC_NPCAttackIndicator arrives as update.
    events={
        wake=function() Sounds.wake() end,
        sleep=function() Sounds.sleep() end,
        update=function(_,event) Sounds.update(event) end,
    },
    menu={
        -- Sound Notifications: a sound when the parry window opens (the yellow
        -- arrow), when the perfect opportunity window opens (the red arrow), and when
        -- an unblockable attack comes: the mod's own sounds, listed from
        -- sounds/cue_*.wav and sounds/unblockable_*.wav each time the menu opens,
        -- played through UE4SSLuaSoundBridge. Directional sound pans a side attack's
        -- sound to the side its arrow shows on and sets ahead and behind apart by
        -- pitch, behind also muffled.
        {id='Sound', label='Sound Notifications', fields={
            {id='.Incoming', label='Attack incoming', values=Sound.ARROW_CHOICES, default='rumble',
                description='Played when the parry window opens (the yellow arrow). The sounds are the files in the mod\'s sounds folder, which needs UE4SS Lua Sound Bridge.'},
            {id='.Perfect', label='Perfect opportunity', values=Sound.ARROW_CHOICES, default='ding',
                description='Played when the perfect opportunity window opens (the red arrow). The sounds are the files in the mod\'s sounds folder, which needs UE4SS Lua Sound Bridge.'},
            {id='.Unblockable', label='Unblockable Attack', values=Sound.UNBLOCKABLE_CHOICES, default='growl',
                description='Played when the unblockable indicator shows up. The sounds are the unblockable files in the mod\'s sounds folder, which needs UE4SS Lua Sound Bridge.'},
            {id='.Directional', label='Enable directional sound', values={[0]='Off',[1]='On'}, widget='switch', default=1,
                description='Play the arrow sounds on the side the arrow shows on, and set ahead and behind apart by pitch.'},
            {id='.Pitch', label='Differentiate back/front by pitch', type='range',
                values={min=-50,max=50,step=5,suffix='%'}, default={-20,20},
                conditions={visible={field='.Directional',values={1}}},
                description='How much lower an arrow from behind (low) and higher one from ahead (high) sounds, from as recorded. An arrow from behind is also muffled.'},
            {id='.Volume', label='Sound volume', values={min=0,max=200,step=10,suffix='%'}, default=100,
                description='How loud these sounds play, relative to the game\'s Effects volume (and Master volume): 100% follows them as set.'},
        }},
    },
}

log.debug('template loaded; level ',log.level)

template.attach=function(objects,params,original)
    Sounds.attach(objects.hud,params,assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
