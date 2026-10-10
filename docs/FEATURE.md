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
  direction. The first styling shows our arrow; the second turns it critical.
- **Arrow styled dark**, or styled while its indicator is hidden: the attack is over.
- **Centre icon to Sword**: no attack pending; the shown arrow resolves.
- **Centre icon to SkullRed**: an unblockable attack; the cue shows a skull.

The centre icon is read before the call, from the sprite argument; arrows are
read after it, once brush and colour are set. Both are handled during the call,
in the game's order, so the cue changes in the same frame as the game's. An
arrow not yet lit when styled is checked again next frame and can only be shown
then. The game also updates hidden twin indicators; only an indicator that is
itself visible counts.

MCT marks combat from `PlayerCombatComponent:OnCombatStarted` and
`OnCombatEnded` and delivers it as the template's `wake` and `sleep` events.
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

Animation uses real elapsed time and absolute phase deadlines, steps once per
frame when the engine tick is hooked, and stops once nothing moves.

Offline tests cover registration, menu generation against MCT's category,
the animation timeline, the event queue and the session against fake UE objects.
Live hook delivery, placement and sounds were checked in game during development.
