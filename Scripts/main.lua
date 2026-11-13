-- Preymonition owns the attack cues; MCT owns HUD discovery, the cue layers and
-- the attack events. The omens, the screen edges, the countdown and the
-- background are separate templates. The settings page lists them in the order
-- they are registered here; their priorities set the order they attach and
-- stack in (the background's layer under the others).
local MC=require('mc')

MC.registerTemplate('omens')
MC.registerTemplate('edges')
MC.registerTemplate('countdown')
MC.registerTemplate('background')
