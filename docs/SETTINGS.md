# Combat Preymonition settings

Combat Preymonition does not ship a `mod_settings.ini`. Compatibility with `mod_settings.ini` is implemented by ModCore Templates.

Templates are reusable components. A module that uses a template gains the template's settings and shows them as its own. When the game starts, ModCore Templates collects the settings of every installed template and ModCore Settings builds the menu pages from them, so the pages always match what is installed.

Change these settings in the mod menu and press Apply. Each template below names the `config.ini` that keeps its values, in the `[Templates]` section, with the keys and numbers listed. A saved value that is not valid falls back to its default.

## Templates in this module

### Omens Overlay

Show the incoming attack as symbols: an arrow for its direction, or a picture when it cannot be blocked.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Omens Overlay (`MCT_Preymonition_Omens_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

#### Parry & Block Indicator

| Setting | Options | Default | Key |
|---|---|---|---|
| Style | Off (`off`), Chevron (`chevron`), Fancy (`fancy`), Solid (`solid`); the list follows the files in the mod folder each time the menu opens | Chevron | `MCT_Preymonition_Omens_ParryStyle` |
| Position | Below (`below`), Middle (`middle`), Above (`above`) | Middle | `MCT_Preymonition_Omens_ParryPosition` |
| Size | A low and a high value from 0% to 100%, in steps of 10; at least 10% apart | 30% to 80% | `MCT_Preymonition_Omens_ParrySize` |
| Movement from Center | A low and a high value from 0% to 100%, in steps of 5 | 40% to 60% | `MCT_Preymonition_Omens_ParryMovement` |
| Attack Incoming | Normal (`normal`), Faint (`faint`), Off (`off`) | Normal | `MCT_Preymonition_Omens_ParryIncoming` |
| Perfect Opportunity | End (`end`), Start (`start`), Halfway (`halfway`), Off (`off`) | End | `MCT_Preymonition_Omens_ParryPerfect` |

#### Unblockable Attack Indicator

| Setting | Options | Default | Key |
|---|---|---|---|
| Style | Off (`off`), Cracked (`cracked`), Ember (`ember`), Fiend (`fiend`), Gore (`gore`), Shattered (`shattered`), Splatter (`splatter`); the list follows the files in the mod folder each time the menu opens | Fiend | `MCT_Preymonition_Omens_UnblockableStyle` |
| Size | A low and a high value from 0% to 100%, in steps of 10 | 60% to 100% | `MCT_Preymonition_Omens_UnblockableSize` |

### Audio Cues

Play a sound when an attack comes: as its parry window opens, as its Perfect Opportunity window opens, and for an unblockable attack.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Audio Cues (`MCT_Preymonition_Audio_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

#### Sounds

| Setting | Options | Default | Key |
|---|---|---|---|
| Attack incoming | None (`none`), Bass (`bass`), Beep (`beep`), Bell (`bell`), Clink (`clink`), Crow (`crow`), Crunch (`crunch`), Ding (`ding`), Hit (`hit`), Hmmm (`hmmm`), Matches (`matches`), Ominous (`ominous`), Ping (`ping`), Plate (`plate`), Rattle (`rattle`), Ring (`ring`), Ruffle (`ruffle`), Rumble (`rumble`), Scrape (`scrape`), Snare (`snare`), Stretch (`stretch`), Sword (`sword`), Synth (`synth`), Whisper (`whisper`); the list follows the files in the mod folder each time the menu opens | Rumble | `MCT_Preymonition_Audio_SoundIncoming` |
| Perfect Opportunity | None (`none`), Bass (`bass`), Beep (`beep`), Bell (`bell`), Clink (`clink`), Crow (`crow`), Crunch (`crunch`), Ding (`ding`), Hit (`hit`), Hmmm (`hmmm`), Matches (`matches`), Ominous (`ominous`), Ping (`ping`), Plate (`plate`), Rattle (`rattle`), Ring (`ring`), Ruffle (`ruffle`), Rumble (`rumble`), Scrape (`scrape`), Snare (`snare`), Stretch (`stretch`), Sword (`sword`), Synth (`synth`), Whisper (`whisper`); the list follows the files in the mod folder each time the menu opens | Ding | `MCT_Preymonition_Audio_SoundPerfect` |
| Unblockable Attack | None (`none`), Bleah (`bleah`), Creature (`creature`), Evil (`evil`), Growl (`growl`), Heart (`heart`), Pulse (`pulse`), Roar (`roar`), Serpent (`serpent`), Trebble (`trebble`); the list follows the files in the mod folder each time the menu opens | Growl | `MCT_Preymonition_Audio_SoundUnblockable` |

#### Options

| Setting | Options | Default | Key |
|---|---|---|---|
| Enable directional sound | Off (`0`), On (`1`) | On | `MCT_Preymonition_Audio_OptionsDirectional` |
| Differentiate back/front by pitch<br>*Shown when Enable directional sound is On.* | A low and a high value from -50% to 50%, in steps of 5 | -20% to 20% | `MCT_Preymonition_Audio_OptionsPitch` |
| Sound volume | 0% to 200%, in steps of 10 | 100% | `MCT_Preymonition_Audio_OptionsVolume` |

### Edges Flash

Light the screen edges while an attack is incoming.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Edges Flash (`MCT_Preymonition_Edges_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

#### Activate Edges

| Setting | Options | Default | Key |
|---|---|---|---|
| Attack incoming | Off (`0`), On (`1`) | On | `MCT_Preymonition_Edges_ActivateIncoming` |
| Perfect Opportunity | Off (`0`), On (`1`) | On | `MCT_Preymonition_Edges_ActivatePerfect` |
| Unblockable Attack | Off (`0`), On (`1`) | On | `MCT_Preymonition_Edges_ActivateUnblockable` |

#### Visuals

| Setting | Options | Default | Key |
|---|---|---|---|
| Style | Bands (`bands`), Linear (`linear`), Soft (`soft`); the list follows the files in the mod folder each time the menu opens | Soft | `MCT_Preymonition_Edges_VisualsStyle` |
| Thickness | 2% to 20%, in steps of 1 | 8% | `MCT_Preymonition_Edges_VisualsThickness` |
| Intensity | 10% to 100%, in steps of 5 | 50% | `MCT_Preymonition_Edges_VisualsIntensity` |

### Countdown (WIP)

Count down to the incoming attack's Perfect Opportunity window, then show NOW while it is open.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Countdown (WIP) (`MCT_Preymonition_Countdown_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

| Setting | Options | Default | Key |
|---|---|---|---|
| Position | Below (`below`), Middle (`middle`), Above (`above`) | Middle | `MCT_Preymonition_Countdown_Position` |
