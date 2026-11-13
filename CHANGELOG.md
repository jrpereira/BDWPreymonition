# Changelog

## v1.4.0

- Requires ModCore Templates 1.7.0 or later, which names the attacker behind each attack.
- New Countdown template (Countdown Overlay), with its own Position (Below, Middle, Above):
  the time left to the attack's parry window above a yellow bar that runs down. When
  ModCore Templates names the attacker, the time comes from the attack's hit window in the
  game; otherwise it is an estimate, 0.3 s times the difficulty's parry window multiplier.
  NOW shows in red only when the game opens the parry window, and its bar runs down until
  the hit window ends (or over a second); it all goes when the attack resolves.
- The Center template is now Omens (Omens Overlay): the attack shown as symbols. Its settings are saved under `MCT_Preymonition_Omens_*`; values saved under
  `MCT_Preymonition_Center_*` are not carried over.
- Every setting has a description in the menu.
- Parry & Block Indicator → Prioritize Perfection over Buildup (default Off): the arrow
  animates, red, once the parry window opens. Buildup visibility (Hidden, Faint, Normal)
  and Buildup animation (Static, Partial to 30%, Normal) set how the yellow arrow shows and
  moves before then; the parry window carries it on from there, and the arrow's sound
  plays only then. Hidden and Static by default. The Background is unaffected.
- New Background template (Background Overlay): the shield moves out of the Omens into a
  template of its own, drawn under them, with Position, Visibility (In Combat, Defending,
  Critical; the template's Enabled replaces Off) and Size (5% to 100% of the screen height,
  default 50%). Defending now shows the shield a see-through yellow, the arrows' colour,
  while an attack is shown (was faint white), then red once its parry window opens. Its
  settings are saved under `MCT_Preymonition_Background_*`; the Omens' Shield Visible and
  Shield Scale values are not carried over. The Omens line up on the shield at its default
  size.
- The Solid arrow no longer shows a brighter line down its middle while it fades.
- The Chevron arrow's two arms meet at the tip instead of showing apart.
- Fancy arrows sit centred on their direction, with their tip where Solid and Chevron put theirs, instead of off to one side.
- Parry & Block Indicator → Size reaches twice as far: 100% is now 50% of the screen height
  (was 25%); 0% stays 5%. It defaults to 30% to 80% (was 10% to 50%).
- Parry & Block is now Parry & Block Indicator and Unblockable Attack is Unblockable Attack
  Indicator; their settings drop "Indicator" from their names (Style, Size, Movement from
  Center).
- Unblockable Attack Indicator → Size is a range on 0%–100% (default 60% to 100%): the skull
  appears at the low end's size and grows to the high end's, from 5% of the screen height at
  0% to the full screen height at 100%. A saved single size falls back to the default.
- Indicator Movement is now Movement from Center, a range on 0%–100% (default
  40% to 60%) of the space the arrow has: at 0% the arrow, at its starting size, has its
  back edge on the cue's centre; at 100% its tip is at the screen edge it travels towards.
  Its tip appears at the low end and stops at the high end. A saved single Movement value
  falls back to the default.

## v1.3.0

- Requires ModCore Settings 1.5.0 or later and ModCore Templates 1.6.0 or later, for range
  settings.
- The mod draws its own arrows instead of using the game's sprite. Indicator Style is Off,
  Solid (a triangle), Chevron (the default), Perspective (the Chevron on a plane at the
  character's waist, seen from above) or Fancy (painted glowing arrows from the mod's
  `images` folder). Drawn arrows use the arrow colour with a dimmer inset and a thin black
  outline, and have a 135 degree tip.
- Indicator Size is a range from 0% to 100% (default 10% to 50%): the size an arrow
  appears at and the size it grows to. An arrow grows by extending its lines from the tip,
  so its outline keeps its thickness.
- Indicator Movement runs from 0% to 100% (default 70%): the share of the way the tip
  travels to 35% of the screen. An arrow appears with its back edge 5% of the screen out
  from the cue's centre.
- The Trailing effect (Glow and Fade) is removed.
- Left and right arrows, and Directional edges, show on the side of the screen where the
  game shows its own left and right indicators.

## v1.2.3

- Requires ModCore Settings 1.4.0 or later and ModCore Templates 1.5.0 or later, which name
  templates by `id` and `label`. Center and Edges declare them (Center Overlay, Edges Overlay).
  Center's Position, Shield Visible and Shield Scale are standalone settings and Edges' Screen
  Edges shows no heading, so their rows sit directly under the template's toggle. Center's
  Display Shield is now Shield Visible and its Opportunity option is Critical, Scale is Shield
  Scale, and Parry & Block's Size and Unblockable size are both Indicator Size.
- Sounds play by default: Chime for parry and block cues, Growl for unblockable attacks.
- Indicator Style no longer offers Glow; a saved Glow falls back to Arrows.
- Shield Visible defaults to Defending and Unblockable Attack's Indicator Size to 120%.

## v1.2.2

- Requires UE4SSLuaEventBridge 1.2.0 or later. Requirements follow minor versions
  now, so ModCore Settings 1.3.0 and ModCore Templates 1.4.0 or later are enough. No change to cues or settings.

## v1.2.1

- Requires ModCore Settings 1.3.1 or later and ModCore Templates 1.4.1 or later. No change to cues or settings.

## v1.2.0

- Requires ModCore Templates 1.4.0 or later, which follows the indicator's own state
  change through UE4SSLuaEventBridge function hooks, and UE4SSLuaEventBridge 1.1.0 or
  later. The cue changes on the next engine tick, about a frame after the game's indicator.
- The early warning is gone, from both the center cue and the edges: the game's early
  warning arrives in the same frame as the attack's arrow.
- The `acceptance.txt` developer aid is gone.

## v1.1.1

- Requires ModCore Settings 1.3.0 or later, which plays the previewing sound choices and
  reads the `conditions` rules in its menu data. No change to the cue.

## v1.1.0

- Two templates in place of one, each with its own Enabled: Center, the cue near the
  middle of the screen, and Edges, the screen edge glows, with an Edge Style of Framed
  or Directional. Settings are saved under `MCT_Center_*` and `MCT_Edges_*`; earlier
  `MCT_Preymonition_*` values are ignored.
- General Options at the top of the Center settings: Scale (−50% to 200%) resizes the
  shield, Position puts the cue Below, in the Middle (the default) or Above, and
  Display Shield moves here. The cue is twice its former size.
- Parry & Block sounds are Chime and Swish; Long Swoosh is gone.
- Requires ModCore Templates 1.3.0 or later, which watches the game's attack indicator
  and delivers it as `MC_NPCAttackIndicator`; Preymonition no longer hooks the game.
- The arrows take their artwork from the indicator blueprint when the cue attaches
  instead of copying it from the live indicator during an attack.
- The `probe.txt` and `preview.txt` developer aids are gone.

## v1.0.1

- Requires ModCore Settings 1.2.0 or later, which ModCore Templates 1.2.0 needs for
  its Templates tab. ModCore Templates 1.1.0 or later still works.
- The Combat Preymonition settings no longer set a menu row level on the Main
  Options, Parry & Block Indicator and Unblockable Attack sections; they follow the
  menu's default nesting.

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
