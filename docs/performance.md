# Measurements and practical limits

These results come from a shared-Mac iOS simulator investigation. They do not establish iPhone/iPad 120 FPS, thermal behavior, input latency or resolved multiplayer stutter.

## Exact-output geometry cache experiment

A fixed-input diagnostic compared the original cache identity with exact destination Float bits using 96 rigs, 240 measured 120 Hz sample steps and three repetitions per workload. Median CPU update time decreased 20.7% for synchronized phases, 25.6% for mixed clips and 36.2% for distinct phases. A deliberately near-equal-time workload decreased 69.2%; that synthetic result must not be generalized to all fights. Runs were sequential, so order and machine effects remain possible.

The near-equal case reduced grid constructions from 351,360 to 15,122; the unshared case stayed essentially unchanged at 351,360 versus 351,357. All 384 captured poses in the affected-unit render comparison were pixel-identical. The public key tests demonstrate exact identity; the game rendering evidence remains in the private validation records.

## Packet decoding

CPU stack sampling confirmed envelope/snapshot decoding left the main thread for a serial worker. In one matched-setting live session guest decoding averaged 1.239 ms/message on main before and 1.084 ms/message on the worker after. Worker queue wait averaged 0.552 ms with p99 8.285 ms. Moving work adds scheduling latency rather than eliminating its cost.

Observed guest FPS was 45.30 before and 46.75 after, but frame p99 was 110.11 ms versus 111.91 ms and populations evolved differently. This does not establish a reliable whole-game improvement. Remaining stutter and hardware acceptance stay open. No graphics reduction or lower troop pose frequency was used.
