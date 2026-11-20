# Measurements and practical limits

Each result below names where it was measured. Simulator results don't establish device behavior, and one device session doesn't establish every workload.

## Device frame rate

On an iPad Pro 12.9-inch (3rd generation), a seeded bot played Endless at its hardest preset with a maximum loadout, reaching 63 entities on screen. After a 32-second warm-up, Instruments captured about 24 seconds. The median of the app's frame-rate windows was 119.92 FPS on a 120 Hz display. The median window-average GPU active time was 3.33 ms per frame, and the maximum was 4.87 ms. Two frames took 50 and 58 ms; their GPU active time stayed under 4.4 ms, so the delay came before presentation rather than from GPU drawing. Those pauses remain open.

![iPad frame timing: the longest frame per window sits on the 8.33 ms line except for spikes of 17, 50, 58 and 25 ms, while GPU time stays between 3 and 5 ms](../media/ipad-frame-timing.svg)

## Multiplayer delivery and the guest buffer

A November 12 capture on an iPhone 16 Pro Max and the iPad ran eight quiet and heavy multiplayer conditions. Guest frame-rate windows averaged 118.6–119.5 FPS in quiet runs and 110.4–114.3 FPS in heavy runs. Delivery was uneven: quiet runs had 57–69 snapshot gaps over 100 ms, and heavy runs had 239–245. The longest gaps were 344–383 ms in all but one run, which had a 1,147 ms gap. On 12–15% of sampled guest frames, the newest snapshot was over 100 ms old. That capture established irregular delivery, not its cause.

![Late snapshots per device run: about 9.5% of snapshot intervals in quiet runs and 12% in heavy runs exceeded 100 ms, mostly in the 100–200 ms band](../media/snapshot-gaps.svg)

| Run (load · host · graphics) | Snapshot intervals | 100–200 ms | Over 200 ms | Longest |
| --- | ---: | ---: | ---: | ---: |
| Quiet · iPad · Enhanced | 694 | 65 | 1 | 373 ms |
| Quiet · iPad · Standard | 687 | 68 | 1 | 343 ms |
| Quiet · iPhone · Enhanced | 598 | 56 | 1 | 348 ms |
| Quiet · iPhone · Standard | 697 | 65 | 1 | 355 ms |
| Heavy · iPad · Enhanced | 1,953 | 214 | 28 | 348 ms |
| Heavy · iPad · Standard | 1,945 | 228 | 11 | 1,147 ms |
| Heavy · iPhone · Enhanced | 2,065 | 227 | 18 | 344 ms |
| Heavy · iPhone · Standard | 1,962 | 211 | 28 | 383 ms |

On November 19, a hands-on two-device test compared guest buffers. At 100 ms, the host's hero walked with a steady stiffness on the guest's screen. At 150 ms, most of it disappeared. At 200 ms it felt worse. Disconnecting both devices from infrastructure Wi-Fi didn't noticeably change it. The buffer default became 150 ms. This was a visual judgment by the developer, not an instrumented comparison. The remaining stiffness, and whether the host or the link causes the late snapshots, need a timing trace.

## Combat target index

The private project checks the index against brute-force scans with 21,811 checks, including 15,360 seeded comparisons and mutations during the same frame. The public tests repeat that approach at a smaller scale. There's no isolated speed measurement of the index on its own. The only timer that covered it also covered the rest of combat processing.

## Exact-output geometry cache experiment (simulator)

A fixed-input diagnostic compared the original cache identity with exact destination Float bits using 96 rigs, 240 measured 120 Hz sample steps and three repetitions per workload. Median CPU update time decreased 20.7% for synchronized phases, 25.6% for mixed clips and 36.2% for distinct phases. A deliberately near-equal-time workload decreased 69.2%; that synthetic result must not be generalized to all fights. Runs were sequential, so order and machine effects remain possible.

The near-equal case reduced grid constructions from 351,360 to 15,122; the unshared case stayed essentially unchanged at 351,360 versus 351,357. All 384 captured poses in the affected-unit render comparison were pixel-identical. The public key tests demonstrate exact identity; the game rendering evidence remains in the private validation records.

## Packet decoding (live session)

CPU stack sampling confirmed envelope/snapshot decoding left the main thread for a serial worker. In one matched-setting live session guest decoding averaged 1.239 ms/message on main before and 1.084 ms/message on the worker after. Worker queue wait averaged 0.552 ms with p99 8.285 ms. Moving work adds scheduling latency rather than eliminating its cost. That session's frame-rate figures varied with the workload and don't establish a whole-game improvement.
