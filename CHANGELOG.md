# Changelog

## v1.0.0

- Rename the mod to Combat Preymonition and move it to ModCore Templates'
  npc.attacks category. The game's styling call is hooked only during combat,
  so outside combat the mod costs nothing.
- List UE4SS Lua Event Bridge as a requirement. Requires ModCore Templates 1.1.0
  or newer.
- Keep the unblockable skull when the game updates a hidden copy of the indicator.
- Keep cue widget names unique after a Lua reload.
- Cut the cue's work per attack and per animation frame by about two thirds:
  widgets resolve once per call, frames write only what changed, and the
  skull and chosen sounds load when the cue attaches instead of mid-combat.
- Log a repeating failure once per combat instead of on every call.
- Rename the installed mod folder to `9_ModCore_Preymonition`.
- Move the cue just below the screen center and redesign it: an arrow flashes in
  from the attack's direction, travels outward, turns red when the attack becomes
  critical, and vanishes as soon as the attack lands or is deflected.
- Show a skull for unblockable attacks.
- Follow the visible indicator only, and update in the same frame as the game.
- Add cue settings: background shield, arrow movement and size, trailing glow,
  unblockable size, and optional sounds for arrows and unblockable attacks.
- Fix a crash when the HUD is rebuilt, such as on a level load or reload.

## v0.2.0

- Rebuild Preymonition as a ModCoreTemplates notification template. MCT now
  finds the HUD and hosts the cue; settings appear on the module page.
- Add a Size setting (Small, Standard, Large).
- Require ModCoreSettings and ModCoreTemplates. The standalone settings page,
  Enable and Debug toggles are replaced by the MCT template toggle.

## v0.1.1

- Add a combined player guide with installation, settings, and troubleshooting.
- Add project metadata and dependency links. Gameplay behavior is unchanged.

## v0.1.0

- Add an animated attack-direction cue near the bottom center of the screen,
  using the game's shield and arrow artwork.
- Update the arrow when the attack direction changes, including repeated attacks
  from the same direction.
