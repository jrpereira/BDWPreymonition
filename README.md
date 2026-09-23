# Premonition

UE4SS Lua mod for **The Blood of Dawnwalker** that repeats the current attacker's
directional shield cue at the bottom center of the HUD. Dawnwalker Mod Menu owns
its settings page. Version: `0.1.0`.

## Requirements and installation

- UE4SS and Dawnwalker Mod Menu (DMM).
- Live Apply uses the DMM settings-notification v1 API.
  An older DMM without this API may save settings but requires a game restart to
  apply them. Startup logs report subscription failures when detectable.

Build with `python tools/package.py`, then extract the archive's `Premonition/`
folder into `ue4ss/Mods/`. In the mod settings page, change Enabled or Debug logging
and choose Apply. DMM owns `config.ini`; startup uses safe defaults if it is missing.
`config.example.ini` is a reference only. Preserve an existing `config.ini` on upgrade.

Premonition has no dependency on another gameplay mod, ModMenuDecorator, either
bridge mod, or any diagnostic helper. It uses native UE4SS hooks directly.

## Behavior

When a visible combat indicator highlights a direction, Premonition creates a
bottom-center square sized to 20% of the shorter viewport dimension. The native
shield is a 20%-opacity background with 18px padding. The matching dark-red arrow
grows from 50% to 100% over 300ms, then settles at 80% over 200ms. Replaced arrows
fade and shrink over 100ms. Clearing the source retains the container at 50%; combat
end fades it to zero over 200ms and resets the arrows.

Events are deferred from native hooks onto the game thread through a bounded queue.
One 16ms callback runs only while animation work exists. There is no gameplay poll,
idle timer, global scan during animation, or diagnostic bridge dependency.

## Development

- `Scripts/main.lua`: startup and one Apply subscription.
- `Scripts/config.lua`: validated file-backed settings.
- `Scripts/runtime.lua`: settings and feature lifecycle ownership.
- `Scripts/animation.lua`: deterministic animation timeline.
- `Scripts/events.lua`: bounded native-event queue.
- `Scripts/feature.lua`: hook, stale-callback, and scheduler coordination.
- `Scripts/ue_adapter.lua`: UE4SS hooks, active-world selection, and UMG ownership.
- `Scripts/dmm_api.lua`: vendored DMM notification protocol helper.
- `Scripts/premonition.lua`: TE-compatible attack-notification template, disabled by default and not auto-registered.
- `mod_settings.ini`: DMM page declaration; keep version and defaults aligned.
- `tests/`: offline runtime and package regressions.
- `tools/`: package allowlist and repository safeguards.
- `dist/`: generated ZIP/checksum output, excluded from Git.

Run every `tests/*_test.lua` file with Lua 5.4, then run
`python -m unittest discover -s tests -p "test_*.py" -v`.
CI also compiles runtime, template, and test Lua files. Run `python tools/bootstrap.py` to enable local Git
guards. Release branches `release/vSEMVER` run checks and publish GitHub assets
when this project is connected to a repository.

Settings are read once on startup and after committed Apply events. Previewing a
menu setting does not mutate runtime state. Disabling the mod unregisters its hooks,
cancels pending callbacks, and removes its owned widget.

Offline tests do not prove native hook delivery, rendered placement, animation
smoothness, or combat performance. Before release, test all four directions,
same-direction attacks, source replacement, clear/combat-end ordering, death/reload,
pause, and resolution changes in game.

GitHub repository name: BDWPremonition (owner: jrpereira). The mod identity and source folder remain Premonition.
