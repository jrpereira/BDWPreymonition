# PREYMONITION

*You see them coming. They won't.*

Keep incoming attack directions in sight in **The Blood of Dawnwalker**, with
animated cues near the bottom center of your screen. Spend less time hunting for
the warning—and more time getting hit in the face like a pro that saw it coming.

## What it does

Preymonition adds a shield cue near the bottom center of the screen without
replacing the game's original warning. Animated arrows repeat the direction
shown by the original shield cue, including repeated attacks from the same
direction. The extra cue fades when combat ends.

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
**Apply**. Adjust **Size** on the same page and choose **Apply** after changing it.

| Setting | Choices |
|---|---|
| **Size** | Small, **Standard**, or Large. |

## If the cue does not appear

- Confirm **Preymonition** is set to **Yes** on its settings page and choose **Apply**.
- Check during combat while the game's original indicator shows an attack direction.
- Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings and ModCore Templates are
  enabled, then restart the game.
- If another mod changes the original attack indicator, try disabling that mod
  to check for a conflict.

This version is awaiting in-game verification of warning delivery and animation.

## Updating or removing

Close the game before updating and keep your existing saved settings. Do not
replace them with example defaults. To stop the extra cue, set **Preymonition**
to **No** on its settings page and choose **Apply**. To uninstall, close the game,
disable or remove the `9_ModCore_Preymonition` folder,
and restart. Keep dependencies used by other mods.

See the [changelog](CHANGELOG.md) for changes.
