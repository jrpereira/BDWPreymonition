[size=5][b]Combat Preymonition[/b][/size]

[i]You see them coming. They won't.[/i]

Keep incoming attack directions in sight with animated cues near the center of your screen. Spend less time hunting for the warning—and more time getting hit in the face like a pro that saw it coming.

[b]What it does[/b]

Preymonition adds an arrow cue near the center of the screen, below it, at its middle or above it. When an attack comes, an arrow flashes in from its direction and turns red when the attack becomes critical. It vanishes once the attack lands or is deflected, so an empty cue means nothing is incoming. Unblockable attacks show a picture at the screen's centre, a horned skull by default. The cue fades when combat ends. Sound cues can play as the attack comes, with or without the arrows, and a countdown can show the time left to the attack's Perfect Opportunity window.

Position, arrow style, size and movement, screen edge glows, the countdown and sounds are all adjustable. The original warning stays in place. Blocking, dodging, and taking the credit remain your responsibility.

[b]Requirements[/b]

Install these before Preymonition:
[list]
[*][b]UE4SS compatible with your game version.[/b] See the loader links in the [url=https://www.nexusmods.com/thebloodofdawnwalker/mods/271]Dawnwalker Mod Menu requirements[/url].
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/271]Dawnwalker Mod Menu[/url].
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/590]ModCore Settings[/url] 1.9.0 or newer.
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/641]ModCore Templates[/url] 1.9.1 or later.
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/526]UE4SS Lua Event Bridge[/url] 1.3.0 or newer, which ModCore Templates also requires. Without it no cue appears.
[*][url=https://github.com/jrpereira/UE4SSLuaEXtensions/releases]UE4SS Lua Sound Bridge[/url] 1.1.0 or newer, for the Audio Cues. Without it they are silent.
[/list]
[b]Installation[/b]
[list=1]
[*]Close the game and install the requirements using their instructions. UE4SS itself does not install inside the Mods folder.
[*]Extract this download so [font=Courier New]9_ModCore_Preymonition[/font] sits directly inside the game's [font=Courier New]ue4ss/Mods[/font] folder. Avoid an extra nested [font=Courier New]9_ModCore_Preymonition/9_ModCore_Preymonition[/font] folder.
[*]Enable the mods in your UE4SS setup or mod manager, then restart the game.
[/list]
[b]Settings[/b]

Combat Preymonition has four parts, each with its own [b]Enabled[/b]: the [b]Omens Overlay[/b] (symbols near the middle of the screen), the [b]Audio Cues[/b] (sounds for each attack, whatever else is on), the [b]Edges Flash[/b] on the screen edges and the [b]Countdown (WIP)[/b]. Open [b]Mod Settings → Combat Preymonition[/b], set [b]Enabled[/b] under [b]Omens Overlay[/b], [b]Audio Cues[/b], [b]Edges Flash[/b], [b]Countdown (WIP)[/b] or any of them to [b]Yes[/b], and choose [b]Apply[/b]. The Audio Cues can be on alone, for sounds without the arrows.

An attack's [b]parry window[/b] opens when it is first shown (the yellow arrow), and its [b]Perfect Opportunity window[/b] later (the red arrow). Adjust each part's settings on the same page and choose [b]Apply[/b] after changing them.
[list]
[*][b]Parry & Block Indicator → Style[/b]: Off, then the pictures in the mod's images folder: [b]Chevron[/b], Fancy and Solid ship. Solid and Chevron are arrows with a thin black outline; Fancy is a glowing arrow. Arrows turn red when the attack is critical.
[*][b]Parry & Block Indicator → Position[/b]: Below, [b]Middle[/b] or Above. Only the arrows move; the unblockable indicator stays at the screen's centre.
[*][b]Parry & Block Indicator → Size[/b]: a range on 0%–100% ([b]30%–80%[/b]), at least 10% apart. An arrow appears at the low end's size and grows to the high end's as it travels, from 5% of the screen height at 0% to 50% at 100%.
[*][b]Parry & Block Indicator → Movement from Center[/b]: a range on 0%–100% ([b]40%–60%[/b]) of the space the arrow has: at 0% its back edge is on the cue's centre, at 100% its tip reaches the screen edge (up and down travel alike, as far as the nearer of the top and bottom edges). Its tip appears at the low end and stops at the high end; equal ends keep it still.
[*][b]Parry & Block Indicator → Attack Incoming[/b]: how the Yellow arrow shows before the Perfect Opportunity window: [b]Normal[/b], Faint (35% opacity) or Off.
[*][b]Parry & Block Indicator → Perfect Opportunity[/b]: how the Perfect Opportunity arrow takes over. [b]End[/b]: yellow runs its course first, red comes in at the end. Start: yellow doesn't move. Halfway: yellow moves 50%. Off: only yellow shows, never red; with Attack Incoming Off too, no arrow shows for attacks. The unblockable indicator and the Audio Cues are unaffected.
[*][b]Unblockable Attack Indicator → Style[/b]: Off, [b]Fiend[/b] (a horned skull), Gore (a bleeding skull), Cracked or Shattered (a broken shield), Ember (a red cloud) or Splatter (a blood splatter), at the screen's centre. Add your own [i]unblockable_<name>.png[/i] to the [i]images[/i] folder to offer it.
[*][b]Unblockable Attack Indicator → Size[/b]: a range on 0%–100% ([b]60%–100%[/b]). The indicator appears at the low end's size and grows to the high end's, from 5% of the screen height at 0% to the full screen height at 100%.
[*][b]Audio Cues → Sounds → Attack incoming[/b] (parry window, yellow arrow, as the attack is first seen) and [b]Perfect Opportunity[/b] (Perfect Opportunity window, red arrow): None or one of the mod's cue sounds; [b]Rumble[/b] and [b]Ding[/b] by default. Drop your own [i]cue_<name>.wav[/i] into the mod's [i]sounds[/i] folder and it is offered the next time the menu opens.
[*][b]Audio Cues → Options → Enable directional sound[/b]: [b]On[/b] plays a side arrow's sound on its side and sets ahead and behind apart by pitch, behind muffled.
[*][b]Audio Cues → Options → Differentiate back/front by pitch[/b]: -50% to +50%, [b]-20%[/b] behind and [b]+20%[/b] ahead by default.
[*][b]Audio Cues → Options → Sound volume[/b]: 0% to 200%, [b]100%[/b] by default, relative to the game's Effects volume (times Master).
[*][b]Audio Cues → Sounds → Unblockable Attack[/b]: None or one of the mod's unblockable sounds, [b]Growl[/b] by default. Drop your own [i]unblockable_<name>.wav[/i] into the [i]sounds[/i] folder to add one.
[*][b]Edges Flash → Activate Edges → Attack incoming[/b]: [b]On[/b] lights the edge on the attack's side yellow from its parry window (yellow arrow) until the attack resolves.
[*][b]Edges Flash → Activate Edges → Perfect Opportunity[/b]: [b]On[/b] lights it red from the Perfect Opportunity window (red arrow) until the attack resolves.
[*][b]Edges Flash → Activate Edges → Unblockable Attack[/b]: [b]On[/b] lights every edge red while an unblockable attack shows.
[*][b]Edges Flash → Visuals → Style[/b]: Bands, or a smooth gradient, Linear or [b]Soft[/b]. Drop a pair [i]edge_<name>_v.png[/i] (top edge, fading down) and [i]edge_<name>_h.png[/i] (left edge, fading right) into the mod's [i]images[/i] folder to add one.
[*][b]Edges Flash → Visuals → Thickness[/b]: 2% to 20% of the shorter screen side, [b]8%[/b] by default.
[*][b]Edges Flash → Visuals → Intensity[/b]: the glow's opacity at the screen edge, 10% to 100%, [b]50%[/b] by default.
[*][b]Countdown (WIP) → Position[/b]: Below, [b]Middle[/b] or Above. A work in progress: the time left to the Perfect Opportunity window counts down above a yellow bar, from the attack's own timing in the game. [b]NOW[/b] shows in red only when the game opens the Perfect Opportunity window, never before.
[/list]

[b]If the cue does not appear[/b]
[list]
[*]Confirm [b]Enabled[/b] is set to [b]Yes[/b] under [b]Omens Overlay[/b], [b]Audio Cues[/b], [b]Edges Flash[/b] or [b]Countdown (WIP)[/b] on the [b]Combat Preymonition[/b] settings page and choose [b]Apply[/b].
[*]Check during combat while the game's original indicator shows an attack direction.
[*]Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings, ModCore Templates and UE4SS Lua Event Bridge are installed and enabled, then restart the game.
[*]If another mod changes the original attack indicator, try disabling it to check for a conflict.
[/list]
[b]Updating or removing[/b]

Close the game before updating and keep your saved settings. Do not replace them with example defaults.

To stop the extra cues, set [b]Enabled[/b] to [b]No[/b] under [b]Omens Overlay[/b], [b]Audio Cues[/b], [b]Edges Flash[/b] and [b]Countdown (WIP)[/b] on the [b]Combat Preymonition[/b] settings page and choose [b]Apply[/b]. To uninstall, close the game, disable or remove [font=Courier New]9_ModCore_Preymonition[/font], and restart. Keep dependencies used by other mods.
