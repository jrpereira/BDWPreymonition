[size=5][b]Combat Preymonition[/b][/size]

[i]You see them coming. They won't.[/i]

Keep incoming attack directions in sight with animated cues near the center of your screen. Spend less time hunting for the warning—and more time getting hit in the face like a pro that saw it coming.

[b]What it does[/b]

Preymonition adds an arrow cue near the center of the screen, below it, at its middle or above it. When an attack comes, an arrow flashes in from its direction and turns red when the attack becomes critical. It vanishes once the attack lands or is deflected, so an empty cue means nothing is incoming. Unblockable attacks show a skull. The cue fades when combat ends.

Shield size and position, arrow style, size and movement, a background shield, trailing effects, screen edge glows and sounds are all adjustable. The original warning stays in place. Blocking, dodging, and taking the credit remain your responsibility.

[b]Requirements[/b]

Install these before Preymonition:
[list]
[*][b]UE4SS compatible with your game version.[/b] See the loader links in the [url=https://www.nexusmods.com/thebloodofdawnwalker/mods/271]Dawnwalker Mod Menu requirements[/url].
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/271]Dawnwalker Mod Menu[/url].
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/590]ModCore Settings[/url] 1.4.0 or newer.
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/641]ModCore Templates[/url] 1.5.0 or newer.
[*][url=https://www.nexusmods.com/thebloodofdawnwalker/mods/526]UE4SS Lua Event Bridge[/url] 1.2.0 or newer, which ModCore Templates also requires. Without it no cue appears.
[/list]
[b]Installation[/b]
[list=1]
[*]Close the game and install the requirements using their instructions. UE4SS itself does not install inside the Mods folder.
[*]Extract this download so [font=Courier New]9_ModCore_Preymonition[/font] sits directly inside the game's [font=Courier New]ue4ss/Mods[/font] folder. Avoid an extra nested [font=Courier New]9_ModCore_Preymonition/9_ModCore_Preymonition[/font] folder.
[*]Enable the mods in your UE4SS setup or mod manager, then restart the game.
[/list]
[b]Settings[/b]

Combat Preymonition has two parts, each with its own [b]Enabled[/b]: the [b]Center[/b] cue and the screen [b]Edges[/b]. Open [b]Mod Settings → Combat Preymonition[/b], set [b]Enabled[/b] under [b]Center[/b], [b]Edges[/b] or both to [b]Yes[/b], and choose [b]Apply[/b]. Adjust each part's settings on the same page and choose [b]Apply[/b] after changing them. Percentages scale the standard look; 100% leaves it unchanged, except Scale, which adds to it: 0% leaves it unchanged.
[list]
[*][b]Shield Scale[/b]: −50%–200% ([b]0%[/b]), the shield's size.
[*][b]Position[/b]: Below, [b]Middle[/b] or Above.
[*][b]Shield Visible[/b]: Off, In Combat, [b]Defending[/b] or Critical.
[*][b]Parry & Block → Indicator Style[/b]: Off or [b]Arrows[/b].
[*][b]Parry & Block → Indicator Size[/b] and [b]Indicator Movement[/b]: 50%–200% ([b]100%[/b]).
[*][b]Parry & Block → Trailing effect[/b]: Off, [b]Glow[/b] or Fade.
[*][b]Parry & Block → Play sound[/b]: None, [b]Chime[/b] or Swish.
[*][b]Unblockable size[/b]: 50%–200% ([b]120%[/b]), the skull's size.
[*][b]Play sound[/b] for unblockable attacks: None, [b]Growl[/b] or Boom.
[*][b]Edges → Edge Style[/b]: [b]Framed[/b] (every edge) or Directional (the attack's side).
[/list]

[b]If the cue does not appear[/b]
[list]
[*]Confirm [b]Enabled[/b] is set to [b]Yes[/b] under [b]Center[/b] or [b]Edges[/b] on the [b]Combat Preymonition[/b] settings page and choose [b]Apply[/b].
[*]Check during combat while the game's original indicator shows an attack direction.
[*]Confirm UE4SS, Dawnwalker Mod Menu, ModCore Settings, ModCore Templates and UE4SS Lua Event Bridge are installed and enabled, then restart the game.
[*]If another mod changes the original attack indicator, try disabling it to check for a conflict.
[/list]
[b]Updating or removing[/b]

Close the game before updating and keep your saved settings. Do not replace them with example defaults.

To stop the extra cues, set [b]Enabled[/b] to [b]No[/b] under [b]Center[/b] and [b]Edges[/b] on the [b]Combat Preymonition[/b] settings page and choose [b]Apply[/b]. To uninstall, close the game, disable or remove [font=Courier New]9_ModCore_Preymonition[/font], and restart. Keep dependencies used by other mods.
