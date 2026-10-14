# Directional cue behavior

Preymonition registers two managed MCT templates in `npc.attacks`: **Center**
(`mc_center.lua`), the cue near the screen's center, and **Edges**
(`mc_edges.lua`), the screen edge glows. Each is turned on by its own Enabled.
The category attaches them once the player is in the game (`MC_PlayerReady`)
and supplies each the HUD (`hud`) and its own full-screen overlay created on the
HUD root (`cue`), so the two never share or clear each other's layer. Both take
MCT's `MC_NPCAttackIndicator` events on their own.

## The center cue

`attach` builds the cue in that layer: a size box holding the shield image, then
an overlay with a flash image behind four arrow images. The box is 40% of the
shorter screen side and centred horizontally. Position places it vertically by
the shield: Below keeps the shield's bottom 10% of the screen height above the
bottom edge, Above keeps its top 10% below the top edge, and Middle centres it.
Scale (−50% to 200%) resizes only the shield, drawn around its centre; the box,
the arrows and their travel keep their size.

The arrows take their artwork, rest position and rotation from the indicator
blueprint's designed arrows (`WBP_CombatTargetIndicator_C:WidgetTree.<Direction>Arrow`)
when the cue attaches, or when combat starts if the blueprint had not loaded
yet. Nothing is copied from a live indicator during an attack, and an attack
that arrives before the artwork is found is not shown. A critical arrow keeps
that artwork, tinted red.

The cue keeps every widget only as a weak handle, so nothing reads a collected
widget after the HUD is rebuilt. MCT releases the layer on detach; the template
clears its own content.

## Signals

MCT owns the game hooks. It watches the combat target indicator through the
native `Image:SetBrushFromAtlasInterface`, which the indicator blueprint uses to
style its arrows and centre icon, and delivers each change as
`MC_NPCAttackIndicator`, the template's `update` event, inside the game's call:

- **arrow**: a lit arrow on a visible indicator; our arrow shows.
- **critical**: the same arrow styled again: the attack turned critical. Nothing
  the hook reads tells this styling from the first: in play (2026-10-11) the
  native colour stayed 1.00 0.67 0.19 with the same brush and white tint.
- **resolve**: the centre icon turned to the sword, the shown arrow went dark, or
  its indicator was hidden; the shown arrow goes.
- **unblockable**: the centre icon turned to SkullRed, or back. The cue shows a
  skull in place of the shield; it grows from its set size to twice that over
  the animation time, then holds until the skull goes.

Each event is handled during the game's call, so the cue changes in the same
frame as the game's. An arrow lit one frame after its styling reaches the cue as
a late arrow; one lit later still shows only with the indicator's next styling.
The game also updates hidden twin indicators: MCT counts only an indicator that
is itself visible, and a hidden twin never takes away the skull. A critical
arrow from an indicator other than the one the cue shows is shown as that
indicator's attack.

MCT marks combat from `PlayerCombatComponent:OnCombatStarted` and
`OnCombatEnded`, and also ends it when a loading screen fades in
(`DWLoadingScreenWidget:OnFadeInFinished`), as after a death, which reports no
combat end. It delivers combat as the template's `wake` and `sleep` events and
hooks the indicator only while a template that takes `MC_NPCAttackIndicator` is
awake, so outside combat nothing shows and the hook costs nothing.

## Early warning

For some attacks, often the first of an exchange, the game tells the player's
helper indicator about the attack 0.1–0.9 s before the indicator arrow lights
(`DawnwalkerPlayerCharacter:ShowHelperAttackIndicator`). MCT delivers it as an
`early` event with the direction, whether it is unblockable, and the attacker.
The cue shows the arrow, or the skull, at once and plays its sound at the
attacker. When the indicator lights the same arrow or shows the skull, that
detection takes over without showing or sounding again. An early show nothing
takes over goes after 1.2 s; an early skull also goes when MCT reports the
skull gone.

## Animation

Each attack's animation lasts 200 ms times the game's parry window multiplier
for the current difficulty, read from its combat subsystem when combat starts:
500 ms on the easiest (2.5), 280 ms on the second (1.4), 240 ms on the third
(1.2) and 200 ms on the hardest (1.0). 1.4 is assumed when it cannot be read.

An arrow shows at full opacity and 1.5 times its size, one movement unit out
from its rest, then over the animation time grows to 2.5 times its size, the
critical size, while travelling to three units out; the bottom arrow moves half
as far. A unit is 5% of the shorter screen side (108 pixels at 2160). The flash
shows where the arrow appears and fades out while growing to 1.5 times its size.

Critical turns the arrow red, and 2.5 times its size if its travel has not got
there, until the attack resolves, as the game turns its shield red. An In
Combat or Defending shield turns red, and an Opportunity shield pops in red and grows to twice its size over the animation
time. A resolved arrow goes at once and the shield calms. Combat start fades the
idle cue in to half opacity; combat end fades it out over a second.

Sounds play through Wwise at the attacker: the one the early warning names,
else the owner of the indicator's latest queued attack, else the player.

Animation uses real elapsed time and absolute phase deadlines, steps once per
frame when the engine tick is hooked, and stops once nothing moves. Each event
and animation frame resolves the cue's widgets once, and a frame writes only the
values that changed. Sprites, arrow artwork and chosen sounds load when the cue
attaches. A failure handling an event is logged once per kind; repeats are
counted when combat ends.

## Screen edges

The Edges template builds four edge glows in its layer, each six nested bands
deepening inward to 8% of the shorter screen side. Its requests
(`preymonition/edges.lua`) decide what shows and its renderer
(`preymonition/edges_render.lua`) draws it. Edge Style Framed lights every edge
while an attack is shown; Directional lights only the attacked side's. An
attack's edges light at once on its arrow request, turn red when it goes
critical, and go out when it resolves; a resolve for another arrow or indicator
changes nothing. An early warning lights them too, the attack takes them over,
and one nothing takes over goes after 1.2 s. Unblockable requests are the center
cue's. Combat end puts every edge out. Edges have no animation and no sound.

## Validation

Offline tests cover registration of both templates, menu generation against
MCT's category, the animation timeline, the center session driven through MCT's
attack indicator source, and the edges' requests, against fake UE objects.

Checked in game on 2026-10-11, when Preymonition still hooked the game itself:
hook delivery, placement, arrow and unblockable sounds, the skull, and combat
start and end, including a loading screen. Not yet checked in game: delivery
through MCT's `MC_NPCAttackIndicator`, the arrow artwork taken from the
blueprint, Scale and Position, the Chime sound, the Edges template on its own
layer, and most non-default settings.
