-- Preymonition owns the attack cues; MCT owns HUD discovery, the cue layers and
-- the attack events. The omens, the sound cues, the screen edges, the countdown
-- and the background are separate templates, so each can be on without the
-- others. The settings page lists them in the order they are registered here;
-- their priorities set the order they attach and stack in (the background's
-- layer under the others).
local MC=require('mc')

MC.registerTemplate('omens')
MC.registerTemplate('sounds')
MC.registerTemplate('edges')
MC.registerTemplate('countdown')
MC.registerTemplate('background')
