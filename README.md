# COMBAT PREYMONITION

*You see them coming. They won't.*

Keep incoming attack directions in sight in **The Blood of Dawnwalker**, with
animated cues near the center of your screen. Spend less time hunting for
the warning—and more time getting hit in the face like a pro that saw it coming.

## What it does

Preymonition adds an arrow cue near the center of the screen without
replacing the game's original warning. When an attack comes, an arrow flashes in
from its direction and turns red when the attack becomes critical. It vanishes
once the attack lands or is deflected, so an empty cue means nothing is incoming.
Unblockable attacks show a picture at the screen's centre, a horned skull by default. The cue fades when combat ends.
A shield behind it can light up with the attack, the screen edges can glow,
sound cues can play as the attack comes, with or without the arrows, and a
countdown can show the time left to the attack's perfect opportunity window.

It makes the warning easier to keep in view. Blocking, dodging, and taking the
credit remain your responsibility.

## Requirements

- **UE4SS for your Dawnwalker game version.** See the loader links in the
  [Dawnwalker Mod Menu requirements](https://www.nexusmods.com/thebloodofdawnwalker/mods/271).
- [Dawnwalker Mod Menu](https://www.nexusmods.com/thebloodofdawnwalker/mods/271)
  for the settings page.
- [ModCore Settings](https://www.nexusmods.com/thebloodofdawnwalker/mods/590)
  1.9.0 or newer.
- [ModCore Templates](https://www.nexusmods.com/thebloodofdawnwalker/mods/641)
  1.9.0 or newer.
- [UE4SS Lua Event Bridge](https://www.nexusmods.com/thebloodofdawnwalker/mods/526) 1.3.0 or newer, which
  ModCore Templates also requires. Without it no cue appears.
- [UE4SS Lua Sound Bridge](https://github.com/jrpereira/UE4SSLuaEXtensions/releases) 1.1.0 or newer,
  for the Sound Cues. Without it they are silent.

## Installation

1. Close the game completely. Extract the mod download so its `9_ModCore_Preymonition`
   folder sits directly inside the game's `ue4ss/Mods` folder.
2. Download any missing dependencies above and install them with the game closed.
   Follow each download's instructions if it includes the full game-folder path.
   UE4SS itself does not install inside `Mods`.
3. Ensure the mods are enabled in your UE4SS setup or mod manager, then restart
   the game. Avoid an extra nested `9_ModCore_Preymonition/9_ModCore_Preymonition` folder.

## Settings

Combat Preymonition has five parts, each turned on by its own **Enabled**: the
**Omens**, symbols near the middle of the screen, the **Sound Cues**, sounds for each
attack that play whatever else is on, the screen **Edges**, which glow while an
attack is incoming, the **Countdown (WIP)** to the attack's perfect opportunity
window, and the **Background**, a shield behind the omens that lights up with the
attack. Open **Mod Settings → Combat Preymonition**, set **Enabled** under
**Omens**, **Sound Cues**, **Edges**, **Countdown (WIP)**, **Background** or any of
them to **Yes**, and choose **Apply**. The Sound Cues can be on alone, for sounds
without the arrows.

An attack has two windows: its **parry window** opens when it is first shown (the
yellow arrow), and its **perfect opportunity window** later (the red arrow).
Adjust each part's settings on the same page and choose **Apply** after
changing them.

Every setting, its options and the `config.ini` key it is saved under are listed
in `SETTINGS.md`, next to this file in the installed mod.

| Setting | Choices |
|---|---|
| **Background → Position** | Below, **Middle** or Above, the same places as the Omens' Position: match them to keep the shield behind the omens. |
| **Background → Visibility** | In Combat (a faint white shield throughout combat), **Defending** (a see-through yellow, the arrows' colour, while an attack is shown) or Critical (a shield that pops in only when the perfect opportunity window opens, growing to twice its size). Each turns red while the perfect opportunity window is open, and clears while the Omens show an unblockable skull. |
| **Background → Size** | 5%–100% (**50%**) of the screen height. The Omens and the Countdown line up on a shield at the default size. |
| **Parry & Block Indicator → Style** | Off, Solid (a triangle), **Chevron**, Perspective, or Fancy (glowing painted arrows from the mod's `images` folder, red while critical; they scale as a whole as they grow): arrows drawn by the mod, in the arrow colour with a thin, dimmer inset and a thin black outline. Perspective lays the Chevron on a plane parallel to the ground at the character's waist, seen from a camera 20° above: arrows further away show higher up and smaller, nearer ones lower and larger. |
| **Parry & Block Indicator → Position** | Where the arrows show: Below (their centre where a default-size shield's bottom is 10% of the screen height above the bottom edge), **Middle** (centred on the screen's middle), or Above (the mirror of Below). Only the arrows move; the unblockable indicator stays at the screen's centre. |
| **Parry & Block Indicator → Size** | A range on 0%–100% (**30%–80%**), its ends at least 10% apart: the low end is the size an arrow appears at, the high end the size it grows to as it travels. Sizes are in units of 5% of the screen height, from 1 unit at 0% to 10 at 100%, so the default grows from 3.7 to 8.2 units. An arrow grows by extending its lines from the tip; its outline keeps its thickness. |
| **Parry & Block Indicator → Movement from Center** | A range on 0%–100% (**40%–60%**) of the space the arrow has: at 0% the arrow, at its starting size, has its back edge on the cue's centre; at 100% its tip is at the screen edge it travels towards. Its tip appears at the low end and stops at the high end, so equal ends keep it still. In Perspective 100% is the furthest the arrow can show: the screen edge for arrows coming towards you, and for the up arrow, which recedes towards the horizon, the point where it has shrunk to a quarter of its size. So at the same share the up arrow covers much more ground than the down arrow. |
| **Parry & Block Indicator → Buildup visibility** | How the yellow arrow shows before the perfect opportunity window opens: Hidden, Faint (see-through) or **Normal**. |
| **Parry & Block Indicator → Buildup animation** | How the yellow arrow moves before the perfect opportunity window opens: Static (stays where it starts), Partial (grows and travels 30% of the way) or **Normal**. With both at Normal the arrow shows and moves from the start, and when that window opens it turns red and grows to full size at once. Any other pair holds it back as chosen; the window turns it red and carries its growth and travel on from there. The Background and the Sound Cues are unaffected. |
| **Unblockable Attack Indicator → Style** | How an unblockable attack shows at the screen's centre: Off, **Fiend** (a horned skull), Gore (a bleeding skull), Cracked (a cracked shield), Shattered (a shattered shield), Ember (a red cloud) or Splatter (a blood splatter), each a picture from the mod's `images` folder in its own colours. The list follows the `unblockable_<name>.png` files there; add your own and it is offered the next time the menu opens. |
| **Unblockable Attack Indicator → Size** | A range on 0%–100% (**60%–100%**): the low end is the indicator's size as it appears, the high end the size it grows to. 0% is 5% of the screen height and 100% the full screen height, so by default it grows from about 62% of the screen to all of it. |
| **Sound Cues → Sound Notifications → Attack incoming** | Played when the parry window opens (the yellow arrow), as the attack is first seen, whatever the Omens show: None or one of the mod's cue sounds, **Rumble** by default. The cue sounds are the `cue_<name>.wav` files in the mod's `sounds` folder; add your own WAV (up to 3 seconds) as `cue_<name>.wav` and it is offered the next time the menu opens. They need UE4SS Lua Sound Bridge. |
| **Sound Cues → Sound Notifications → Perfect opportunity** | Played when the perfect opportunity window opens (the red arrow): the same choices, **Ding** by default. |
| **Sound Cues → Sound Notifications → Unblockable Attack** | Played when the unblockable indicator appears: None or one of the mod's unblockable sounds, **Growl** by default: the `unblockable_<name>.wav` files in the `sounds` folder, which you can add to the same way. |
| **Sound Cues → Sound Notifications → Enable directional sound** | **On**: a side arrow's sound plays on the side the arrow shows on, and ahead and behind are set apart by pitch, behind also muffled. Off: every arrow sounds the same. |
| **Sound Cues → Sound Notifications → Differentiate back/front by pitch** | How much lower an arrow from behind and higher one from ahead sounds, -50% to +50%; **-20%** and **+20%** by default. Shown while directional sound is on. |
| **Sound Cues → Sound Notifications → Sound volume** | How loud these sounds play, 0% to 200%, relative to the game's **Effects** volume (times **Master**); **100%** follows them as set. Changes in the game's audio settings apply from the next fight. |
| **Edges → Screen Edges → Edge Style** | **Framed** (every screen edge glows during an attack) or Directional (only the edge on the attack's side); red while the attack is critical. |
| **Countdown (WIP) → Position** | Below, **Middle** or Above: under the Background's shield at the same Position, at its default size. The countdown, a work in progress, shows the time left to the attack's perfect opportunity window above a yellow bar that runs down. The time comes from the attack's own timing in the game, to within about 0.05 s; when the game does not give it, it is an estimate (0.42 s on the second difficulty), and real attacks vary from almost none to about 0.8 s. **NOW** shows only when the game opens the perfect opportunity window, never before: the time and bar turn red and the bar runs down until the attack's hit would land. Everything goes as soon as the attack resolves. |

## If the cue does not appear

- Confirm **Enabled** is set to **Yes** under **Omens**, **Sound Cues**, **Edges**, **Countdown (WIP)** or **Background** on the
  **Combat Preymonition** settings page and choose **Apply**.
- Check during combat while the game's original indicator shows an attack direction.
- Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings, ModCore Templates and
  UE4SS Lua Event Bridge are enabled, then restart the game.
- If another mod changes the original attack indicator, try disabling that mod
  to check for a conflict.

## Updating or removing

Close the game before updating and keep your existing saved settings. Do not
replace them with example defaults. To stop the extra cues, set **Enabled** to
**No** under **Omens**, **Sound Cues**, **Edges**, **Countdown (WIP)** and **Background** on the **Combat Preymonition** settings page and choose **Apply**. To uninstall, close the game,
disable or remove the `9_ModCore_Preymonition` folder,
and restart. Keep dependencies used by other mods.

See the [changelog](CHANGELOG.md) for changes.
