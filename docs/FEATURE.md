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
an overlay with four arrows the cue draws from solid images (Solid, Chevron).
Fancy shows two pictures from the mod's `images` folder, loaded as textures when
the cue attaches (yellow, and red for critical), turned from pointing right to
each direction; it scales as a whole, and falls back to the Chevron if the
pictures do not load. Perspective draws the Chevron as seen lying on a plane parallel to the ground
at the waist, from a camera 20 degrees above and half a screen height away: each
arm is sheared to the shape it projects to where the arrow appears, and as the
arrow travels it moves to where its flat place projects, scaled by its nearness. The box is 40% of the
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

MCT owns the game hooks. It watches the combat target indicator's own state
change, `WBP_CombatTargetIndicator_C:OnObservedStubIconTypeChanged`, through
UE4SSLuaEventBridge's hooks, and delivers each change as `MC_NPCAttackIndicator`,
the template's `update` event, on the next engine tick, about a frame after the
game's change:

- **arrow**: an attack shows on a visible indicator (icon types 1–4); our arrow
  shows.
- **critical**: that attack's parry window opened (5–8); MCT sends the arrow
  first if it was not seen.
- **resolve**: the indicator went back to the sword (0) or to a weak spot
  (10–13), or was hidden; the shown arrow goes.
- **unblockable**: the indicator showed the unblockable skull (9), or it went.
  The cue shows a skull in place of the shield; it grows from its set size to
  twice that over the animation time, then holds until the skull goes.

A frame's delay is small next to the parry window, which MCT measured opening
0.19–0.41 s after the arrow shows. The game also updates hidden twin
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

An arrow shows at full opacity with its back edge one unit out from the cue's
centre, then over the animation time grows while its tip travels outward. A unit
is 5% of the screen along the arrow's axis: the height for top and bottom, the
width for left and right. Indicator Size is a range whose low end sets the size
an arrow appears at and whose high end the size it grows to, in units of the
height from 1 at 0% to 5 at 100%; Movement takes its tip that share of the
way to 7 units (35% of the screen). An arrow grows by extending its lines back
from the tip, so its outline and inset keep their thickness: a Chevron's arms
lengthen, a Solid triangle's layers grow about their tips. Both have a 135
degree tip. The game's left and right arrows show on the opposite sides of the
screen, so the cue shows them there too.

Critical turns the arrow red, and its grown size if its travel has not got
there, until the attack resolves, as the game turns its shield red. An In
Combat or Defending shield turns red, and a Critical shield pops in red and grows to twice its size over the animation
time. A resolved arrow goes at once and the shield calms. Combat start fades the
idle cue in to half opacity; combat end fades it out over a second.

Sounds play through Wwise at the attacker: the owner of the indicator's latest
queued attack, else the player.

Animation uses real elapsed time and absolute phase deadlines, steps once per
frame when the engine tick is hooked, and stops once nothing moves. Each event
and animation frame resolves the cue's widgets once, and a frame writes only the
values that changed. Sprites and chosen sounds load when the cue
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
changes nothing. Unblockable requests are the center cue's. Combat end puts every edge out. Edges have no animation and no sound.

## Validation

Offline tests cover registration of both templates, menu generation against
MCT's category, the animation timeline, the center session driven through MCT's
attack indicator source, and the edges' requests, against fake UE objects.

Checked in game on 2026-10-11, when Preymonition still hooked the game itself:
hook delivery, placement, arrow and unblockable sounds, the skull, and combat
start and end, including a loading screen. Not yet checked in game: delivery
through MCT's `MC_NPCAttackIndicator`, the drawn arrows, Scale and Position,
the Chime sound, the Edges template on its own layer, and most non-default settings.
