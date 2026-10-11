# Directional cue behavior

Preymonition is a managed MCT template in `npc.attacks`. The category
attaches it once the player is in the game (`MCTPlayerReady`) and supplies the HUD (`hud`) and a full-screen overlay created on its root (`cue`).
`attach` builds the cue in that layer, centred horizontally with its top on the
screen's vertical middle: a size box holding the shield image, then an overlay
with a flash image behind four arrow images. The cue keeps every widget only as
a weak handle, so nothing reads a collected widget after the HUD is rebuilt. MCT
releases the layer on detach; the template clears its own content.

## Signals

This UE4SS cannot hook blueprint functions, and the game updates its indicator
widgets from C++, which hooks never see. The indicator blueprint styles its
arrows and its centre icon through the native `Image:SetBrushFromAtlasInterface`,
and that one call carries the attack:

- **Arrow styled lit** (orange, on a visible indicator): an attack from that
  direction; our arrow shows.
- **Shown arrow styled again**: the attack turned critical. Nothing the hook
  reads tells this styling from the first: in play (2026-10-11) the native
  colour stayed 1.00 0.67 0.19 with the same brush and white tint. So the
  second styling counts, and a duplicated delivery would turn an attack
  critical early.
- **Arrow styled dark**, or styled while its indicator is hidden: the attack is over.
- **Centre icon to Sword**: no attack pending; the shown arrow resolves.
- **Centre icon to SkullRed**: an unblockable attack; the cue shows a skull.

The centre icon is read before the call, from the sprite argument; arrows are
read after it, once brush and colour are set. Both are handled during the call,
in the game's order, so the cue changes in the same frame as the game's. When an
arrow is not yet lit as it is styled, its indicator's arrows are checked again
next frame, once per indicator however many arrows it styled, and a lit one
can only be shown then. The game also updates hidden twin indicators; only an indicator that is
itself visible counts, and a hidden twin never takes away the skull its visible
indicator shows.

MCT marks combat from `PlayerCombatComponent:OnCombatStarted` and
`OnCombatEnded`, and also ends it when a loading screen fades in
(`DWLoadingScreenWidget:OnFadeInFinished`), as after a death, which reports no
combat end. It delivers combat as the template's `wake` and `sleep` events.
The styling call is hooked only between them, so outside combat nothing shows
and the hook costs nothing.

## Animation

An arrow shows at full opacity and 1.5 times its size, one arrow image out from
the native rest (half an image for the bottom arrow), then over 0.2 s grows to
twice its size while travelling to three images out (two for the bottom). The
flash shows where it appears and fades out while growing. Critical turns the
arrow red and 2.5 times its size until resolved; a resolved arrow goes at once.
Combat start fades the idle cue in; combat end fades it out over a second.
The cue settings scale arrow size and movement, show the shield, turn the
flash off, size the skull and choose sounds, posted through Wwise at the player.

Deferred work waits in a queue of 16 events; under pressure the oldest gives
way, and consecutive events of the same kind for the same object merge. The
next-frame recheck catches an arrow lit at most one frame after its styling;
one lit later still shows only with the indicator's next styling.

A `preview.txt` file next to `mod.json` is a developer aid: it keeps the cue on
screen with the top arrow lit from attach, and through combat end.

Animation uses real elapsed time and absolute phase deadlines, steps once per
frame when the engine tick is hooked, and stops once nothing moves.
Each hook call, deferred drain and animation frame resolves the cue's widgets
once, and a frame writes only the values that changed. Sprites and chosen
sounds load when the cue attaches. A failure inside the game's call is logged
once per kind; repeats are counted when combat ends, with the number of styling
calls the hook saw (DEBUG).

Offline tests cover registration, menu generation against MCT's category,
the animation timeline, the event queue and the session against fake UE objects.
Hook delivery, placement, arrow and unblockable sounds, the skull, and combat
start and end (including a loading screen) were checked in game on 2026-10-11.
Most non-default settings are not yet tested in play.
