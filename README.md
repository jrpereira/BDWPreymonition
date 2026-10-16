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

It makes the warning easier to keep in view. Blocking, dodging, and taking the
credit remain your responsibility.

## Requirements

- **UE4SS for your Dawnwalker game version.** See the loader links in the
  [Dawnwalker Mod Menu requirements](https://www.nexusmods.com/thebloodofdawnwalker/mods/271).
- [Dawnwalker Mod Menu](https://www.nexusmods.com/thebloodofdawnwalker/mods/271)
  for the settings page.
- [ModCore Settings](https://www.nexusmods.com/thebloodofdawnwalker/mods/590)
  1.3.1 or newer.
- [ModCore Templates](https://www.nexusmods.com/thebloodofdawnwalker/mods/641)
  1.4.1 or newer.
- [UE4SS Lua Event Bridge](https://www.nexusmods.com/thebloodofdawnwalker/mods/526) 1.1.0 or newer, which
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

Combat Preymonition has two parts, each turned on by its own **Enabled**: the
**Center** cue near the middle of the screen, and the screen **Edges**, which glow
while an attack is incoming. Open **Mod Settings → Combat Preymonition**, set
**Enabled** under **Center**, **Edges** or both to **Yes**, and choose **Apply**.
Adjust each part's settings on the same page and choose **Apply** after
changing them. Percentages scale the standard look; 100% leaves it
unchanged, except Scale, which adds to it: 0% leaves it unchanged.

Every setting, its options and the `config.ini` key it is saved under are listed
in `SETTINGS.md`, next to this file in the installed mod.

| Setting | Choices |
|---|---|
| **General Options → Scale** | −50%–200% (**0%**): resizes the shield; 0% is the standard size, 40% of the shorter screen side. Arrows keep their size (see Parry & Block → Size) and the skull its own (Unblockable size). |
| **General Options → Position** | Below (the cue's bottom 10% of the screen height above the bottom edge), **Middle** (centred on the screen's middle), or Above (its top 10% below the top edge). |
| **General Options → Display Shield** | **Off**; In Combat (a faint shield behind the arrows throughout combat); Defending (the faint shield while an attack is shown); or Opportunity (a shield that pops in only when an attack turns critical, growing to twice its size). Each turns red while the attack is critical, and the skull replaces it during an unblockable attack. |
| **Parry & Block → Indicator Style** | Off, **Arrows**, or Glow: Glow moves the game's attack flash in place of the arrow. |
| **Parry & Block → Size** | 50%–200% (**100%**): the arrows' size. |
| **Parry & Block → Indicator Movement** | 50%–200% (**100%**): how far arrows travel. |
| **Parry & Block → Trailing effect** | Off, **Glow** (a flash where an arrow appears), or Fade (two fainter arrows trail it, at half and a quarter of its opacity). |
| **Parry & Block → Play sound** | **None**, Chime, or Swish, when an attack appears, played at the attacker. |
| **Unblockable size** | 50%–200% (**100%**): the skull's size as it appears; it grows to twice that as it appears. |
| **Play sound** (unblockable) | **None**, Growl, or Boom, when the skull appears, played at the attacker. |
| **Edges → Screen Edges → Edge Style** | **Framed** (every screen edge glows during an attack) or Directional (only the edge on the attack's side); red while the attack is critical. |

## If the cue does not appear

- Confirm **Enabled** is set to **Yes** under **Center** or **Edges** on the
  **Combat Preymonition** settings page and choose **Apply**.
- Check during combat while the game's original indicator shows an attack direction.
- Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings, ModCore Templates and
  UE4SS Lua Event Bridge are enabled, then restart the game.
- If another mod changes the original attack indicator, try disabling that mod
  to check for a conflict.

## Updating or removing

Close the game before updating and keep your existing saved settings. Do not
replace them with example defaults. To stop the extra cues, set **Enabled** to
**No** under **Center** and **Edges** on the **Combat Preymonition** settings page and choose **Apply**. To uninstall, close the game,
disable or remove the `9_ModCore_Preymonition` folder,
and restart. Keep dependencies used by other mods.

See the [changelog](CHANGELOG.md) for changes.
