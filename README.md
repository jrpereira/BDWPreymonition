# PREYMONITION

*You see them coming. They won't.*

Keep incoming attack directions in sight with animated cues near the bottom center of your screen. Repeats the game’s directional shield indicator so you can spend less time hunting for the warning—and more time getting hit in the face like a pro that saw it coming.

## What it does

Preymonition repeats the current attacker's directional warning near the bottom
center of the screen. Animated arrows highlight the direction shown by the
original shield cue, then fade when combat ends.

It makes the warning easier to keep in view. Blocking, dodging, and taking the
credit remain your responsibility.

## Requirements

- **UE4SS for your Dawnwalker game version.** See the loader links in the
  [Dawnwalker Mod Menu requirements](https://www.nexusmods.com/thebloodofdawnwalker/mods/271).
- [Dawnwalker Mod Menu](https://www.nexusmods.com/thebloodofdawnwalker/mods/271)
  for the settings page.
- [ModCoreSettings](https://www.nexusmods.com/thebloodofdawnwalker/mods/590)
- [ModCoreTemplates](https://www.nexusmods.com/thebloodofdawnwalker/mods/641),
  which finds the HUD and hosts the cue.

## Installation

1. Close the game completely. Extract the mod download so its `_ModCore_X_Preymonition`
   folder sits directly inside the game's `ue4ss/Mods` folder.
2. Download any missing dependencies above and install them with the game closed.
   Follow each download's instructions if it includes the full game-folder path.
   UE4SS itself does not install inside `Mods`.
3. Ensure the mods are enabled in your UE4SS setup or mod manager, then restart
   the game. Avoid an extra nested `_ModCore_X_Preymonition/_ModCore_X_Preymonition` folder.

## Settings

Open **Mod Settings → ModCore Templates** and turn on **Preymonition** under
Player notifications. Its options are on the **Preymonition** module page; choose
**Apply** after changing them.

| Setting | Choices |
|---|---|
| **Size** | Small, **Standard**, or Large. |

## If the cue does not appear

- Confirm **Preymonition** is turned on in ModCore Templates and choose Apply.
- Check during combat while the game's original indicator shows an attack direction.
- Confirm UE4SS, Dawnwalker Mod Menu, ModCoreSettings and ModCoreTemplates are
  enabled, then restart the game.
- If another mod changes the original attack indicator, try disabling that mod
  to check for a conflict.

This version is awaiting in-game verification of warning delivery and animation.

## Updating or removing

Close the game before updating and keep your existing saved settings. Do not
replace them with example defaults. To stop the extra cue, turn it off in ModCore
Templates and Apply. To uninstall, close the game, disable or remove the `_ModCore_X_Preymonition` folder,
and restart. Keep dependencies used by other mods.

See the [changelog](CHANGELOG.md) for changes.

## Development

Run the tests from the workspace root (beside `ModCoreTemplates`):

```sh
for t in Preymonition/tests/*_test.lua; do lua5.4 "$t" || break; done
```
