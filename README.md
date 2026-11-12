# Army of Darkness Defense — engineering showcase

Selected Swift implementation examples from a personal Swift/SpriteKit recreation project. This repository demonstrates performance work, ordered multiplayer packet handling and the tests used to check correctness. It is a curated showcase, not the complete game or an installable distribution.

## Code examples

- [`code/performance/PerformancePrimitives.swift`](code/performance/PerformancePrimitives.swift): a presentation budget shared across callbacks, cancellation, and bit-exact warp destination identity. The destination key avoids time quantization while sharing identical render geometry.
- [`code/multiplayer/OrderedPacketDecoder.swift`](code/multiplayer/OrderedPacketDecoder.swift): an adapted standalone serial decoder with packet/byte limits, FIFO main-thread delivery and generation cancellation.
- [`tests/ShowcaseTests.swift`](tests/ShowcaseTests.swift): frame-budget, Float precision, queue-bound, ordered-delivery and stale-callback checks with synthetic data.

Run `./scripts/test.sh` on macOS with Xcode command-line tools. These examples build independently of the original game and its assets. See [architecture](docs/architecture.md), [measured results and limits](docs/performance.md), and [provenance](docs/provenance.md).

## Redistribution boundary

This repository contains selected implementation examples and technical documentation from a recreation project. It does not distribute the original game, extracted Lua or bytecode, recovered game data, or original game assets. Redistribution permission for those materials has not been established. Their availability elsewhere online does not grant permission to rehost them. Original game material remains the property of its respective rights holders; any license added here applies only to explicitly identified project-authored material. No blanket open-source license is granted by this repository.

The [archived original game listing](https://archive.org/details/aodhd-1.1.1-ipa) is linked for provenance only. No affiliation with or endorsement by the original developer or rights holders is claimed. Screenshots and recordings containing third-party content are excluded pending a separate rights review.

## Synchronization

The private project is the source of truth. A reviewed allowlist exports only these examples, tests and documents. `SYNC_MANIFEST.json` identifies the private source commit and exported file hashes. Exporting never commits or pushes, and public changes never automatically flow back to private. Read [the workflow](docs/sync.md).
