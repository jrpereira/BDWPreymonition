# Directional cue behavior

Preymonition registers four managed MCT templates in `npc.attacks`:
**Background** (`mc_background.lua`), a shield that lights up with the attack,
**Omens** (`mc_omens.lua`), the attack shown as symbols around it, the cue,
**Edges** (`mc_edges.lua`), the screen edge glows, and **Countdown**
(`mc_countdown.lua`), a count to the parry window. Each is turned on by its own
Enabled. MCT orders them by priority (9, 10, 11, 12): the Background attaches
first, so its layer sits under the omens'.
The category attaches them once the player is in the game (`MC_PlayerReady`)
and supplies each the HUD (`hud`) and its own full-screen overlay created on the
HUD root (`cue`), so they never share or clear each other's layer. Each takes
MCT's `MC_NPCAttackIndicator` events on their own.

## The omens

Its requests (`preymonition/omens.lua`) follow the attack, its timeline
(`preymonition/omens_animation.lua`) animates it and its renderer
(`preymonition/omens_render.lua`, with `omens_drawn.lua` and `omens_fancy.lua` for
the arrows) draws it; `omens_sound.lua` plays its sounds. The parry window,
the attacker and the clock come from `preymonition/combat.lua`, shared with the
countdown.

`attach` builds the cue in that layer: a size box holding the centre image (the
unblockable skull, clear otherwise), then an overlay with four arrows the cue draws from solid images (Solid, Chevron).
Fancy shows two pictures from the mod's `images` folder, loaded as textures when
the cue attaches (yellow, and red for critical), turned from pointing right to
each direction; it scales as a whole, and falls back to the Chevron if the
pictures do not load. Perspective draws the Chevron as seen lying on a plane parallel to the ground
at the waist, from a camera 20 degrees above and half a screen height away: each
arm is sheared to the shape it projects to where the arrow appears, and as the
arrow travels it moves to where its flat place projects, scaled by its nearness. The box is 40% of the
shorter screen side and centred horizontally. Position places it vertically on
the Background's shield at its default size, 50% of the screen height
(`preymonition/placement.lua`, shared with the Background): Below keeps that
shield's bottom 10% of the screen height above the bottom edge, Above keeps its
top 10% below the top edge, and Middle centres it.

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
  The cue shows a skull at its centre, and the Background clears its shield
  meanwhile; the skull grows from Unblockable
  Attack Indicator → Size's low end to its high end over the animation time,
  then holds until the skull goes. 0% is 5% of the screen height and 100% the
  full screen height.

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

An arrow shows at full opacity, then over the animation time grows while its
tip travels outward. Movement from Center is a range on the space the arrow
has: at 0% the arrow, at its starting size, has its back edge on the cue's
centre; at 100% its tip is at the screen edge it travels towards. The arrow
appears with its tip at the low end and its tip stops at the high end, so equal
ends keep it still, and a large arrow never starts across the centre. In Perspective the shares
are of the furthest the arrow can show on the screen: the screen edge, or for the
up arrow, which recedes towards the horizon and never reaches the edge, where it
has shrunk to a quarter of its size. A receding arrow therefore covers more of
the ground plane than a nearing one at the same share. Size is a range whose low end sets the size
an arrow appears at and whose high end the size it grows to, in units of 5% of
the screen height, from 1 at 0% to 10 at 100%. An arrow grows by extending its lines back
from the tip, so its outline and inset keep their thickness: a Chevron's arms
lengthen, a Solid triangle's layers grow about their tips. Both have a 135
degree tip. The game's left and right arrows show on the opposite sides of the
screen, so the cue shows them there too.

Critical turns the arrow red, and its grown size if its travel has not got
there, until the attack resolves, as the game turns its shield red. A resolved
arrow goes at once.

With Prioritize Perfection over Buildup on, the arrow's animation belongs to the
parry window. Before then the yellow arrow is a buildup, shown by Buildup
visibility (Hidden; Faint, at 35% opacity; Normal) and moved by Buildup animation
(Static, staying at its starting size and place; Partial, growing and travelling
30% of the way; Normal, as without the option). When the parry window opens the
arrow turns red and carries its growth and travel on from where the buildup
left them to the end, at the same pace: a Static arrow animates all the way, a
Normal one has already finished. The arrow's sound plays only then, when
perfection starts; the buildup is silent. Hidden and Static are the defaults. The option affects only the
arrow; the Background follows the attack from its yellow arrow as always. Combat start fades the
idle cue in to half opacity; combat end fades it out over a second.

Sounds play through Wwise at the attacker: the owner of the indicator's latest
queued attack, else the player.

Animation uses real elapsed time and absolute phase deadlines, steps once per
frame when the engine tick is hooked, and stops once nothing moves. Each event
and animation frame resolves the cue's widgets once, and a frame writes only the
values that changed. Sprites and chosen sounds load when the cue
attaches. A failure handling an event is logged once per kind; repeats are
counted when combat ends.

## Background

The Background template builds the game's shield sprite in a box in its layer
(`preymonition/background_render.lua`), centred where Position puts a shield of
its Size, the same places the omens use; its requests
(`preymonition/background.lua`) follow the attack with the omens' timeline
(`preymonition/omens_animation.lua`). Combat start fades it in to half opacity
over 0.2 s, and combat end fades it out over a second. Visibility In Combat
shows it faint white throughout combat; Defending a see-through yellow, the
arrows' colour, while an attack is shown; Critical only once the parry window
opens. Each turns red while the parry window is open; a Critical shield pops in
red and grows to twice its size over the animation time, 200 ms times the parry
window multiplier. The shield clears while the omens show the unblockable skull,
and when the attack resolves it calms. Size (5% to 100% of the screen height)
scales the shield about its centre; the omens and the countdown line up on it at
its default, 50%.

## Screen edges

The Edges template builds four edge glows in its layer, each six nested bands
deepening inward to 8% of the shorter screen side. Its requests
(`preymonition/edges.lua`) decide what shows and its renderer
(`preymonition/edges_render.lua`) draws it. Edge Style Framed lights every edge
while an attack is shown; Directional lights only the attacked side's. An
attack's edges light at once on its arrow request, turn red when it goes
critical, and go out when it resolves; a resolve for another arrow or indicator
changes nothing. Unblockable requests are the omens' and the background's. Combat end puts every edge out. Edges have no animation and no sound.

## Countdown

The Countdown template builds a time above a thin bar in its layer, 20% of the
screen height wide, under where the Background's shield at its default size (50% of the height)
sits for its Position. Its requests (`preymonition/countdown.lua`) time the
attack and its renderer (`preymonition/countdown_render.lua`) draws it, stepping
every frame only while something moves.

The parry window opens when the attacker's animation says, 0.02–0.81 s after
the arrow (median 0.42 s, second difficulty). The countdown runs on game time,
which stops while the game is paused. When the event names the attacker (its
`stub`, from MCT), it reads the attack's hit window from the game
(`CombatBlueprintFunctionLibrary:GetHitWindowTime`, through
`preymonition/combat.lua`), fixed as the arrow shows: the count runs to 0.18 s
before the hit window starts, where the parry window opened in five measured
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
Unblockable requests are the omens' and the background's.

## Validation

Offline tests cover registration of the four templates, menu generation against
MCT's category, the animation timeline, the omens driven through MCT's
attack indicator source, and the background's, edges' and countdown's requests, against fake UE objects.

Checked in game on 2026-10-11, when Preymonition still hooked the game itself:
hook delivery, placement, arrow and unblockable sounds, the skull, and combat
start and end, including a loading screen. Not yet checked in game: delivery
through MCT's `MC_NPCAttackIndicator`, the drawn arrows, Scale and Position,
the Chime sound, the Edges template on its own layer, the Countdown, the Background template, and most non-default settings.
