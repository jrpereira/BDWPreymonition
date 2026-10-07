# Changelog

## Unreleased

- Rename the installed mod folder to `9_ModCore_Preymonition`.
- Move the cue just below the screen center and redesign it: an arrow flashes in
  from the attack's direction, travels outward, turns red when the attack becomes
  critical, and vanishes as soon as the attack lands or is deflected.
- Show a skull for unblockable attacks.
- Follow the visible indicator only, and update in the same frame as the game.
- Add cue settings: background shield, arrow movement and size, trailing glow,
  unblockable size, and optional sounds for arrows and unblockable attacks.
- Fix a crash when the HUD is rebuilt, such as on a level load or reload.

## 0.2.0

- Rebuild Preymonition as a ModCoreTemplates notification template. MCT now
  finds the HUD and hosts the cue; settings appear on the module page.
- Add a Size setting (Small, Standard, Large).
- Require ModCoreSettings and ModCoreTemplates. The standalone settings page,
  Enable and Debug toggles are replaced by the MCT template toggle.

## 0.1.1

- Add a combined player guide with installation, settings, and troubleshooting.
- Add project metadata and dependency links. Gameplay behavior is unchanged.

## 0.1.0

- Add an animated attack-direction cue near the bottom center of the screen,
  using the game's shield and arrow artwork.
- Update the arrow when the attack direction changes, including repeated attacks
  from the same direction.
