# Preymonition

*You see them coming. They won't.*

Keep incoming attack directions in sight with animated cues near the bottom
center of your screen. Spend less time hunting for the warning—and more time
getting hit in the face like a pro that saw it coming.

## What it does

Preymonition adds a shield cue near the bottom center of the screen. Animated
arrows repeat the attack direction shown by the game's original shield warning,
including repeated attacks from the same direction. The extra cue fades when
combat ends.

Choose **Small**, **Standard** or **Large** to suit your screen. The original
warning stays in place. Blocking, dodging, and taking the credit remain your
responsibility.

**Current status:** this version is awaiting in-game verification of warning
delivery and animation.

## Requirements

Install these before Preymonition:

- **UE4SS compatible with your game version.** See the loader links in the
  [Dawnwalker Mod Menu requirements](https://www.nexusmods.com/thebloodofdawnwalker/mods/271).
- [Dawnwalker Mod Menu](https://www.nexusmods.com/thebloodofdawnwalker/mods/271).
- [ModCore Settings](https://www.nexusmods.com/thebloodofdawnwalker/mods/590).
- [ModCore Templates](https://www.nexusmods.com/thebloodofdawnwalker/mods/641).

## Installation

1. Close the game and install the requirements using their instructions.
   UE4SS itself does not install inside the Mods folder.
2. Extract this download so `9_ModCore_Preymonition` sits directly inside the
   game's `ue4ss/Mods` folder. Avoid an extra nested
   `9_ModCore_Preymonition/9_ModCore_Preymonition` folder.
3. Enable the mods in your UE4SS setup or mod manager, then restart the game.

## Settings

Open **Mod Settings → Preymonition**, set **Preymonition** to **Yes**, and choose
**Apply**. Adjust **Size** on the same page: **Small**, **Standard** (the default)
or **Large**. Choose **Apply** after changing it.

## If the cue does not appear

- Confirm **Preymonition** is set to **Yes** on its settings page and choose **Apply**.
- Check during combat while the game's original indicator shows an attack direction.
- Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings and ModCore Templates are
  installed and enabled, then restart the game.
- If another mod changes the original attack indicator, try disabling it to
  check for a conflict.

## Updating or removing

Close the game before updating and keep your saved settings. Do not replace
them with example defaults.

To stop the extra cue, set **Preymonition** to **No** on its settings page and
choose **Apply**. To uninstall, close the game, disable or remove
`9_ModCore_Preymonition`, and restart. Keep dependencies used by other mods.
