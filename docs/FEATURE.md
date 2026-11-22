# Directional cue behavior

Preymonition registers four managed MCT templates in `npc.attacks`, listed on
the settings page in this order: **Omens Overlay** (`mc_omens.lua`), the attack shown as
symbols, the cue, **Audio Cues** (`mc_audio.lua`), a sound for each attack,
**Edges Flash** (`mc_edges.lua`), the screen edge glows, and **Countdown**
(`mc_countdown.lua`), a count to the Perfect Opportunity window. Each is turned
on by its own Enabled, so any of them, the Audio Cues alone included, can be on
without the others. MCT attaches them by priority (Omens 10, Edges 11,
Countdown 12, Audio Cues 13).
The category attaches them once the player is in the game (`MC_PlayerReady`)
and supplies each the HUD (`hud`) and, to each template that draws, its own
full-screen overlay created on the HUD root (`cue`), so they never share or clear
each other's layer. The Audio Cues draw nothing and take the HUD alone. Each takes
MCT's `MC_NPCAttackIndicator` events on their own.

An attack has two windows. Its parry window opens when it is first shown (the
`arrow` event, the yellow arrow); its Perfect Opportunity window opens later (the
`critical` event, the red arrow). The game's own "parry window multiplier" is a
difficulty timing value, used below for the animation pace.

## The omens

Its requests (`preymonition/omens.lua`) follow the attack, its timeline
(`preymonition/omens_animation.lua`) animates it and its renderer
(`preymonition/omens_render.lua`, with `omens_fancy.lua` for the arrows) draws
it. The parry window multiplier, the attacker and the clock
come from `preymonition/combat.lua`, shared with the countdown.

`attach` builds the cue in that layer: a size box at the arrows' Position with an
overlay of four arrows, each its Style's picture, and a
second box at the screen's centre with the unblockable picture. That picture is
the Unblockable Style's file from the mod's `images` folder, the only one loaded,
set on the image when the cue attaches and kept clear until an unblockable attack.
Every Style but Off (Solid, Chevron, Fancy and any other the menu lists) shows one picture from the mod's
`images` folder, `omen_<style>.png`, loaded as a texture when the cue attaches and
reused by later attaches while the engine keeps it (as every picture the mod loads). It holds
two layers side by side: the glow on the left half, drawn tinted (yellow, red in the
Perfect Opportunity window), and the white core on the right, drawn on top untinted, each
shown through a clip that shifts the picture to its half. `tools/make_omen_shapes.py`
draws Solid and Chevron; `tools/make_omen_layers.py` makes Fancy, or any other painted
Style, from its colour art in `art/<style>.png`. Each half must share Fancy's canvas
and arrow placement (887 by 1774, tip and back where `omens_fancy.lua` says). The menu
lists every `omen_<style>.png` each time it opens. The arrow is turned from pointing right
to each direction and scales as a whole. If the picture does not load, no arrows show
and the cue logs a warning; a saved Style that is not a name is Chevron. The box is 40% of the shorter screen side and centred
horizontally. Position places it vertically, centred on a cue area 50% of the
screen height tall (`preymonition/placement.lua`): Below keeps that
area's bottom 10% of the screen height above the bottom edge, Above keeps its
top 10% below the top edge, and Middle centres it.

The cue keeps every widget only as a weak handle, so nothing reads a collected
widget after the HUD is rebuilt. MCT releases the layer on detach; the template
clears its own content.

## Signals

MCT owns the game hooks. It watches the combat target indicator's own state
change, `WBP_CombatTargetIndicator_C:OnObservedStubIconTypeChanged`, through
UE4SSLuaEventBridge's hooks, and delivers each change as `MC_NPCAttackIndicator`,
the template's `update` event, on the next engine tick, about a frame after the
game's change:

- **arrow**: an attack shows on a visible indicator (icon types 1–4); our arrow
  shows.
- **critical**: that attack's Perfect Opportunity window opened (5–8); MCT
  sends the arrow first if it was not seen.
- **resolve**: the indicator went back to the sword (0) or to a weak spot
  (10–13), or was hidden; the shown arrow goes.
- **unblockable**: the indicator showed the unblockable skull (9), or it went.
  The cue shows its unblockable picture at the screen's centre; the picture grows from Unblockable
  Attack Indicator → Size's low end to its high end over the animation time,
  then holds until the attack's skull goes. 0% is 5% of the screen height and 100% the
  full screen height. Its opacity runs with that growth, from Unblockable Attack
  Indicator → Opacity's low end (50% by default) to its high end (80%).

A frame's delay is small next to the Perfect Opportunity window, which opens
0.02–0.81 s after the arrow shows (see the Countdown). The game also updates hidden twin
indicators: MCT counts only an indicator that is itself visible, and a hidden
twin never takes away the skull. A critical arrow from an indicator other than
the one the cue shows is shown as that indicator's attack.

MCT marks combat from `PlayerCombatComponent:OnCombatStarted` and
`OnCombatEnded`, and also ends it when a loading screen fades in
(`DWLoadingScreenWidget:OnFadeInFinished`), as after a death, which reports no
combat end. It delivers combat as the template's `wake` and `sleep` events and
hooks the indicator only while a template that takes `MC_NPCAttackIndicator` is
awake, so outside combat nothing shows and the hook costs nothing.

## Animation

Each attack's animation lasts 200 ms times the game's parry window multiplier
for the current difficulty, read from its combat subsystem when combat starts:
500 ms on the easiest (2.5), 280 ms on the second (1.4), 240 ms on the third
(1.2) and 200 ms on the hardest (1.0). 1.4 is assumed when it cannot be read.

An arrow shows at once, then over the animation time grows while its tip travels
outward and its opacity runs from Opacity's low end to its high end. Travel is a range on the space the arrow
has: at 0% the arrow, at its starting size, has its back edge on the cue's
centre; at 100% its tip is at the screen edge it travels towards. Up and down
arrows travel alike, as far as the nearer of the top and bottom edges, so at Below or
Above an arrow from behind moves as much as one from ahead. The arrow
appears with its tip at the low end and its tip stops at the high end, so equal
ends keep it still, and a large arrow never starts across the centre. Size is a
range whose low end sets the size an arrow appears at and whose high end the
size it grows to, in units of 5% of the screen height, from 1 at 0% to 10 at 100%. An arrow's picture scales as a whole
as it grows, its tip where the travel puts it. Solid and Chevron have a 135
degree tip (`tools/make_omen_shapes.py`). The game's left and right arrows show on the opposite sides of the
screen, so the cue shows them there too.

Opacity (Parry & Block Indicator → Opacity, a range, 50%–70% by default) is the
arrow's own opacity over its travel: the low end as it appears, the high end once its
travel ends, in step with its growth and travel (a held arrow's opacity follows its
share of the travel, and carries on with it once revealed). The cue's box adds none of
its own, at 100% in combat and 0% outside it, so that is what shows on screen. A yellow
arrow also takes Attack Incoming's opacity: with the defaults a Normal arrow appears
at 50% and reaches 70%, a Faint one 17.5% to 24.5%, and a red arrow shows at the
range's value where its travel is, 70% once it stops. The unblockable picture takes
its own Opacity (Unblockable Attack Indicator → Opacity, 50%–80% by default), in step
with its growth.

Critical turns the arrow red, and its grown size if its travel has not got
there, until the attack resolves, as the game turns its shield red (unless
Perfect Opportunity is Off). A resolved
arrow goes at once.

The arrow has two phases: the Yellow arrow before the Perfect Opportunity window, set
by Attack Incoming (Normal; Faint, at 35% of Opacity; Off, not shown), and the red arrow
taking over, set by Perfect Opportunity (End, Start, Halfway, Off). Attack Incoming sets
the yellow arrow's opacity and Perfect Opportunity the share of its growth and travel;
the yellow arrow is held back unless Attack Incoming is Normal and Perfect Opportunity
End, and Off never turns it red:

| Attack Incoming | Perfect Opportunity | Held | Yellow opacity (of Opacity) | Yellow travel | Red |
|---|---|---|---|---|---|
| Normal | End | no | 100% | all | yes |
| Faint or Off | End | yes | 35% or 0% | all | yes |
| any | Halfway | yes | by Attack Incoming | 50% | yes |
| any | Start | yes | by Attack Incoming | none | yes |
| any | Off | no | by Attack Incoming | all | no |

An arrow not held, at Normal and Normal, the defaults, shows and moves from the
first sighting and jumps to its critical size when that window opens. A held
arrow turns red when the Perfect Opportunity window opens and carries its growth
and travel on from where it was to the end, at the same pace, so one that has
not moved animates all the way. Without red the Perfect Opportunity window
changes nothing: the arrow stays yellow, at Attack Incoming's opacity, and an
attack first seen in that window shows yellow too. Unknown saved values are
Normal. These settings affect only the arrow; the unblockable indicator shows
as always, and the Audio Cues follow the attack from its yellow arrow. Combat start, or
the cue attaching during combat, shows the idle cue at once; combat end
takes it out at once. Nothing shows in the idle cue, so a fade would change nothing on
screen.

Animation uses real elapsed time and absolute phase deadlines, steps once per
frame when the engine tick is hooked, and stops once nothing moves. Each event
and animation frame resolves the cue's widgets once, and a frame writes only the
values that changed. Sprites load when the cue attaches. A failure handling an event is logged once per kind; repeats are
counted when combat ends.

## Audio Cues

The Audio Cues template (`preymonition/audio.lua`) plays a sound for each
attack, independent of what any other template shows; `preymonition/sound.lua`
loads and plays the files. Attack incoming plays when an attack is first seen,
as its parry window opens (an `arrow` event for a new indicator path or
direction), Perfect Opportunity when its Perfect Opportunity window opens (its
`critical` event), and Unblockable Attack, centred, when the unblockable
indicator shows (once until it goes). An attack whose first event is `critical`
plays only Perfect Opportunity; MCT sends `arrow` before `critical` for an attack
first seen in that window, so in game both play back to back. A repeated event
for the same attack replays nothing; its `resolve` forgets it, and combat end
forgets every attack.

The arrow sounds are the mod's own WAV files, `sounds/cue_<name>.wav`
(`tools/make_sounds.py` builds Ping and Bell), listed by
`Scripts/choices/cue_sounds.lua` each time the menu opens and saved by name;
selecting one in the menu plays it, centred. The three sounds sit under Sounds;
Enable directional sound, Differentiate back/front by pitch and Sound volume
under Options. They play through UE4SS Lua Sound
Bridge outside Wwise, once, at Sound volume times the game's Master and Effects
volume (0 when the game is muted), read at attach and when combat starts. With
Enable directional sound on, a side arrow's sound pans fully to the side the
arrow shows on, an up arrow plays at the front pitch and a down arrow at the back
pitch with a 1200 Hz low-pass (Differentiate back/front by pitch, -20% and +20%
by default); off, every arrow plays as recorded, centred. The unblockable sound
is one of the mod's `sounds/unblockable_<name>.wav` files, listed by
`Scripts/choices/unblockable_sounds.lua` the same way (Growl by default) and
played centred, as recorded, at the same volume. Chosen sounds load at attach;
sounds longer than 3 seconds are refused. Without the bridge, or when the chosen
file is gone or refused, nothing plays and the log says why, once per sound. No
Wwise events are posted.

In the module page's live preview the template takes only the preview's events
and plays them without combat, and nothing for an event the preview marks
silent (its sound button off, or on Auto with no Sounds or Options setting
selected); game events never reach the preview.

## Screen edges

The Edges template builds four edge glows in its layer, reaching in Thickness
(2% to 20%, default 8%) of the shorter screen side. With Visuals → Style Bands each
glow is six nested bands deepening inward, each with opacity
1-(1-Intensity)^(1/6) so that where all six overlap, at the screen edge, they
reach Intensity (10% to 100%, default 50%). With a gradient picture (default
Soft) each glow is one image of `images/edge_<key>_v.png` (top and bottom) or
`images/edge_<key>_h.png` (left and right screen edges), white and opaque at
the screen edge, tinted yellow or red with Intensity as its opacity; the bottom
and right screen edges show it mirrored by a render scale of -1 around its
centre. The pictures load through `KismetRenderingLibrary:ImportFileAsTexture2D`
from the mod folder, as the Unblockable pictures do (`preymonition/omens_images.lua`),
once per file for the session while the engine keeps them; a gradient whose
pictures cannot load draws Bands and logs a warning once. The Style list
(`choices/edge_gradients.lua`) offers Bands, then every `_v` picture with a
matching `_h` picture, each time the menu opens; `tools/make_edge_gradients.py`
writes the shipped Linear and Soft pairs. Its requests
(`preymonition/edges.lua`) decide what shows and its renderer
(`preymonition/edges_render.lua`) draws it. Only the attacked side's edge
lights, the game's left on the screen's right edge and its right on the left.
Activate Edges holds three switches, all On by default. With Attack incoming
On, the edge lights yellow on the attack's arrow request, as its parry window
opens; with Perfect Opportunity On, it lights red on its critical request. With
only Attack incoming On it stays yellow to the resolve; with only Perfect
Opportunity On it stays dark until critical; with both Off attacks light
nothing. A later attack moves the edge to its side; the edge goes out when the
attack it shows resolves, and a resolve for another indicator changes nothing.
With Unblockable Attack On, an active unblockable request lights all four
edges red, over the directional edge, until its inactive request, after which
the directional attack, if still open, shows again as it now stands. Combat
end puts every edge out and forgets both. Edges have no animation and no
sound.

## Countdown

The Countdown template builds a time, centred above a thin bar, in its layer. At
the default Size (10%) the bar is 20% of the screen height wide and its bottom
sits 77.5%, 55% or 32.5% of the height down for Below, Middle and Above, its own
places, not the omens'. Size scales the bar by 1+2*(s-10)/90 (three times at 100%)
and the time's line linearly from 3.5% of the height at 10% to 70% at 100% (below
10% it shrinks with the bar), keeping the font at 4/7 of the line; the box widens
to a time wider than the bar. Another Size keeps the box's vertical centre where
the 10% box has it for its Position, then moves it inside the screen. Its requests (`preymonition/countdown.lua`) time the
attack and its renderer (`preymonition/countdown_render.lua`) draws it, stepping
every frame only while something moves. Each frame looks up the HUD once and reuses
the widgets built in it while it lives; while the game is paused its clock stands
still, so nothing is drawn and the next look waits five frames.

The Perfect Opportunity window opens when the attacker's animation says, 0.02–0.81 s after
the arrow (median 0.42 s, second difficulty). The countdown runs on game time,
which stops while the game is paused. When the event names the attacker (its
`stub`, from MCT), it reads the attack's hit window from the game
(`CombatBlueprintFunctionLibrary:GetHitWindowTime`, through
`preymonition/combat.lua`), fixed as the arrow shows: the count runs to 0.18 s
before the hit window starts, where the Perfect Opportunity window opened in five measured
attacks (within 0.05 s), and the red bar to the hit window's end. Without a stub
or a hit window, the count is 0.3 s times the parry window multiplier read when
combat starts (0.42 s at 1.4, assumed when it cannot be read) and the red bar
runs over a second. Whether the 0.18 s scales with the multiplier is not yet
checked.

The time shows in tenths, rounded up, and the bar runs down from full; the
outline and the remaining bar are half see-through and the elapsed part is not
drawn. A count that runs out first holds at 0.0s. NOW comes only from the
critical request: the time reads NOW, everything turns red and the red bar runs
down, then holds empty. A resolve, or
combat end, hides it. The arrow showing again for the same attack keeps its
count; a critical request for an attack not counted says NOW at once.
Unblockable requests are the omens' and the sound cues'.

## Live preview

The Combat Preymonition page in the mod menu shows a live preview: ModCore
Templates attaches every selected template, each to its own layer in the
preview over the Omens' picture (`images/preview_background.jpg`), with the
page's current settings, applied or not, and loops npc.attacks' script: four
attacks, left, right, ahead and behind, each first seen (arrow), 700 ms later in
its Perfect Opportunity window (critical) and 500 ms after that resolved, then
an unblockable attack for 2 s. All four templates take part. The layers stack
by priority as on the HUD.

Each template keeps the preview's events to its preview attachment and the
game's away from it; the preview plays without combat, and combat start and end
leave it alone. A preview attachment shows its idle state at once. Its animation steps
by engine frames, which tick with the mod menu open (checked in game 2026-11-16). The Edges light and turn red as in
combat. The Countdown has no attack to time there and the game may be paused,
so in the preview it counts 0.7 s, the script's gap from arrow to critical, on
real time, says NOW as the script's critical comes and runs its red bar over
the 0.5 s to the resolve. The Audio Cues sound as above.

## Validation

Offline tests cover registration of the four templates, menu generation against
MCT's category, the animation timeline, the omens driven through MCT's
attack indicator source, the audio cues' sounds against a fake sound bridge, and the edges' and countdown's requests, against fake UE objects, each in combat and in the live preview.

Checked in game:

- 2026-10-11, when Preymonition still hooked the game itself: hook delivery,
  placement, the skull, and combat start and end, including a loading screen.
- 2026-10-18: the game's left and right arrows show on the opposite sides of the
  screen.
- 2026-11-12: attacks delivered through MCT's `MC_NPCAttackIndicator` with their
  attackers' stubs, and the Countdown's timing from the hit window (the Perfect
  Opportunity window opened 0.18 s before it in five attacks, within 0.05 s).
- 2026-11-16: the engine ticks with the mod menu open, so the live preview steps by
  frames.

Not yet checked in game: the Solid, Chevron and Fancy pictures, Position, the Audio
Cues, the Edges template and its switches, gradients, Thickness and Intensity, the
Countdown's display, the live preview of each template, and most non-default
settings.
