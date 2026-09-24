# Premonition

Keep incoming attack directions in sight with animated cues near the bottom center of your screen. Repeats the game’s directional shield indicator so you can spend less time hunting for the warning—and more time getting hit in the face like a pro that saw it coming.

## What it does

Premonition repeats the current attacker's directional warning near the bottom
center of the screen. Animated arrows highlight the direction shown by the
original shield cue, then fade when combat ends.

It makes the warning easier to keep in view. Blocking, dodging, and taking the
credit remain your responsibility.

## Requirements

- **UE4SS for your Dawnwalker game version.** See the loader links in the
  [Dawnwalker Mod Menu requirements](https://www.nexusmods.com/thebloodofdawnwalker/mods/271).
- [Dawnwalker Mod Menu](https://www.nexusmods.com/thebloodofdawnwalker/mods/271)
  for the settings page.

Premonition does not require ModCoreSettings, ModCoreControls, ModCoreTemplates,
or UE4SSLuaEventBridge.

## Installation

1. Close the game completely. Extract the mod download so its `Premonition`
   folder sits directly inside the game's `ue4ss/Mods` folder.
2. Download any missing dependencies above and install them with the game closed.
   Follow each download's instructions if it includes the full game-folder path.
   UE4SS itself does not install inside `Mods`.
3. Ensure the mods are enabled in your UE4SS setup or mod manager, then restart
   the game. Avoid an extra nested `Premonition/Premonition` folder.

## Settings

Open **Mod Settings → Premonition**, change a setting, and choose **Apply**.

| Setting | Recommended choice |
|---|---|
| **Enable Premonition** | **On** to display the extra attack cue; **Off** to remove it. |
| **Debug logging** | Leave **Off** unless troubleshooting. It records configuration changes. |

Premonition starts enabled. On a supported menu version, Apply updates it during
play. With older versions of Dawnwalker Mod Menu, restart the game after saving.

## If the cue does not appear

- Confirm **Enable Premonition** is On and choose Apply.
- Check during combat while the game's original indicator shows an attack direction.
- Confirm UE4SS and Dawnwalker Mod Menu are enabled, then restart the game.
- If another mod changes the original attack indicator, try disabling that mod
  to check for a conflict.

This version is awaiting in-game verification of warning delivery and animation.

## Updating or removing

Close the game before updating and keep your existing saved settings. Do not
replace them with example defaults. To stop the extra cue, turn the mod Off and
Apply. To uninstall, close the game, disable or remove the `Premonition` folder,
and restart. Keep dependencies used by other mods.

See the [changelog](CHANGELOG.md) for changes.
