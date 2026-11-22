# Changelog

## Unreleased

- Parry & Block Indicator → Movement from Center is now Travel (`ParryTravel`), just below
  Opacity.
- The Countdown is no longer marked as a work in progress.
- The Countdown's time is centred over its bar instead of at its right end.
- The Countdown has positions of its own instead of following the Omens' cue area: at
  the default size its bar ends 77.5% (Below), 55% (Middle) or 32.5% (Above) of the
  screen height down, where it was 85%, 70% and 55%.
- New Countdown → Size, a range on 5% to 100% (10%–10% by default, the size so far):
  the size as the count starts and as it reaches the Perfect Opportunity window, growing
  as it runs down. The bar grows to three times its size at 100% and the time to a line
  70% of the screen height tall; the countdown stays centred where it is at 10% for its
  Position, kept on screen.
- New Countdown → Style, first on its page: Full (the time above the bar), Bar only or
  Label only.
- New Countdown → Show direction in label (Off by default): in the Perfect Opportunity
  window the label shows the attack's direction, UP, DOWN, LEFT or RIGHT, the way the
  Omens' arrow points, instead of NOW. Hidden with Style Bar only.
- New Countdown → Opacity, a range (50%–70% by default): the countdown appears at the low
  end and reaches the high end at the Perfect Opportunity window. It replaces the fixed
  full opacity; the bar and outline keep their half see-through colours within it.
- Every Size, Opacity and Travel range accepts equal ends, which hold the value still;
  the Omens' Size and Opacity no longer need their ends 10% apart.
- Log levels no longer come from `log_level.txt`. With the UE4SS Lua Log Bridge installed they
  are set on its Logs page or under `[Levels]` in its `config.ini`; without it, WARN and above.
- New Unblockable Attack Indicator → Opacity, a range (50%–80% by default): the picture
  appears at the low end and reaches the high end as it grows. It replaces the fixed 50%.

## v1.5.1

- Solid and Chevron are pictures in `images/` like Fancy, and a Style whose picture does
  not load shows no arrows.
- Up and down arrows travel the same distance at any Position, as far as the nearer of
  the top and bottom screen edges.
- The Background template is removed.
- Parry & Block Indicator → Style lists the styles found in the `images` folder
  after Off: each `omen_<style>.png`, Chevron, Fancy and Solid among them. A
  style is one picture with its glow and white core side by side; the mod tints the glow
  yellow, or red in the Perfect Opportunity window.
  A picture that is not a 1774 by 1774 PNG is left out of the list.
- Requires ModCore Templates 1.9.1 or later, which starts the Audio Cues on, and
  ModCore Settings 1.9.0 and UE4SS Lua Event Bridge 1.3.0 or newer.
- The Omens' Style and Position and the Countdown's Position save their choice by name
  (`ParryStyle=chevron`, `Position=middle`) instead of a number. Choices saved before for
  them reset to their defaults once.
- The Omens' Perspective Style is removed. A saved Perspective shows Chevron.
- New Audio Cues template: the sounds move out of the Omens into a template of their
  own, with its own Enabled, so they can play with the arrows off or on their own. Its
  Sounds group holds Attack incoming, Perfect Opportunity and Unblockable Attack; its
  Options group holds Enable directional sound, Differentiate back/front by pitch and
  Sound volume.
- Attack incoming plays as soon as an attack is first seen, as its parry window opens,
  whatever the Omens' Attack Incoming and Perfect Opportunity, and whether or not the
  Omens are on. Before, it followed the arrow and was skipped while the yellow arrow was
  held back. Perfect Opportunity plays when its Perfect Opportunity window opens, and a
  repeated event for the same attack never plays a sound again.
- An attack reported again in the same direction while its arrow still shows no longer
  flashes the arrow in again or replays its sound: it counts as the attack shown, and the
  arrow goes once all of them resolve.
- Templates are named Omens Overlay, Audio Cues, Edges Flash and Countdown (WIP).
  The Countdown is marked as a work in progress.
- Descriptions name the red arrow's window the Perfect Opportunity window: the parry
  window opens with the yellow arrow, when the attack is first shown.
- The preview's sound button: on Auto it sounds while an Audio Cues setting is
  selected; On always; Off never.
- Selecting a sound in Attack incoming, Perfect Opportunity or Unblockable Attack plays it,
  centred, so you hear what you pick.
- The Combat Preymonition page shows a live preview of every template, the Omens
  Overlay, Audio Cues, Edges Flash and Countdown: four attacks and an
  unblockable one, looping over a game scene, drawn and sounded with the page's current
  settings before they are applied.
- New Sounds section replaces the Play sound rows: Attack incoming (when the
  parry window opens, the yellow arrow), Perfect Opportunity (when the Perfect Opportunity
  window opens, the red arrow) and Unblockable Attack (default Growl).
- Attack incoming and Perfect Opportunity play the mod's own cue sounds (Bass, Bell, Clink,
  Ding, Whisper and more) instead of the game's: the `cue_<name>.wav` files in its `sounds`
  folder, listed each time the menu opens, so a file dropped in while the game runs is
  offered the next time. Default Rumble and Ding. They are saved by name
  (`SoundIncoming=ding`), so new files never move a saved choice. They play through UE4SS
  Lua Sound Bridge; without it, or when the chosen file is gone, they are silent.
- Unblockable Attack plays the mod's own sounds too (Bleah, Creature, Evil, Growl, Heart,
  Pulse, Roar, Serpent): the `unblockable_<name>.wav` files in the `sounds` folder, listed
  the same way. Default Growl. Growl and Boom, the game's sounds, are gone.
- New Enable directional sound (default On): a side arrow's sound plays on the side the
  arrow shows on, and ahead and behind are set apart by pitch, behind also muffled. New
  Differentiate back/front by pitch, -50% to +50% (default -20% behind, +20% ahead), and
  Sound volume, 0% to 200% (default 100%), for all of these sounds, relative to the game's
  Effects volume times its Master volume, and silent when the game is muted; changes in the
  game's audio settings apply from the next fight.
- The bundled sounds are mono 48 kHz, matched in loudness (unblockable sounds a little
  louder) and cut to start at once.
- Requires UE4SS Lua Sound Bridge 1.1.0 or newer for the sounds.
- Position moves into Parry & Block Indicator and places only the arrows; the unblockable
  indicator stays at the screen's centre.
- New Unblockable Attack Indicator → Style: Off, Fiend (default), Gore, Cracked, Shattered,
  Ember or Splatter, the mod's own pictures in place of the game's low-resolution skull.
  Only the chosen picture loads. The list follows the `unblockable_<name>.png` files in the
  `images` folder each time the menu opens, and the choice is saved by name
  (`UnblockableStyle=fiend`).
- Parry & Block Indicator → Attack Incoming (Normal, Faint, Off) and Perfect Opportunity
  (End, Start, Halfway, Off) replace Prioritize Perfection over Buildup, Buildup visibility
  and Buildup animation, and saved Buildup choices are ignored. Attack Incoming sets how
  the Yellow arrow shows before the Perfect Opportunity window; Perfect Opportunity sets
  how the red arrow takes over: at the end of the yellow arrow's course, from its start,
  halfway, or not at all (Off shows only the yellow arrow).
- New Edges Flash → Activate Edges group replaces Edge Style: Attack incoming lights the
  edge on the attack's side yellow when its parry window opens, Perfect Opportunity red
  when its Perfect Opportunity window opens, and Unblockable Attack every edge red while
  an unblockable attack shows, over the attack's own edge. Each is an On/Off switch, On
  by default. Edges always light the attacked side only; a saved Edge Style is ignored.
- New Edges Flash → Visuals group: Style, Bands or a smooth gradient picture, Linear or
  Soft (default). The list follows the `edge_<name>_v.png` and `edge_<name>_h.png`
  pairs in the `images` folder each time the menu opens, and the choice is saved by name
  (`VisualsStyle=soft`). A gradient whose pictures cannot load draws Bands. Thickness,
  2% to 20% of the shorter screen side (default 8%), and Intensity, the glow's opacity at
  the screen edge, 10% to 100% (default 50%), apply to Bands and gradients alike.
- Settings saved under the old Position, Play sound and Prioritize Perfection keys are
  ignored.

## v1.4.0

- Requires ModCore Settings 1.6.0 or later and ModCore Templates 1.7.0 or later, which
  names the attacker behind each attack.
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
