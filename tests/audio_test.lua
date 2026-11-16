-- The Audio Cues template: MC_NPCAttackIndicator events play the mod's own sounds
-- through UE4SSLuaSoundBridge, whatever the other templates show. Attack incoming
-- plays when an attack is first seen (its parry window opens, the yellow arrow),
-- Perfect Opportunity when its Perfect Opportunity window opens (the red arrow),
-- and Unblockable Attack, centred, for an unblockable attack.
package.path='Preymonition/Scripts/?.lua;ModCoreTemplates/Scripts/?.lua;'..package.path

-- The sounds name Preymonition's own folder: the Sound Bridge would resolve a bare
-- relative path against ModCore Templates', whose Lua state runs this code. The
-- test loads from a relative source, so the path goes up from the caller's folder.
local ROOT='../Preymonition'
-- Each load and play is recorded, and a missing file is refused as the bridge
-- refuses it.
local loads,plays,missingFiles={},{},{}
local function soundBridge()
    return setmetatable({GetCapabilities=function() return {api=1,paths='any'} end},{__call=function()
        return {Load=function(path,options)
            assert(options.max_seconds==3,'sounds are kept short')
            loads[#loads+1]=path
            if missingFiles[path] then return nil,'not_found','missing' end
            return {path=path,Play=function(_,how) plays[#plays+1]=how; how.path=path; return #plays end}
        end}
    end})
end
UE4SSLuaSoundBridge=soundBridge()
-- The game's Master and Effects volume (0 to 100) and its Mute switch.
local gameAudio={[1]=100,[3]=100,mute=false}
local userSettings={}
function userSettings:IsValid() return true end
function userSettings:GetSetting(id,out) out.OutSettingValue=gameAudio[id]; return gameAudio[id]~=nil end
function userSettings:GetSettingAsBool(_,out) out.OutSettingBool=gameAudio.mute; return true end
FindFirstOf=function(class) return class=='RebelGameUserSettings' and userSettings or nil end
-- The Audio Cues never defer work and draw nothing.
ExecuteWithDelay=function() error('the audio cues defer nothing') end
StaticConstructObject=function() error('the audio cues draw nothing') end

local template=dofile('Preymonition/Scripts/mc_audio.lua')
assert(template.id=='Audio' and template.label=='Audio Cues' and template.category=='npc.attacks')
assert(template.objects.hud and template.objects.cue==nil,'the HUD alone: no layer')
assert(template.preview.sound==true and template.preview.background==nil and template.defaultEnabled==true,
    'on by default; the preview sounds while any Audio Cues setting is selected; the Omens give its picture')
assert(not template.description:find(';',1,true),'no semicolons in the description')

local hud={}
local cleanups={}
local function detachAll()
    for index=#cleanups,1,-1 do cleanups[index]() end
    cleanups={}
end
local function attach(settings,preview)
    template.attach({hud=hud},{settings=settings or {},preview=preview,
        onCleanup=function(callback) cleanups[#cleanups+1]=callback end},{})
end
local function update(event) template.events.update({},event) end
local function wake() template.events.wake({},{name='wake'}) end
local function sleep() template.events.sleep({},{name='sleep'}) end
-- The game's icon directions: 1 top (ahead), 2 bottom (behind), 3 left, 4 right.
local TOP,BOTTOM,LEFT,RIGHT=1,2,3,4
local PATH='/Game/HUD.Indicator'
local function arrow(direction,path) update({kind='arrow',direction=direction,path=path or PATH}) end
local function critical(direction,path) update({kind='critical',direction=direction,path=path or PATH}) end
local function resolve(path) update({kind='resolve',reason='sword',path=path or PATH}) end
-- The files played since a mark, by name.
local function played(from)
    local out={}
    for index=from+1,#plays do out[#out+1]=plays[index].path:match('([%w_]+)%.wav$') end
    return table.concat(out,' ')
end

-- MCT passes the defaults, Rumble, Ding and Growl: loaded at attach, nothing
-- played yet. With no setting at all nothing is chosen.
attach({})
assert(#loads==0,'no setting, no sound')
detachAll()
attach({SoundIncoming='rumble',SoundPerfect='ding',SoundUnblockable='growl'})
assert(#loads==3,'the chosen sounds load at attach')
local loaded={}
for _,path in ipairs(loads) do loaded[path]=true end
assert(loaded[ROOT..'/sounds/cue_rumble.wav'] and loaded[ROOT..'/sounds/cue_ding.wav']
    and loaded[ROOT..'/sounds/unblockable_growl.wav'],'Rumble, Ding and Growl by default')
arrow(LEFT)
assert(#plays==0,'nothing plays outside combat')
wake()

-- An attack: Attack incoming when it is first seen, Perfect Opportunity when its
-- Perfect Opportunity window opens, each once; whatever the Omens' Attack Incoming and Perfect Opportunity.
local mark=#plays
arrow(BOTTOM)
assert(played(mark)=='cue_rumble','Attack incoming plays on the first arrow')
arrow(BOTTOM)
assert(played(mark)=='cue_rumble','a repeated arrow does not replay it')
critical(BOTTOM)
assert(played(mark)=='cue_rumble cue_ding','Perfect Opportunity plays when it goes critical')
critical(BOTTOM)
arrow(BOTTOM)
assert(played(mark)=='cue_rumble cue_ding','repeated events for the same attack replay nothing')
resolve('/Game/HUD.Other')
arrow(BOTTOM)
assert(played(mark)=='cue_rumble cue_ding','another indicator\'s resolve forgets nothing')
resolve()
arrow(BOTTOM)
assert(played(mark)=='cue_rumble cue_ding cue_rumble','after its resolve the next attack plays again')
-- A new direction on the same indicator is a new attack.
arrow(TOP)
assert(played(mark)=='cue_rumble cue_ding cue_rumble cue_rumble','a new direction is a new attack')
resolve()
-- The same direction reported again from another indicator while the first is open
-- is the same attack: no second sound, and it stays open until both resolve.
mark=#plays
local OTHER='/Game/HUD.Second'
arrow(LEFT)
critical(LEFT,OTHER)
assert(played(mark)=='cue_rumble cue_ding','a same-direction repeat is the open attack: it only goes critical')
arrow(LEFT,OTHER)
critical(LEFT)
assert(played(mark)=='cue_rumble cue_ding','and plays nothing more')
resolve()
arrow(LEFT,OTHER)
assert(played(mark)=='cue_rumble cue_ding','still open while the other indicator has not resolved')
resolve(OTHER)
arrow(LEFT)
assert(played(mark)=='cue_rumble cue_ding cue_rumble','once all resolve, the next attack plays')
resolve()
-- An attack first seen critical plays only Perfect Opportunity.
mark=#plays
critical(RIGHT)
assert(played(mark)=='cue_ding','first seen critical: only Perfect Opportunity')
arrow(RIGHT)
assert(played(mark)=='cue_ding','and its arrow plays nothing after it')
resolve()
-- An unblockable attack plays its sound centred, once until it goes.
mark=#plays
update({kind='unblockable',active=true,path=PATH})
update({kind='unblockable',active=true,path=PATH})
assert(played(mark)=='unblockable_growl' and plays[#plays].pan==nil and plays[#plays].pitch==nil
    and plays[#plays].lowpass==nil,'Unblockable Attack plays once, centred')
update({kind='unblockable',active=false,path=PATH})
update({kind='unblockable',active=true,path=PATH})
assert(played(mark)=='unblockable_growl unblockable_growl','and again for the next one')
-- Combat end forgets the attacks.
arrow(LEFT)
sleep()
wake()
mark=#plays
arrow(LEFT)
update({kind='unblockable',active=true,path=PATH})
assert(played(mark)=='cue_rumble unblockable_growl','combat end forgets the attack and the skull')
sleep()

-- With directional sound on (the default) a side arrow pans to the side it shows
-- on (the game's left arrow shows on the right), a top arrow plays at the front
-- pitch and a bottom one at the back pitch, muffled.
local function soundCue(settings)
    detachAll()
    attach(settings)
    sleep()
    wake()
end
local function cueSound(direction)
    local from=#plays
    arrow(direction)
    resolve()
    local out={}
    for index=from+1,#plays do
        local how=plays[index]
        out[#out+1]=string.format('%s/%s/%s/%s',how.pan or '-',how.pitch or '-',how.lowpass or '-',how.volume)
    end
    return table.concat(out,' ')
end
loads={}
soundCue({SoundIncoming='ping',SoundPerfect='none',SoundUnblockable='none',OptionsVolume=150})
assert(#loads==1 and loads[1]==ROOT..'/sounds/cue_ping.wav','only the chosen sound loads; None loads nothing')
assert(cueSound(LEFT)=='1/-/-/1.5','the game\'s left arrow pans right, at its volume')
assert(cueSound(RIGHT)=='-1/-/-/1.5','and its right arrow left')
assert(cueSound(TOP)=='-/1.2/-/1.5','a top arrow plays 20% higher by default')
assert(cueSound(BOTTOM)=='-/0.8/1200/1.5','a bottom arrow 20% lower and muffled, once')
assert(#loads==1,'no reload')
-- Differentiate back/front by pitch sets both pitches.
soundCue({SoundIncoming='ping',OptionsPitch={-35,10}})
assert(cueSound(TOP)=='-/1.1/-/1.0' and cueSound(BOTTOM)=='-/0.65/1200/1.0','the chosen pitches')
-- Directional sound off: every arrow plays as recorded, centred.
soundCue({SoundIncoming='ping',OptionsDirectional=0,OptionsPitch={-35,10}})
assert(cueSound(LEFT)=='-/-/-/1.0' and cueSound(TOP)=='-/-/-/1.0' and cueSound(BOTTOM)=='-/-/-/1.0',
    'without directional sound the arrows play alike')
-- The game's Master and Effects volume scale the sounds, read when combat
-- starts; muted, they are silent. Unreadable, the last value stays.
gameAudio[1],gameAudio[3]=80,50
soundCue({SoundIncoming='ping',OptionsDirectional=0,OptionsVolume=150})
assert(cueSound(TOP)=='-/-/-/0.6','Sound volume times the game\'s Master and Effects volume')
gameAudio.mute=true
soundCue({SoundIncoming='ping',OptionsDirectional=0})
assert(cueSound(TOP)=='-/-/-/0.0','silent while the game is muted')
gameAudio.mute,gameAudio[3]=false,nil
soundCue({SoundIncoming='ping',OptionsDirectional=0})
assert(cueSound(TOP)=='-/-/-/0.0','an unreadable volume keeps the last one read')
gameAudio[3]=100
soundCue({SoundIncoming='ping',OptionsDirectional=0})
assert(cueSound(TOP)=='-/-/-/0.8','and a readable one replaces it')
gameAudio[1]=100
-- The Omens' Attack Incoming and Perfect Opportunity change nothing here: a
-- held, hidden yellow arrow
-- still plays Attack incoming as the attack is first seen.
soundCue({SoundIncoming='ping',SoundPerfect='ding',ParryIncoming='off',ParryPerfect='start',ParryStyle='off'})
mark=#plays
arrow(BOTTOM)
critical(BOTTOM)
resolve()
assert(played(mark)=='cue_ping cue_ding','Attack incoming and Perfect Opportunity whatever the Omens show')
-- A sound whose file is gone plays nothing.
missingFiles[ROOT..'/sounds/cue_gone_file.wav']=true
soundCue({SoundIncoming='gone_file'})
assert(cueSound(LEFT)=='' and cueSound(RIGHT)=='','a sound that did not load plays nothing')
-- Without the bridge, neither.
UE4SSLuaSoundBridge=nil
soundCue({SoundIncoming='knock'})
assert(cueSound(LEFT)=='','without the sound bridge nothing plays')
UE4SSLuaSoundBridge=soundBridge()
-- A play the bridge refuses is reported once and stops nothing.
local Audio=require('preymonition.audio')
local warned=0
local logger={enabled=function() return false end}
for _,level in ipairs({'trace','debug','info','error','critical'}) do logger[level]=function() end end
logger.warn=function() warned=warned+1 end
Audio.setLog(logger)
soundCue({SoundIncoming='ping'})
local Sound=require('preymonition.sound')
local play=Sound.play
Sound.play=function() error('refused') end
cueSound(LEFT)
cueSound(RIGHT)
assert(warned==1,'a refused sound warns once')
Sound.play=play
assert(cueSound(LEFT)=='1/-/-/1.0','and plays again once the bridge takes it')

-- A live preview (ModCore Templates in the mod menu): attached with params.preview,
-- it plays without combat; preview events reach only it, game events only the
-- HUD's. A silent preview event (sound button off, or no sound setting selected)
-- plays nothing.
sleep()
detachAll()
attach({SoundIncoming='ping',SoundPerfect='ding'})
attach({SoundIncoming='bell',SoundPerfect='clink'},true)
mark=#plays
update({kind='arrow',direction=LEFT,path='preview:1:1',preview=true})
update({kind='critical',direction=LEFT,path='preview:1:1',preview=true})
assert(played(mark)=='cue_bell cue_clink','a preview event plays without combat, only on the preview')
update({kind='resolve',reason='sword',path='preview:1:1',preview=true})
update({kind='arrow',direction=RIGHT,path='preview:1:2',preview=true,silent=true})
update({kind='critical',direction=RIGHT,path='preview:1:2',preview=true,silent=true})
update({kind='unblockable',active=true,path='preview:1:5',preview=true,silent=true})
assert(played(mark)=='cue_bell cue_clink','a silent preview event plays nothing')
update({kind='resolve',reason='sword',path='preview:1:2',preview=true})
update({kind='arrow',direction=TOP,path='preview:2:1',preview=true})
assert(played(mark)=='cue_bell cue_clink cue_bell','a sounding one plays again')
wake()
arrow(LEFT)
assert(played(mark)=='cue_bell cue_clink cue_bell cue_ping','a game event reaches only the HUD\'s')
resolve()
sleep()

-- Sounds: Attack incoming and Perfect Opportunity offer None and the cue sounds
-- listed from the sounds folder, with no notes; then the unblockable sounds.
-- Options: directional sound and its pitches, and the volume.
local groups,groupOrder={},{}
for _,entry in ipairs(template.menu) do groups[entry.id]=entry; groupOrder[#groupOrder+1]=entry.id end
assert(table.concat(groupOrder,' ')=='Sound Options','Sounds, then Options')
local soundGroup,optionsGroup=groups.Sound,groups.Options
local function rows(group)
    local fields,order={},{}
    for _,field in ipairs(group.fields) do fields[field.id]=field; order[#order+1]=field.id end
    return fields,table.concat(order,' ')
end
local soundFields,soundOrder=rows(soundGroup)
local optionFields,optionOrder=rows(optionsGroup)
assert(soundOrder=='.Incoming .Perfect .Unblockable','the three sound rows in order')
assert(optionsGroup.label=='Options' and optionOrder=='.Directional .Pitch .Volume','the three option rows in order')
local incoming,perfectField,skullField=soundFields['.Incoming'],soundFields['.Perfect'],soundFields['.Unblockable']
assert(soundGroup.label=='Sounds' and incoming.label=='Attack incoming'
    and perfectField.label=='Perfect Opportunity' and skullField.label=='Unblockable Attack','the three pickers')
assert(incoming.values==perfectField.values and incoming.default=='rumble' and perfectField.default=='ding',
    'the same keyed options; Rumble and Ding by default')
assert(#incoming.values==2 and incoming.values[1].key=='none' and incoming.values[1].note==nil
    and incoming.values[2].from=='choices/cue_sounds.lua','None, then the listed cue sounds')
assert(skullField.default=='growl' and #skullField.values==2 and skullField.values[1].key=='none'
    and skullField.values[2].from=='choices/unblockable_sounds.lua','None, then the listed unblockable sounds; Growl by default')
assert(optionFields['.Directional'].default==1 and optionFields['.Directional'].widget=='switch','directional on by default')
local pitch=optionFields['.Pitch']
assert(pitch.type=='range' and pitch.values.min==-50 and pitch.values.max==50 and pitch.default[1]==-20 and pitch.default[2]==20
    and pitch.conditions.visible.field=='.Directional','pitch from -50% to 50%, -20% and 20% by default, with directional sound')
assert(optionFields['.Volume'].default==100 and optionFields['.Volume'].label=='Sound volume','sounds play as recorded by default')

detachAll()
wake()
mark=#plays
arrow(LEFT)
assert(#plays==mark,'detached, nothing plays')
sleep()
print('PASS: the Audio Cues play Attack incoming, Perfect Opportunity and Unblockable Attack once per attack, directional, in preview and in combat')
