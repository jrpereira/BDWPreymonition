# Preymonition development

In the Gaming workspace, read the shared rules and relevant procedures before
working on this module. Keep template and runtime source in `Scripts/`, tests
in `tests/`, and public documentation in `docs/`.

Preymonition is an MCT template in `player.notifications`. MCT owns HUD
discovery, the created cue layer and settings. This module owns the cue widgets
inside that layer, its three native attack hooks and the animation. Keep the
native-arrow direction heuristic and the event-driven, frame-deferred animation;
do not add gameplay polling.

Run the Lua tests from the workspace root for relevant changes. Offline tests
and install state do not establish live gameplay acceptance. Preserve personal
configuration and enablement during installation. Coordinate cross-module
interfaces, including the `player.notifications` category objects, with the
Coordinator.
