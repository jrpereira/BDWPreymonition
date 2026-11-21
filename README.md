# COMBAT PREYMONITION

*You see them coming. They won't.*

Keep incoming attack directions in sight in **The Blood of Dawnwalker**, with
animated cues near the center of your screen. Spend less time hunting for
the warning—and more time getting hit in the face like a pro that saw it coming.

## What it does

Preymonition adds an arrow cue near the center of the screen without
replacing the game's original warning. When an attack comes, an arrow flashes in
from its direction and turns red when the attack becomes critical. It vanishes
once the attack lands or is deflected, so an empty cue means nothing is incoming.
Unblockable attacks show a picture at the screen's centre, a horned skull by default. The cue clears when combat ends.
The screen edges can glow,
sound cues can play as the attack comes, with or without the arrows, and a
countdown can show the time left to the attack's Perfect Opportunity window.

It makes the warning easier to keep in view. Blocking, dodging, and taking the
credit remain your responsibility.

## Requirements

- **UE4SS for your Dawnwalker game version.** See the loader links in the
  [Dawnwalker Mod Menu requirements](https://www.nexusmods.com/thebloodofdawnwalker/mods/271).
- [Dawnwalker Mod Menu](https://www.nexusmods.com/thebloodofdawnwalker/mods/271)
  for the settings page.
- [ModCore Settings](https://www.nexusmods.com/thebloodofdawnwalker/mods/590)
  1.9.0 or newer.
- [ModCore Templates](https://www.nexusmods.com/thebloodofdawnwalker/mods/641)
  1.9.1 or later.
- [UE4SS Lua Event Bridge](https://www.nexusmods.com/thebloodofdawnwalker/mods/526) 1.3.0 or newer, which
  ModCore Templates also requires. Without it no cue appears.
- [UE4SS Lua Sound Bridge](https://github.com/jrpereira/UE4SSLuaEXtensions/releases) 1.1.0 or newer,
  for the Audio Cues. Without it they are silent.

## Installation

1. Close the game completely. Extract the mod download so its `9_ModCore_Preymonition`
   folder sits directly inside the game's `ue4ss/Mods` folder.
2. Download any missing dependencies above and install them with the game closed.
   Follow each download's instructions if it includes the full game-folder path.
   UE4SS itself does not install inside `Mods`.
3. Ensure the mods are enabled in your UE4SS setup or mod manager, then restart
   the game. Avoid an extra nested `9_ModCore_Preymonition/9_ModCore_Preymonition` folder.

## Settings

Combat Preymonition has four parts, each turned on by its own **Enabled**: the
**Omens Overlay**, symbols near the middle of the screen, the **Audio Cues**, sounds for each
attack that play whatever else is on, the **Edges Flash** on the screen edges, which glow while an
attack is incoming, and the **Countdown** to the attack's Perfect Opportunity
window. Open **Mod Settings → Combat Preymonition**, set **Enabled** under
**Omens Overlay**, **Audio Cues**, **Edges Flash**, **Countdown** or any of
them to **Yes**, and choose **Apply**. The Audio Cues can be on alone, for sounds
without the arrows.

An attack has two windows: its **parry window** opens when it is first shown (the
yellow arrow), and its **Perfect Opportunity window** later (the red arrow).
Adjust each part's settings on the same page and choose **Apply** after
changing them.

Every setting, its options and the `config.ini` key it is saved under are listed
in `SETTINGS.md`, next to this file in the installed mod.

| Setting | Choices |
|---|---|
| **Parry & Block Indicator → Style** | Off, then the styles listed from the mod's `images` folder, each a picture `omen_<style>.png`: **Chevron**, Fancy and Solid (a triangle) ship. Solid and Chevron are in the arrow colour with a thin, dimmer inset and a thin black outline; Fancy is a glowing arrow with a white core. The colour is yellow, red in the Perfect Opportunity window, and every arrow scales as a whole as it grows. If a Style's picture does not load, no arrows show. |
| **Parry & Block Indicator → Position** | Where the arrows show: Below (their centre 35% of the screen height above the bottom edge), **Middle** (centred on the screen's middle), or Above (the mirror of Below). Only the arrows move; the unblockable indicator stays at the screen's centre. |
| **Parry & Block Indicator → Size** | A range on 0%–100% (**30%–80%**), its ends at least 10% apart: the low end is the size an arrow appears at, the high end the size it grows to as it travels. Sizes are in units of 5% of the screen height, from 1 unit at 0% to 10 at 100%, so the default grows from 3.7 to 8.2 units. An arrow scales as a whole as it grows. |
| **Parry & Block Indicator → Movement from Center** | A range on 0%–100% (**40%–60%**) of the space the arrow has: at 0% the arrow, at its starting size, has its back edge on the cue's centre; at 100% its tip is at the screen edge it travels towards (up and down travel alike, as far as the nearer of the top and bottom edges). Its tip appears at the low end and stops at the high end, so equal ends keep it still. |
| **Parry & Block Indicator → Opacity** | A range on 0%–100% (**50%–70%**), its ends at least 10% apart: the arrow's opacity as it appears and once its travel ends, changing as it travels. This is the opacity seen on screen; Attack Incoming Faint shows the Yellow arrow at 35% of it (17.5% to 24.5% by default). |
| **Parry & Block Indicator → Attack Incoming** | How the Yellow arrow shows before the Perfect Opportunity window: **Normal**, Faint (35% of Opacity) or Off (not shown). |
| **Parry & Block Indicator → Perfect Opportunity** | How the Perfect Opportunity arrow takes over: **End** (yellow runs its course first, red comes in at the end), Start (yellow doesn't move), Halfway (yellow moves 50%) or Off (only yellow shows, never red; with Attack Incoming Off too, no arrow shows for attacks). The unblockable indicator and the Audio Cues are unaffected. |
| **Unblockable Attack Indicator → Style** | How an unblockable attack shows at the screen's centre: Off, **Fiend** (a horned skull), Gore (a bleeding skull), Cracked (a cracked shield), Shattered (a shattered shield), Ember (a red cloud) or Splatter (a blood splatter), each a picture from the mod's `images` folder in its own colours. The list follows the `unblockable_<name>.png` files there; add your own and it is offered the next time the menu opens. |
| **Unblockable Attack Indicator → Size** | A range on 0%–100% (**60%–100%**): the low end is the indicator's size as it appears, the high end the size it grows to. 0% is 5% of the screen height and 100% the full screen height, so by default it grows from about 62% of the screen to all of it. |
| **Unblockable Attack Indicator → Opacity** | A range on 0%–100% (**50%–80%**), its ends at least 10% apart: the indicator's opacity as it appears and once grown, changing as it grows. |
| **Audio Cues → Sounds → Attack incoming** | Played when the parry window opens (the yellow arrow), as the attack is first seen, whatever the Omens show: None or one of the mod's cue sounds, **Rumble** by default. The cue sounds are the `cue_<name>.wav` files in the mod's `sounds` folder; add your own WAV (up to 3 seconds) as `cue_<name>.wav` and it is offered the next time the menu opens. They need UE4SS Lua Sound Bridge. |
| **Audio Cues → Sounds → Perfect Opportunity** | Played when the Perfect Opportunity window opens (the red arrow): the same choices, **Ding** by default. |
| **Audio Cues → Sounds → Unblockable Attack** | Played when the unblockable indicator appears: None or one of the mod's unblockable sounds, **Growl** by default: the `unblockable_<name>.wav` files in the `sounds` folder, which you can add to the same way. |
| **Audio Cues → Options → Enable directional sound** | **On**: a side arrow's sound plays on the side the arrow shows on, and ahead and behind are set apart by pitch, behind also muffled. Off: every arrow sounds the same. |
| **Audio Cues → Options → Differentiate back/front by pitch** | How much lower an arrow from behind and higher one from ahead sounds, -50% to +50%; **-20%** and **+20%** by default. Shown while directional sound is on. |
| **Audio Cues → Options → Sound volume** | How loud these sounds play, 0% to 200%, relative to the game's **Effects** volume (times **Master**); **100%** follows them as set. Changes in the game's audio settings apply from the next fight. |
| **Edges Flash → Activate Edges → Attack incoming** | **On**: when an attack's parry window opens (the yellow arrow), the screen edge on the attack's side glows yellow until the attack resolves. |
| **Edges Flash → Activate Edges → Perfect Opportunity** | **On**: when the attack's Perfect Opportunity window opens (the red arrow), the edge on its side glows red until the attack resolves. With Attack incoming Off, the edge stays dark until then; with this Off, it stays yellow. |
| **Edges Flash → Activate Edges → Unblockable Attack** | **On**: every screen edge glows red while an unblockable attack shows, over any attack's own edge, which shows again once it goes. |
| **Edges Flash → Visuals → Style** | How the glow fades inward: Bands (six stepped bands) or a smooth gradient picture, Linear or **Soft**. The list follows the `edge_<name>_v.png` files in the `images` folder that have a matching `edge_<name>_h.png` (`_v` fades down its height, for the top edge; `_h` along its width, for the left edge), each time the menu opens. A picture that cannot load draws Bands. |
| **Edges Flash → Visuals → Thickness** | How far the glow reaches in from the screen edge, 2% to 20% of the shorter screen side; **8%** by default. |
| **Edges Flash → Visuals → Intensity** | How strong the glow is at the screen edge, 10% to 100% opacity; **50%** by default. |
| **Countdown → Position** | Below, **Middle** or Above: the bar's bottom sits 77.5%, 55% or 32.5% of the screen height down at the default Size. The countdown shows the time left to the attack's Perfect Opportunity window above a yellow bar that runs down. The time comes from the attack's own timing in the game, to within about 0.05 s; when the game does not give it, it is an estimate (0.42 s on the second difficulty), and real attacks vary from almost none to about 0.8 s. **NOW** shows only when the game opens the Perfect Opportunity window, never before: the time and bar turn red and the bar runs down until the attack's hit would land. Everything goes as soon as the attack resolves. |
| **Countdown → Size** | How big the countdown is, 5% to 100%; **10%** by default. The bar grows to three times its default size at 100%, the time to a line 70% of the screen height tall, centred over the bar. Another Size keeps the countdown centred where it is at 10% for its Position, moved in only as far as needed to stay on screen. |

## If the cue does not appear

- Confirm **Enabled** is set to **Yes** under **Omens Overlay**, **Audio Cues**, **Edges Flash** or **Countdown** on the
  **Combat Preymonition** settings page and choose **Apply**.
- Check during combat while the game's original indicator shows an attack direction.
- Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings, ModCore Templates and
  UE4SS Lua Event Bridge are enabled, then restart the game.
- If another mod changes the original attack indicator, try disabling that mod
  to check for a conflict.

## Updating or removing

Close the game before updating and keep your existing saved settings. Do not
replace them with example defaults. To stop the extra cues, set **Enabled** to
**No** under **Omens Overlay**, **Audio Cues**, **Edges Flash** and **Countdown** on the **Combat Preymonition** settings page and choose **Apply**. To uninstall, close the game,
disable or remove the `9_ModCore_Preymonition` folder,
and restart. Keep dependencies used by other mods.

See the [changelog](CHANGELOG.md) for changes.
