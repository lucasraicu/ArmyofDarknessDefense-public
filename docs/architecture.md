# Selected architecture

The complete application uses Swift and SpriteKit. The public examples focus on small, independently testable components rather than recovered game behavior.

`PresentationFrameBudget` shares one allowance across repeated callbacks for the same frame. Repeating `beginFrame` with the same identifier does not replenish it. This can distribute cosmetic construction across frames while authoritative simulation stays immediate.

`WarpDestinationKey` records the eight existing Float coordinate bit patterns of a fixed-source quad. Identical output can share immutable grid geometry even when its animation timestamps differ. One-ULP changes remain distinct. It does not round timestamps, reduce pose rates or change coordinates. Texture/model identity is intentionally absent because it does not change that grid object.

`OrderedPacketDecoder` owns its binary PropertyList decoder on one serial queue. Session mutation and UI work belong in main-thread completion callbacks. Pending count and bytes stay reserved through delivery. Cancellation invalidates queued callbacks by generation. This is an adapted generic example with synthetic types; it omits the private game's protocol and session rules.
