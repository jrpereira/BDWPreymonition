# How the cues behave

Combat Preymonition has four parts, listed on its settings page in this order:
**Omens Overlay**, the attack shown as symbols near the middle of the screen,
**Audio Cues**, a sound for each attack, **Edges Flash**, the screen edge glows,
and **Countdown**, a count to the Perfect Opportunity window. Each is turned on
by its own **Enabled**, so any of them, the Audio Cues alone included, can be on
without the others. They show once you are in the game and only during combat;
combat end, or a loading screen such as after a death, clears them all.

An attack has two windows. Its **parry window** opens when it is first shown
(the yellow arrow); its **Perfect Opportunity window** opens later (the red
arrow), between almost at once and about 0.8 s after the arrow. The cues follow
the game's own attack indicator and change about a frame after it.

## The omens

When an attack comes, an arrow shows from its direction. When its Perfect
Opportunity window opens the arrow turns red, as the game turns its shield red,
and it goes as soon as the attack lands or is deflected. The game's left and
right arrows show on the opposite sides of the screen, so the cue shows them
there too.

**Style** picks the arrow's picture: Chevron, Fancy, Solid or any other picture
in the mod's `images` folder named `omen_<style>.png`. The menu lists them each
time it opens. If a Style's picture does not load, no arrows show.

**Position** puts the arrows below the screen's middle, at it, or above it. It
moves only the arrows; the unblockable picture always shows at the screen's
centre.

### How an arrow moves

An arrow shows at once and then, over a short animation, grows, travels outward
and changes opacity. The animation is quicker on harder difficulties: about half
a second on the easiest and a fifth of a second on the hardest.

- **Size** is a range: the low end is the size an arrow appears at, the high end
  the size it grows to, from 5% of the screen height at 0% to 50% at 100%.
- **Travel** is a range on the space the arrow has: at 0% its back edge is on the
  cue's centre, at 100% its tip reaches the screen edge it travels towards. Up and
  down arrows travel alike, as far as the nearer of the top and bottom edges. The
  tip appears at the low end and stops at the high end, so equal ends keep it
  still.
- **Opacity** is a range: the arrow appears at the low end and reaches the high
  end once its travel ends.

### Yellow and red

**Attack Incoming** sets how the yellow arrow shows before the Perfect
Opportunity window: Normal, Faint (at 35% of Opacity) or Off. **Perfect
Opportunity** sets how the red arrow takes over:

| Attack Incoming | Perfect Opportunity | Yellow arrow | Red arrow |
|---|---|---|---|
| Normal | End | moves all the way from the first sighting | jumps in when the window opens |
| Faint or Off | End | moves all the way, faint or hidden | carries on from where yellow was |
| any | Halfway | moves halfway | carries on from there |
| any | Start | does not move | animates all the way |
| any | Off | moves all the way | never; the arrow stays yellow |

With Attack Incoming and Perfect Opportunity both Off, no arrow shows for
attacks. These settings affect only the arrow; the unblockable picture and the
Audio Cues are unaffected.

### Unblockable attacks

An unblockable attack shows its picture (**Unblockable Attack Indicator →
Style**, a horned skull by default) at the screen's centre. It grows from the
low end of its **Size** to the high end, from 5% of the screen height at 0% to
the full screen height at 100%, with its **Opacity** running from low to high
as it grows, then holds until the attack's skull goes. Add your own picture as
`unblockable_<name>.png` in the `images` folder and it is offered the next time
the menu opens.

## Audio Cues

The Audio Cues play whatever the other parts show:

- **Attack incoming** plays when an attack is first seen, as its parry window
  opens.
- **Perfect Opportunity** plays when its Perfect Opportunity window opens. An
  attack first seen in that window plays both, back to back.
- **Unblockable Attack** plays, centred, when the unblockable picture appears.

The same attack never plays a sound twice. The sounds are the WAV files in the
mod's `sounds` folder: `cue_<name>.wav` for the first two and
`unblockable_<name>.wav` for the third. Add your own (up to 3 seconds) and it is
offered the next time the menu opens; selecting a sound in the menu plays it.

With **Enable directional sound** on, a side arrow's sound plays on the side the
arrow shows on, an attack from ahead plays higher and one from behind lower and
muffled, by **Differentiate back/front by pitch**. Off, every arrow plays as
recorded, centred.

**Sound volume** is relative to the game's Effects volume times its Master
volume, and the sounds are silent when the game is muted. Changes in the game's
audio settings apply from the next fight.

The sounds need UE4SS Lua Sound Bridge. Without it, or when the chosen file is
missing or longer than 3 seconds, nothing plays and the log says why.

## Edges Flash

Only the attacked side's edge lights: the game's left on the screen's right edge
and its right on the left. **Activate Edges** holds three switches, all On by
default:

- **Attack incoming** lights the edge yellow when the parry window opens.
- **Perfect Opportunity** lights it red when the Perfect Opportunity window
  opens. With only Attack incoming On, the edge stays yellow until the attack
  resolves; with only Perfect Opportunity On, it stays dark until then.
- **Unblockable Attack** lights every edge red while an unblockable attack shows.
  Once it goes, an attack still open shows its own edge again.

A later attack moves the edge to its side; the edge goes out when the attack it
shows resolves. Edges have no animation and no sound.

**Visuals → Style** is Bands, six stepped bands deepening inward, or a smooth
gradient picture, Linear or Soft. To add a gradient, drop a pair of pictures in
the `images` folder: `edge_<name>_v.png` for the top edge, white and opaque at
the edge and fading down, and `edge_<name>_h.png` for the left edge, fading
right. A gradient whose pictures cannot load draws Bands. **Thickness** is how
far the glow reaches in, as a share of the shorter screen side, and
**Intensity** its opacity at the screen edge.

## Countdown

The countdown shows the time left to the attack's Perfect Opportunity window,
in tenths of a second, above a yellow bar that runs down. **Style** shows both,
the bar alone or the time alone.

The time comes from the attack's own timing in the game. When the game does not
give it, the countdown uses an estimate for the difficulty. A count that runs out
first holds at 0.0s. The countdown runs on game time, so it stands still while
the game is paused.

When the Perfect Opportunity window opens the time reads **NOW**, or with **Show
direction in label** on, the attack's direction (UP, DOWN, LEFT or RIGHT, the
way the Omens' arrow points on screen; NOW when the direction is unknown).
Everything turns red and the red bar runs down until the attack's hit would
land, then holds empty. NOW never shows before the game opens the window. The
countdown goes as soon as the attack resolves.

**Position** has places of its own, apart from the arrows'. **Size** and
**Opacity** are ranges: the low end as the count starts, the high end as it
reaches the Perfect Opportunity window, where it stays. Opacity fades the time,
the bar and its outline together. The countdown stays centred at its Position
and on screen at any Size.

## Live preview

The Combat Preymonition page shows a live preview over a game scene, drawn and
sounded with the page's current settings, applied or not. It loops four attacks,
left, right, ahead and behind, each turning to its Perfect Opportunity window
and resolving, then an unblockable attack. The countdown there counts the
preview's own timing. The preview's sound button: on Auto it sounds while an
Audio Cues setting is selected; On always; Off never.

