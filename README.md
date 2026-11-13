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
Unblockable attacks show a skull. The cue fades when combat ends.
A shield behind it can light up with the attack, the screen edges can glow,
and a countdown can show the time left to the attack's parry window.

It makes the warning easier to keep in view. Blocking, dodging, and taking the
credit remain your responsibility.

## Requirements

- **UE4SS for your Dawnwalker game version.** See the loader links in the
  [Dawnwalker Mod Menu requirements](https://www.nexusmods.com/thebloodofdawnwalker/mods/271).
- [Dawnwalker Mod Menu](https://www.nexusmods.com/thebloodofdawnwalker/mods/271)
  for the settings page.
- [ModCore Settings](https://www.nexusmods.com/thebloodofdawnwalker/mods/590)
  1.6.0 or newer.
- [ModCore Templates](https://www.nexusmods.com/thebloodofdawnwalker/mods/641)
  1.7.0 or newer.
- [UE4SS Lua Event Bridge](https://www.nexusmods.com/thebloodofdawnwalker/mods/526) 1.2.0 or newer, which
  ModCore Templates also requires. Without it no cue appears.

## Installation

1. Close the game completely. Extract the mod download so its `9_ModCore_Preymonition`
   folder sits directly inside the game's `ue4ss/Mods` folder.
2. Download any missing dependencies above and install them with the game closed.
   Follow each download's instructions if it includes the full game-folder path.
   UE4SS itself does not install inside `Mods`.
3. Ensure the mods are enabled in your UE4SS setup or mod manager, then restart
   the game. Avoid an extra nested `9_ModCore_Preymonition/9_ModCore_Preymonition` folder.

## Settings

Combat Preymonition has four parts, each turned on by its own **Enabled**: the
**Background**, a shield near the middle of the screen that lights up with the
attack, the **Omens**, symbols around it, the screen **Edges**, which glow while an
attack is incoming, and the **Countdown** to the attack's parry window. Open
**Mod Settings → Combat Preymonition**, set **Enabled** under **Background**,
**Omens**, **Edges**, **Countdown** or any of them to **Yes**, and choose **Apply**.
Adjust each part's settings on the same page and choose **Apply** after
changing them.

Every setting, its options and the `config.ini` key it is saved under are listed
in `SETTINGS.md`, next to this file in the installed mod.

| Setting | Choices |
|---|---|
| **Background → Position** | Below, **Middle** or Above, the same places as the Omens' Position: match them to keep the shield behind the omens. |
| **Background → Visibility** | In Combat (a faint white shield throughout combat), **Defending** (a see-through yellow, the arrows' colour, while an attack is shown) or Critical (a shield that pops in only when the parry window opens, growing to twice its size). Each turns red while the parry window is open, and clears while the Omens show an unblockable skull. |
| **Background → Size** | 5%–100% (**50%**) of the screen height. The Omens and the Countdown line up on a shield at the default size. |
| **Position** | Below (the cue's bottom 10% of the screen height above the bottom edge), **Middle** (centred on the screen's middle), or Above (its top 10% below the top edge). |
| **Parry & Block Indicator → Style** | Off, Solid (a triangle), **Chevron**, Perspective, or Fancy (glowing painted arrows from the mod's `images` folder, red while critical; they scale as a whole as they grow): arrows drawn by the mod, in the arrow colour with a thin, dimmer inset and a thin black outline. Perspective lays the Chevron on a plane parallel to the ground at the character's waist, seen from a camera 20° above: arrows further away show higher up and smaller, nearer ones lower and larger. |
| **Parry & Block Indicator → Size** | A range on 0%–100% (**30%–80%**), its ends at least 10% apart: the low end is the size an arrow appears at, the high end the size it grows to as it travels. Sizes are in units of 5% of the screen height, from 1 unit at 0% to 10 at 100%, so the default grows from 3.7 to 8.2 units. An arrow grows by extending its lines from the tip; its outline keeps its thickness. |
| **Parry & Block Indicator → Movement from Center** | A range on 0%–100% (**40%–60%**) of the space the arrow has: at 0% the arrow, at its starting size, has its back edge on the cue's centre; at 100% its tip is at the screen edge it travels towards. Its tip appears at the low end and stops at the high end, so equal ends keep it still. In Perspective 100% is the furthest the arrow can show: the screen edge for arrows coming towards you, and for the up arrow, which recedes towards the horizon, the point where it has shrunk to a quarter of its size. So at the same share the up arrow covers much more ground than the down arrow. |
| **Parry & Block Indicator → Play sound** | None, **Chime**, or Swish, when an attack appears, played at the attacker. |
| **Parry & Block Indicator → Prioritize Perfection over Buildup** | **Off** or On. On makes the arrow animate, red, once the parry window opens, carrying on from where its buildup left it; its sound plays only then. The Background is unaffected. |
| **Parry & Block Indicator → Buildup visibility** | With Prioritize Perfection on: how the yellow arrow shows before the parry window. **Hidden**, Faint (see-through) or Normal. |
| **Parry & Block Indicator → Buildup animation** | With Prioritize Perfection on: how the yellow arrow moves before the parry window. **Static** (stays where it starts), Partial (grows and travels 30% of the way) or Normal. |
| **Unblockable Attack Indicator → Size** | A range on 0%–100% (**60%–100%**): the low end is the skull's size as it appears, the high end the size it grows to. 0% is 5% of the screen height and 100% the full screen height, so by default it grows from about 62% of the screen to all of it. |
| **Unblockable Attack Indicator → Play sound** | None, **Growl**, or Boom, when the skull appears, played at the attacker. |
| **Edges → Screen Edges → Edge Style** | **Framed** (every screen edge glows during an attack) or Directional (only the edge on the attack's side); red while the attack is critical. |
| **Countdown → Position** | Below, **Middle** or Above: under the Background's shield at the same Position, at its default size. The countdown shows the time left to the attack's parry window above a yellow bar that runs down. The time comes from the attack's own timing in the game, to within about 0.05 s; when the game does not give it, it is an estimate (0.42 s on the second difficulty), and real attacks vary from almost none to about 0.8 s. **NOW** shows only when the game opens the parry window, never before: the time and bar turn red and the bar runs down until the attack's hit would land. Everything goes as soon as the attack resolves. |

## If the cue does not appear

- Confirm **Enabled** is set to **Yes** under **Background**, **Omens**, **Edges** or **Countdown** on the
  **Combat Preymonition** settings page and choose **Apply**.
- Check during combat while the game's original indicator shows an attack direction.
- Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings, ModCore Templates and
  UE4SS Lua Event Bridge are enabled, then restart the game.
- If another mod changes the original attack indicator, try disabling that mod
  to check for a conflict.

## Updating or removing

Close the game before updating and keep your existing saved settings. Do not
replace them with example defaults. To stop the extra cues, set **Enabled** to
**No** under **Background**, **Omens**, **Edges** and **Countdown** on the **Combat Preymonition** settings page and choose **Apply**. To uninstall, close the game,
disable or remove the `9_ModCore_Preymonition` folder,
and restart. Keep dependencies used by other mods.

See the [changelog](CHANGELOG.md) for changes.
