# Directional cue behavior

Premonition listens to three native game functions:

- `CombatTargetIndicatorBase:UpdateIconTypeToMatchObservedStubState` detects a cue.
- `CombatTargetIndicatorBase:NotifyIndicatorCleared` performs the ordinary hide.
- `PlayerCombatComponent:OnCombatEnded` performs the combat-end fade and reset.

Hook callbacks copy only the source object path. Work is coalesced in a bounded
queue, delayed once, and moved to the game thread before reading widget state. Each
native update event has its own identity, so a new attack may retrigger the same
direction. A clear event only affects the currently associated source.

The adapter accepts a HUD only when its root hierarchy is visible and belongs to
the source world. The local player's HUD is preferred; an ambiguous selection is
rejected. Combat-end state is accepted only from the active HUD world. A replaced
or destroyed HUD invalidates queued animation work and is recreated on the next
valid detection.

Animation uses real elapsed time and absolute phase deadlines. Delayed callbacks
catch up instead of stretching the sequence. One deferred callback is pending at a
time and no callback remains after the model settles or is hidden. Disabling the
feature unregisters hooks, clears the event queue, invalidates scheduled callbacks,
and removes the owned widget.

Direction selection intentionally follows the rendered native arrows rather than
the combat icon enum. The visible arrow with the strongest color value above the
inactive threshold is selected. This matches the observed gold/red native states,
but modified game artwork may require revisiting the heuristic.

Offline tests cover animation interruption, same-direction retrigger, bounded event
delivery, duplicate clears, combat-end stale events, destroyed HUDs, and scheduling
failure. They do not establish live native event delivery, visual placement,
animation cadence, or frame impact.
