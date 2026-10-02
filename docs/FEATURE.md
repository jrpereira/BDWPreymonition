# Directional cue behavior

Preymonition is a managed MCT template in `player.notifications`. The category
supplies the HUD (`hud`) and a full-screen overlay created on its root (`cue`).
`attach` builds a size box, the shield border and four arrow images inside that
layer, bottom-centered. MCT releases the layer on detach; the template clears
its own content and forgets the cue.

`template.loaded` registers three native hooks for the session:

- `CombatTargetIndicatorBase:UpdateIconTypeToMatchObservedStubState` shows a cue.
- `CombatTargetIndicatorBase:NotifyIndicatorCleared` returns it to idle.
- `PlayerCombatComponent:OnCombatEnded` fades it out and resets.

Hook callbacks copy only the source object path, and only while a cue is attached.
Events are coalesced in a bounded queue and drained once, deferred to the game
thread, before reading widget state. Each update has its own identity, so a new
attack may retrigger the same direction. A clear only affects the cue's current
source. After combat ends, updates are ignored until combat state is positive.

Direction selection follows the rendered native arrows rather than the combat icon
enum: the visible arrow with the strongest colour above 0.5 wins. Modified game
artwork may require revisiting this heuristic.

Animation uses real elapsed time and absolute phase deadlines. One deferred frame
is pending per cue and none remain once it settles.

Offline tests cover registration, menu generation against a proposed category,
the animation timeline, the event queue and the session against fake UE objects.
They do not establish live hook delivery, HUD discovery, placement or cadence.
