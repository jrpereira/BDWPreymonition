-- Preymonition owns the attack cues; MCT owns HUD discovery, the cue layers and
-- the attack events. The omens, the audio cues, the screen edges and the
-- countdown are separate templates, so each can be on without the others. The
-- settings page lists them in the order they are registered here; their
-- priorities set the order they attach and stack in.
local MC=require('mc')

MC.registerTemplate('omens')
MC.registerTemplate('audio')
MC.registerTemplate('edges')
MC.registerTemplate('countdown')
