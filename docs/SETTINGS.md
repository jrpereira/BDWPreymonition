# Combat Preymonition settings

Combat Preymonition does not ship a `mod_settings.ini`. Compatibility with `mod_settings.ini` is implemented by ModCore Templates.

Templates are reusable components. A module that uses a template gains the template's settings and shows them as its own. When the game starts, ModCore Templates collects the settings of every installed template and ModCore Settings builds the menu pages from them, so the pages always match what is installed.

Change these settings in the mod menu and press Apply. Each template below names the `config.ini` that keeps its values, in the `[Templates]` section, with the keys and numbers listed. A saved value that is not valid falls back to its default.

## Templates in this module

### Center Overlay

Repeat the incoming attack direction near the center of the screen.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Center Overlay (`MCT_Preymonition_Center_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

| Setting | Options | Default | Key |
|---|---|---|---|
| Position | Below (`0`), Middle (`1`), Above (`2`) | Middle | `MCT_Preymonition_Center_GeneralPosition` |
| Shield Visible | Off (`0`), In Combat (`1`), Defending (`2`), Opportunity (`3`) | Off | `MCT_Preymonition_Center_GeneralShield` |
| Shield Scale | -50% to 200%, in steps of 10 | 0% | `MCT_Preymonition_Center_GeneralScale` |

#### Parry & Block

| Setting | Options | Default | Key |
|---|---|---|---|
| Indicator Style | Off (`0`), Arrows (`1`), Glow (`2`) | Arrows | `MCT_Preymonition_Center_ParryStyle` |
| Size | 50% to 200%, in steps of 10 | 100% | `MCT_Preymonition_Center_ParrySize` |
| Indicator Movement | 50% to 200%, in steps of 10 | 100% | `MCT_Preymonition_Center_ParryMovement` |
| Trailing effect | Off (`0`), Glow (`1`), Fade (`2`) | Glow | `MCT_Preymonition_Center_ParryTrail` |
| Play sound | None (`0`), Chime (`1`), Swish (`2`) | None | `MCT_Preymonition_Center_ParrySound` |

#### Unblockable Attack

| Setting | Options | Default | Key |
|---|---|---|---|
| Unblockable size | 50% to 200%, in steps of 10 | 100% | `MCT_Preymonition_Center_UnblockableSize` |
| Play sound | None (`0`), Growl (`1`), Boom (`2`) | None | `MCT_Preymonition_Center_UnblockableSound` |

### Edges Overlay

Light the screen edges while an attack is incoming.

- **Category:** NPC Attacks. The settings appear on this module's page.
- **Turn on:** set Edges Overlay (`MCT_Preymonition_Edges_Enabled`) to Enabled (`1`).
- **Saved in:** `9_ModCore_Preymonition/config.ini`, section `[Templates]`.

#### Screen Edges

| Setting | Options | Default | Key |
|---|---|---|---|
| Edge Style | Framed (`1`), Directional (`2`) | Framed | `MCT_Preymonition_Edges_EdgeStyle` |
