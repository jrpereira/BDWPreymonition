# PREYMONITION

*You see them coming. They won't.*

Keep incoming attack directions in sight in **The Blood of Dawnwalker**, with
animated cues just below the center of your screen. Spend less time hunting for
the warning—and more time getting hit in the face like a pro that saw it coming.

## What it does

Preymonition adds an arrow cue just below the center of the screen without
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
- [ModCore Settings](https://www.nexusmods.com/thebloodofdawnwalker/mods/590).
- [ModCore Templates](https://www.nexusmods.com/thebloodofdawnwalker/mods/641).

## Installation

1. Close the game completely. Extract the mod download so its `9_ModCore_Preymonition`
   folder sits directly inside the game's `ue4ss/Mods` folder.
2. Download any missing dependencies above and install them with the game closed.
   Follow each download's instructions if it includes the full game-folder path.
   UE4SS itself does not install inside `Mods`.
3. Ensure the mods are enabled in your UE4SS setup or mod manager, then restart
   the game. Avoid an extra nested `9_ModCore_Preymonition/9_ModCore_Preymonition` folder.

## Settings

Open **Mod Settings → Preymonition**, set **Preymonition** to **Yes**, and choose
**Apply**. Adjust the settings under **Main Options** and the sections below it on the same page and choose
**Apply** after changing them. Percentages scale the standard look; 100% leaves it
unchanged.

| Setting | Choices |
|---|---|
| **Size** | Small, **Standard**, or Large. |
| **Show background shield** | **Off** or On: a faint shield behind the arrows. |
| **Arrow Movement** | 50%–200% (**100%**): how far arrows travel. |
| **Arrow Size** | 50%–200% (**100%**). |
| **Show trailing glow** | Off or **On**: a flash where an arrow appears. |
| **Play sound** (arrows) | **None**, Short Swoosh, or Long Swoosh, when an arrow appears. |
| **Unblockable size** | 50%–200% (**100%**): the skull's size. |
| **Play sound** (unblockable) | **None**, Growl, or Boom, when the skull appears. |

## If the cue does not appear

- Confirm **Preymonition** is set to **Yes** on its settings page and choose **Apply**.
- Check during combat while the game's original indicator shows an attack direction.
- Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings and ModCore Templates are
  enabled, then restart the game.
- If another mod changes the original attack indicator, try disabling that mod
  to check for a conflict.

## Updating or removing

Close the game before updating and keep your existing saved settings. Do not
replace them with example defaults. To stop the extra cue, set **Preymonition**
to **No** on its settings page and choose **Apply**. To uninstall, close the game,
disable or remove the `9_ModCore_Preymonition` folder,
and restart. Keep dependencies used by other mods.

See the [changelog](CHANGELOG.md) for changes.
