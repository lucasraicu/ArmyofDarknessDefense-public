#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=$(mktemp -d /tmp/aod-showcase-tests.XXXXXX)
trap 'rm -rf "$OUT"' EXIT
swiftc -swift-version 5 "$ROOT/code/performance/PerformancePrimitives.swift" "$ROOT/code/multiplayer/OrderedPacketDecoder.swift" "$ROOT/tests/ShowcaseTests.swift" -o "$OUT/tests"
"$OUT/tests"
