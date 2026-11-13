# Combat Preymonition settings

Combat Preymonition does not ship a `mod_settings.ini`. Compatibility with `mod_settings.ini` is implemented by ModCore Templates.

Templates are reusable components. A module that uses a template gains the template's settings and shows them as its own. When the game starts, ModCore Templates collects the settings of every installed template and ModCore Settings builds the menu pages from them, so the pages always match what is installed.

Change these settings in the mod menu and press Apply. Each template below names the `config.ini` that keeps its values, in the `[Templates]` section, with the keys and numbers listed. A saved value that is not valid falls back to its default.

## Templates in this module

### Omens Overlay

Show the incoming attack as symbols: an arrow for its direction, or a skull when it cannot be blocked.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Omens Overlay (`MCT_Preymonition_Omens_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

| Setting | Options | Default | Key |
|---|---|---|---|
| Position | Below (`0`), Middle (`1`), Above (`2`) | Middle | `MCT_Preymonition_Omens_GeneralPosition` |

#### Parry & Block Indicator

| Setting | Options | Default | Key |
|---|---|---|---|
| Style | Off (`0`), Solid (`1`), Chevron (`2`), Perspective (`3`), Fancy (`4`) | Chevron | `MCT_Preymonition_Omens_ParryStyle` |
| Size | A low and a high value from 0% to 100%, in steps of 10; at least 10% apart | 30% to 80% | `MCT_Preymonition_Omens_ParrySize` |
| Movement from Center | A low and a high value from 0% to 100%, in steps of 5 | 40% to 60% | `MCT_Preymonition_Omens_ParryMovement` |
| Play sound | None (`0`), Chime (`1`), Swish (`2`) | Chime | `MCT_Preymonition_Omens_ParrySound` |
| Prioritize Perfection over Buildup | Off (`0`), On (`1`) | Off | `MCT_Preymonition_Omens_ParryPerfection` |
| Buildup visibility<br>*Shown when Prioritize Perfection over Buildup is On.* | Hidden (`0`), Faint (`1`), Normal (`2`) | Hidden | `MCT_Preymonition_Omens_ParryBuildupVisibility` |
| Buildup animation<br>*Shown when Prioritize Perfection over Buildup is On.* | Static (`0`), Partial (`1`), Normal (`2`) | Static | `MCT_Preymonition_Omens_ParryBuildupAnimation` |

#### Unblockable Attack Indicator

| Setting | Options | Default | Key |
|---|---|---|---|
| Size | A low and a high value from 0% to 100%, in steps of 10 | 60% to 100% | `MCT_Preymonition_Omens_UnblockableSize` |
| Play sound | None (`0`), Growl (`1`), Boom (`2`) | Growl | `MCT_Preymonition_Omens_UnblockableSound` |

### Edges Overlay

Light the screen edges while an attack is incoming.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Edges Overlay (`MCT_Preymonition_Edges_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

#### Screen Edges

| Setting | Options | Default | Key |
|---|---|---|---|
| Edge Style | Framed (`1`), Directional (`2`) | Framed | `MCT_Preymonition_Edges_EdgeStyle` |

### Countdown Overlay

Count down to the incoming attack's parry window, then show NOW while it is open.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Countdown Overlay (`MCT_Preymonition_Countdown_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

| Setting | Options | Default | Key |
|---|---|---|---|
| Position | Below (`0`), Middle (`1`), Above (`2`) | Middle | `MCT_Preymonition_Countdown_Position` |

### Background Overlay

Show a shield behind the omens: yellow while an attack is shown, red once its parry window opens.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Background Overlay (`MCT_Preymonition_Background_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

| Setting | Options | Default | Key |
|---|---|---|---|
| Position | Below (`0`), Middle (`1`), Above (`2`) | Middle | `MCT_Preymonition_Background_Position` |
| Visibility | In Combat (`1`), Defending (`2`), Critical (`3`) | Defending | `MCT_Preymonition_Background_Visibility` |
| Size | 5% to 100%, in steps of 5 | 50% | `MCT_Preymonition_Background_Size` |
