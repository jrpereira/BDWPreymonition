[size=5][b]Combat Preymonition[/b][/size]

[i]You see them coming. They won't.[/i]

Keep incoming attack directions in sight with animated cues near the center of your screen. Spend less time hunting for the warning—and more time getting hit in the face like a pro that saw it coming.

[b]What it does[/b]

Preymonition adds an arrow cue near the center of the screen, below it, at its middle or above it. When an attack comes, an arrow flashes in from its direction and turns red when the attack becomes critical. It vanishes once the attack lands or is deflected, so an empty cue means nothing is incoming. Unblockable attacks show a skull. The cue fades when combat ends. A countdown can show the time left to the attack's parry window.

Position, arrow style, size and movement, a background shield, screen edge glows, the countdown and sounds are all adjustable. The original warning stays in place. Blocking, dodging, and taking the credit remain your responsibility.

[b]Requirements[/b]

Install these before Preymonition:
[list]
[*][b]UE4SS compatible with your game version.[/b] See the loader links in the [url=https://www.nexusmods.com/thebloodofdawnwalker/mods/271]Dawnwalker Mod Menu requirements[/url].
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/271]Dawnwalker Mod Menu[/url].
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/590]ModCore Settings[/url] 1.7.0 or newer.
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/641]ModCore Templates[/url] 1.7.0 or newer.
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/526]UE4SS Lua Event Bridge[/url] 1.2.0 or newer, which ModCore Templates also requires. Without it no cue appears.
[/list]
[b]Installation[/b]
[list=1]
[*]Close the game and install the requirements using their instructions. UE4SS itself does not install inside the Mods folder.
[*]Extract this download so [font=Courier New]9_ModCore_Preymonition[/font] sits directly inside the game's [font=Courier New]ue4ss/Mods[/font] folder. Avoid an extra nested [font=Courier New]9_ModCore_Preymonition/9_ModCore_Preymonition[/font] folder.
[*]Enable the mods in your UE4SS setup or mod manager, then restart the game.
[/list]
[b]Settings[/b]

Combat Preymonition has four parts, each with its own [b]Enabled[/b]: the [b]Background[/b] (a shield that lights up with the attack), the [b]Omens[/b] (symbols around it), the screen [b]Edges[/b] and the [b]Countdown[/b]. Open [b]Mod Settings → Combat Preymonition[/b], set [b]Enabled[/b] under [b]Background[/b], [b]Omens[/b], [b]Edges[/b], [b]Countdown[/b] or any of them to [b]Yes[/b], and choose [b]Apply[/b]. Adjust each part's settings on the same page and choose [b]Apply[/b] after changing them.
[list]
[*][b]Background → Position[/b]: Below, [b]Middle[/b] or Above; match the Omens' Position to keep the shield behind them.
[*][b]Background → Visibility[/b]: In Combat (faint white), [b]Defending[/b] (see-through yellow while an attack is shown) or Critical (pops in when the parry window opens); each turns red while the parry window is open.
[*][b]Background → Size[/b]: 5%–100% ([b]50%[/b]) of the screen height.
[*][b]Position[/b]: Below, [b]Middle[/b] or Above.
[*][b]Parry & Block Indicator → Style[/b]: Off, Solid, [b]Chevron[/b], Perspective or Fancy. Solid, Chevron and Perspective are drawn arrows with a thin black outline; Perspective lays the Chevron flat on the ground around your character's waist, as the camera sees it. Fancy shows glowing painted arrows, red when the attack is critical.
[*][b]Parry & Block Indicator → Size[/b]: a range on 0%–100% ([b]30%–80%[/b]), at least 10% apart. An arrow appears at the low end's size and grows to the high end's as it travels, from 5% of the screen height at 0% to 50% at 100%.
[*][b]Parry & Block Indicator → Movement from Center[/b]: a range on 0%–100% ([b]40%–60%[/b]) of the space the arrow has: at 0% its back edge is on the cue's centre, at 100% its tip reaches the screen edge. Its tip appears at the low end and stops at the high end; equal ends keep it still.
[*][b]Parry & Block Indicator → Play sound[/b]: None, [b]Chime[/b] or Swish.
[*][b]Parry & Block Indicator → Prioritize Perfection over Buildup[/b]: [b]Off[/b] or On. On makes the arrow animate, red, once the parry window opens, and plays its sound only then. The Background is unaffected.
[*][b]Parry & Block Indicator → Buildup visibility[/b] and [b]Buildup animation[/b] (with Prioritize Perfection on): the yellow arrow before the parry window is [b]Hidden[/b], Faint or Normal, and [b]Static[/b], Partial (30% of its animation) or Normal.
[*][b]Unblockable Attack Indicator → Size[/b]: a range on 0%–100% ([b]60%–100%[/b]). The skull appears at the low end's size and grows to the high end's, from 5% of the screen height at 0% to the full screen height at 100%.
[*][b]Unblockable Attack Indicator → Play sound[/b]: None, [b]Growl[/b] or Boom.
[*][b]Edges → Edge Style[/b]: [b]Framed[/b] (every edge) or Directional (the attack's side).
[*][b]Countdown → Position[/b]: Below, [b]Middle[/b] or Above. The time left to the parry window counts down above a yellow bar, from the attack's own timing in the game. [b]NOW[/b] shows in red only when the game opens the parry window, never before.
[/list]

[b]If the cue does not appear[/b]
[list]
[*]Confirm [b]Enabled[/b] is set to [b]Yes[/b] under [b]Background[/b], [b]Omens[/b], [b]Edges[/b] or [b]Countdown[/b] on the [b]Combat Preymonition[/b] settings page and choose [b]Apply[/b].
[*]Check during combat while the game's original indicator shows an attack direction.
[*]Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings, ModCore Templates and UE4SS Lua Event Bridge are installed and enabled, then restart the game.
[*]If another mod changes the original attack indicator, try disabling it to check for a conflict.
[/list]
[b]Updating or removing[/b]

Close the game before updating and keep your saved settings. Do not replace them with example defaults.

To stop the extra cues, set [b]Enabled[/b] to [b]No[/b] under [b]Background[/b], [b]Omens[/b], [b]Edges[/b] and [b]Countdown[/b] on the [b]Combat Preymonition[/b] settings page and choose [b]Apply[/b]. To uninstall, close the game, disable or remove [font=Courier New]9_ModCore_Preymonition[/font], and restart. Keep dependencies used by other mods.
