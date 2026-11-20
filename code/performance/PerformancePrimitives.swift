// Selected project-authored components; no game data or assets.
import Foundation

/// One budget shared by update and all action completions in the same frame.
struct PresentationFrameBudget {
    let limit: Int
    private var frame: Double?
    private(set) var used = 0
    init(limit: Int) { self.limit = max(1, limit) }
    mutating func beginFrame(_ identifier: Double) {
        guard identifier != frame else { return }
        frame = identifier; used = 0
    }
    mutating func claim() -> Bool {
        guard used < limit else { return false }
        used += 1; return true
    }
}

/// Cancellation never waits for decoding or audio work. Owners publish results
/// only after checking this token again on their serialized execution context.
final class WorkCancellation {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}

/// Exact destination identity: reuse only the Float coordinates SpriteKit receives.
/// No animation-time rounding, quantization or pose-rate reduction.
struct WarpDestinationKey: Hashable {
    let x0, y0, x1, y1, x2, y2, x3, y3: UInt32
    init(_ p0: SIMD2<Float>, _ p1: SIMD2<Float>, _ p2: SIMD2<Float>, _ p3: SIMD2<Float>) {
        x0 = p0.x.bitPattern; y0 = p0.y.bitPattern
        x1 = p1.x.bitPattern; y1 = p1.y.bitPattern
        x2 = p2.x.bitPattern; y2 = p2.y.bitPattern
        x3 = p3.x.bitPattern; y3 = p3.y.bitPattern
    }
}
