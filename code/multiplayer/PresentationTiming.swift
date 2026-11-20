// Selected project-authored components; no game data or assets.
import Foundation

/// A delayed packet must not rewind an already displayed simulation instant.
/// Reset per battle; callers still bound extrapolation and retain interpolation.
struct GuestPresentationClock {
    /// How far behind the newest host state the guest presents. 150 ms by
    /// default since build 35: on the 2026-11-19 device test it removed most of
    /// the host hero's visible stiffness on the guest, where 100 ms often ran
    /// dry over peer-to-peer Wi-Fi. AOD_MP_BUFFER_MS still overrides it.
    static let defaultDelay = 0.15
    static let delayRange = 0.025...0.3
    /// Internal N2 setting: AOD_MP_BUFFER_MS, or the AODMultiplayerBufferMS
    /// user default. Missing or out-of-range values keep the default.
    static let configuredDelay: Double = delay(
        fromMilliseconds: ProcessInfo.processInfo.environment["AOD_MP_BUFFER_MS"] ??
            UserDefaults.standard.string(forKey: "AODMultiplayerBufferMS"))
    static func delay(fromMilliseconds text: String?) -> Double {
        guard let text, let milliseconds = Double(text), milliseconds.isFinite,
              delayRange.contains(milliseconds / 1000) else { return defaultDelay }
        return milliseconds / 1000
    }
    let delay: Double
    private(set) var time: Double?
    init(delay: Double = GuestPresentationClock.defaultDelay) {
        self.delay = Self.delayRange.contains(delay) ? delay : Self.defaultDelay
    }
    mutating func advance(snapshotTime: Double, age: Double, dt: Double, oldestTime: Double) -> Double {
        let candidate = snapshotTime + min(0.25, max(0, age)) - delay
        guard let previous = time else { time = candidate; return candidate }
        let step = max(0, min(0.25, dt))
        let error = candidate - (previous + step)
        // Ordinary delivery jitter adjusts speed rather than resetting time.
        // After starvation, rebase forward if more than two snapshot intervals
        // behind, so a slow slew cannot retain seconds of obsolete presentation.
        let rate = error > 0.01 ? 1.02 : error < -0.01 ? 0.98 : 1
        let advanced = error > 0.1 ? candidate : previous + step * rate
        let next = max(previous, oldestTime - delay, min(advanced, snapshotTime + 0.15))
        time = next
        return next
    }
    /// N0 battle age: how old the battle state on screen is. Past the newest
    /// snapshot the clock may run up to 150 ms ahead while units stay on that
    /// snapshot, so the shown state is never newer than the newest snapshot.
    /// `newestAge` is how long ago it arrived; one-way delay is not included.
    static func displayedAge(newestTime: Double, newestAge: Double, presented: Double) -> Double {
        max(0, newestTime + max(0, newestAge) - min(presented, newestTime))
    }
}

/// Keep the intended 20 Hz phase across render frames. Missed deadlines are
/// skipped, never replayed as a burst of duplicate snapshots after a hitch.
struct SnapshotCadence {
    private var next: Double?
    mutating func shouldPublish(at time: Double, force: Bool = false) -> Bool {
        guard let deadline = next else { next = time + 0.05; return true }
        guard force || time + 1e-9 >= deadline else { return false }
        next = force ? time + 0.05 : deadline + (floor(max(0, time - deadline + 1e-9) / 0.05) + 1) * 0.05
        return true
    }
}
