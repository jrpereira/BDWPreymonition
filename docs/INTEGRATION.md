# Mod Menu integration

The manifest uses `[Mod]` identity plus `[Setting.Id]` entries
mapping numeric toggles into `[General]` in `config.ini`. DMM handles preview,
dirty state, Apply and persistence. Subscribe once to `Preymonition` using the
vendored `dmm_api.lua`; read the committed file on the game thread after a
notification. Repeated notifications coalesce; unchanged settings are a no-op.
Malformed Apply content preserves the previous valid runtime state.

The vendored helper implements DMM notification protocol v1; it transfers numeric
setting data via shared variables and a console command between isolated UE4SS Lua
states. It does not import another gameplay mod.
Keep protocol updates coordinated with DMM. Never add file polling as a fallback.
The feature lifecycle is owned by `runtime.lua`; disabling it unregisters native
hooks, invalidates deferred callbacks, cancels animation work, and removes its widget.

For new settings, update the manifest, distribution defaults, parser and tests
together. Do not retain stale Unreal object references across load transitions.
See `FEATURE.md` for the hook, world-selection, and animation contract.

## Optional TE template

The installable template entry point is `Preymonition/Scripts/preymonition.lua`.
TE registers that path externally; Preymonition does not auto-register it.
Keep its `Preymonition` collection identity, `npc.attacks` category, and
disabled-by-default selector setting when changing the contract.
