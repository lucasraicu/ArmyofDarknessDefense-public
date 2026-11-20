# Selected architecture

The complete application uses Swift and SpriteKit. Multiplayer runs over a local TCP connection with an authoritative host: the host simulates the battle and sends state snapshots, and the guest draws them while predicting only its own hero. The public examples focus on small, independently testable components rather than recovered game behavior.

## Performance

`CombatTargetIndex` keeps each team's units in fixed-width horizontal bins, with a sorted list of occupied bins. Nearest-target search walks outward from the origin's bin and stops once the next bin is farther than the best match. Range queries visit only overlapping bins. Every query reproduces a linear scan exactly, including which of two equally distant units wins (the earlier one in the caller's array), so it could replace scans without changing combat outcomes. Callers own all game rules through predicates; the index holds no damage, health or authority logic. Rebuilds reuse existing records and buckets, and range visits snapshot their candidates into reused per-depth buffers, so a visitor can safely run nested queries or mutate units.

`PresentationFrameBudget` shares one allowance across repeated callbacks for the same frame. Repeating `beginFrame` with the same identifier does not replenish it. This can distribute cosmetic construction across frames while authoritative simulation stays immediate.

`WarpDestinationKey` records the eight existing Float coordinate bit patterns of a fixed-source quad. Identical output can share immutable grid geometry even when its animation timestamps differ. One-ULP changes remain distinct. It does not round timestamps, reduce pose rates or change coordinates. Texture/model identity is intentionally absent because it does not change that grid object.

## Multiplayer timing

`SnapshotCadence` publishes host state at 20 Hz regardless of render rate. After a hitch it publishes once and resumes the original phase, instead of sending a burst of duplicate snapshots.

`GuestPresentationClock` decides which moment of host time the guest draws. It targets a fixed delay behind the newest snapshot (150 ms by default) so there are usually two snapshots to interpolate between. Ordinary arrival jitter changes the clock's speed by 2% rather than resetting it, and presentation never moves backwards. During an outage the clock may run at most 150 ms past the newest snapshot, while units hold their last known positions. If it falls more than 100 ms behind, it jumps forward instead of slowly replaying stale state. `displayedAge` reports how old the state on screen is, for the timing measurements described in [performance](performance.md). The comments' N0 and N2 labels refer to the project's measurement and tuning stages.

`OrderedPacketDecoder` owns its binary PropertyList decoder on one serial queue. Session mutation and UI work belong in main-thread completion callbacks. Pending count and bytes stay reserved through delivery. Cancellation invalidates queued callbacks by generation. This is an adapted generic example with synthetic types; it omits the private game's protocol and session rules.
