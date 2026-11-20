// Selected project-authored components; no game data or assets.
import Foundation

/// A scene-thread lane index over caller-selected reference entities.
///
/// Membership is explicit: rebuild with the exact array being queried, then
/// update positions/teams as they change. update never inserts an unknown ID,
/// and health/death/hero/defense rules belong to the caller's predicate. In
/// particular, a fighter dying during a captured `living` pass must remain a
/// member when the original query did not recheck health; a newly spawned
/// fighter joins that pass only at its next rebuild.
///
/// IDs must be unique, positions finite, and predicates pure. Visitors take an
/// ordered snapshot before calling their body, so nested queries or mutations
/// in the body cannot invalidate traversal. No damage or authority is owned here.
final class CombatTargetIndex<Entity: AnyObject, Identifier: Hashable, Team: Hashable> {
    private final class Entry {
        let id: Identifier
        var entity: Entity
        var team: Team
        var x: Double
        var order: Int
        var epoch: UInt64
        var bin: Int
        var slot = 0
        init(id: Identifier, entity: Entity, team: Team, x: Double, order: Int, epoch: UInt64, bin: Int) {
            self.id = id; self.entity = entity; self.team = team; self.x = x
            self.order = order; self.epoch = epoch; self.bin = bin
        }
    }
    private final class Bucket { var entries: [Entry] = [] }
    private final class TeamBins {
        var buckets: [Int: Bucket] = [:]
        var occupied: [Int] = []
    }
    private struct Candidate { let entity: Entity; let order: Int }
    private let identifier: (Entity) -> Identifier
    private let teamOf: (Entity) -> Team
    private let position: (Entity) -> Double
    let binWidth: Double
    private var entries: [Identifier: Entry] = [:]
    private var teams: [Team: TeamBins] = [:]
    private var removedIDs: [Identifier] = []
    private var visitorBuffers: [[Candidate]] = []
    private var epoch: UInt64 = 0
    private var nextOrder = 0
    var count: Int { entries.count }

    init(binWidth: Double = 128, id: @escaping (Entity) -> Identifier,
         team: @escaping (Entity) -> Team, x: @escaping (Entity) -> Double) {
        precondition(binWidth.isFinite && binWidth > 0)
        self.binWidth = binWidth; identifier = id; teamOf = team; position = x
    }
    private func bin(for x: Double) -> Int {
        // Bound conversion even for unusual finite coordinates. Normal game
        // lanes are only a few thousand points wide.
        Int(max(Double(Int.min / 4), min(Double(Int.max / 4), floor(x / binWidth))))
    }
    private func lowerBound(_ value: Int, in values: [Int]) -> Int {
        var low = 0, high = values.count
        while low < high {
            let middle = low + (high - low) / 2
            if values[middle] < value { low = middle + 1 } else { high = middle }
        }
        return low
    }
    private func append(_ entry: Entry) {
        let state: TeamBins
        if let existing = teams[entry.team] { state = existing }
        else { state = TeamBins(); teams[entry.team] = state }
        let bucket: Bucket
        if let existing = state.buckets[entry.bin] { bucket = existing }
        else { bucket = Bucket(); state.buckets[entry.bin] = bucket }
        if bucket.entries.isEmpty {
            state.occupied.insert(entry.bin, at: lowerBound(entry.bin, in: state.occupied))
        }
        entry.slot = bucket.entries.count; bucket.entries.append(entry)
    }
    private func detach(_ entry: Entry) {
        guard let state = teams[entry.team], let bucket = state.buckets[entry.bin] else { return }
        let last = bucket.entries.count - 1
        if entry.slot != last {
            let moved = bucket.entries[last]
            bucket.entries[entry.slot] = moved; moved.slot = entry.slot
        }
        bucket.entries.removeLast()
        if bucket.entries.isEmpty {
            let offset = lowerBound(entry.bin, in: state.occupied)
            state.occupied.remove(at: offset)
        }
    }

    /// Reuse records/buckets for survivors; only new entities allocate records.
    /// Ordinals reset to the supplied array's order, including after reordering.
    func rebuild(_ values: [Entity]) {
        epoch &+= 1
        for state in teams.values {
            for bucket in state.buckets.values { bucket.entries.removeAll(keepingCapacity: true) }
            state.occupied.removeAll(keepingCapacity: true)
        }
        for (order, entity) in values.enumerated() {
            let id = identifier(entity), team = teamOf(entity), x = position(entity)
            guard x.isFinite else { continue }
            let entry: Entry
            if let existing = entries[id] {
                precondition(existing.epoch != epoch, "Combat entity IDs must be unique")
                entry = existing; entry.entity = entity; entry.team = team; entry.x = x
                entry.order = order; entry.epoch = epoch; entry.bin = bin(for: x)
            } else {
                entry = Entry(id: id, entity: entity, team: team, x: x, order: order, epoch: epoch, bin: bin(for: x))
                entries[id] = entry
            }
            append(entry)
        }
        removedIDs.removeAll(keepingCapacity: true)
        for (id, entry) in entries where entry.epoch != epoch { removedIDs.append(id) }
        for id in removedIDs { entries.removeValue(forKey: id) }
        nextOrder = values.count
    }
    /// Newly inserted members follow all existing members in original order.
    func insert(_ entity: Entity) {
        let id = identifier(entity)
        if entries[id] != nil { update(entity); return }
        let x = position(entity)
        guard x.isFinite else { return }
        let entry = Entry(id: id, entity: entity, team: teamOf(entity), x: x,
                          order: nextOrder, epoch: epoch, bin: bin(for: x))
        nextOrder += 1; entries[id] = entry; append(entry)
    }
    @discardableResult func update(_ entity: Entity) -> Bool {
        guard let entry = entries[identifier(entity)] else { return false }
        let x = position(entity), team = teamOf(entity)
        guard x.isFinite else { return false }
        let newBin = bin(for: x)
        if entry.team != team || entry.bin != newBin {
            detach(entry); entry.team = team; entry.bin = newBin; append(entry)
        }
        entry.x = x; entry.entity = entity
        return true
    }
    @discardableResult func remove(id: Identifier) -> Bool {
        guard let entry = entries.removeValue(forKey: id) else { return false }
        detach(entry); return true
    }
    private func bounds(team: Team, minimumX: Double, maximumX: Double) -> (TeamBins, Range<Int>)? {
        guard !minimumX.isNaN, !maximumX.isNaN, minimumX <= maximumX, let state = teams[team] else { return nil }
        let low = minimumX.isFinite ? lowerBound(bin(for: minimumX), in: state.occupied) : 0
        let high = maximumX.isFinite ? lowerBound(bin(for: maximumX) + 1, in: state.occupied) : state.occupied.count
        guard low < high else { return nil }
        return (state, low..<high)
    }

    /// Equal horizontal distances select the first entity in original order,
    /// matching array.min { abs(a.x-origin) < abs(b.x-origin) } exactly.
    func nearest(to origin: Double, team: Team, minimumX: Double = -.infinity,
                 maximumX: Double = .infinity, where predicate: (Entity) -> Bool = { _ in true }) -> Entity? {
        guard origin.isFinite, let (state, range) = bounds(team: team, minimumX: minimumX, maximumX: maximumX) else { return nil }
        let split = max(range.lowerBound, min(range.upperBound, lowerBound(bin(for: origin), in: state.occupied)))
        var left = split - 1, right = split
        var best: Entry?, bestDistance = Double.infinity
        func binDistance(_ index: Int) -> Double {
            guard range.contains(index) else { return .infinity }
            let number = state.occupied[index]
            let low = max(minimumX, Double(number) * binWidth)
            let high = min(maximumX, Double(number + 1) * binWidth)
            return origin < low ? low - origin : origin > high ? origin - high : 0
        }
        while left >= range.lowerBound || right < range.upperBound {
            let leftDistance = binDistance(left), rightDistance = binDistance(right)
            let distance = min(leftDistance, rightDistance)
            // Equality must remain searchable to preserve original-order ties.
            if best != nil && distance > bestDistance { break }
            let index: Int
            if left >= range.lowerBound && (right >= range.upperBound || leftDistance <= rightDistance) { index = left; left -= 1 }
            else { index = right; right += 1 }
            guard let bucket = state.buckets[state.occupied[index]] else { continue }
            for entry in bucket.entries where entry.x >= minimumX && entry.x <= maximumX && predicate(entry.entity) {
                let candidateDistance = abs(entry.x - origin)
                if best == nil || candidateDistance < bestDistance ||
                    (candidateDistance == bestDistance && entry.order < best!.order) {
                    best = entry; bestDistance = candidateDistance
                }
            }
        }
        return best?.entity
    }
    func first(inXRange range: ClosedRange<Double>, team: Team,
               where predicate: (Entity) -> Bool = { _ in true }) -> Entity? {
        guard let (state, bins) = bounds(team: team, minimumX: range.lowerBound, maximumX: range.upperBound) else { return nil }
        var best: Entry?
        for index in bins {
            guard let bucket = state.buckets[state.occupied[index]] else { continue }
            for entry in bucket.entries where range.contains(entry.x) && predicate(entry.entity) {
                if best == nil || entry.order < best!.order { best = entry }
            }
        }
        return best?.entity
    }
    func hasAny(inXRange range: ClosedRange<Double>, team: Team,
                where predicate: (Entity) -> Bool = { _ in true }) -> Bool {
        guard let (state, bins) = bounds(team: team, minimumX: range.lowerBound, maximumX: range.upperBound) else { return false }
        for index in bins {
            guard let bucket = state.buckets[state.occupied[index]] else { continue }
            for entry in bucket.entries where range.contains(entry.x) && predicate(entry.entity) { return true }
        }
        return false
    }
    /// Custom strict ordering supports the multiplayer healer's health-fraction
    /// priority and network-ID tiebreak; equivalent minima retain array order.
    func minimum(inXRange range: ClosedRange<Double>, team: Team,
                 where predicate: (Entity) -> Bool = { _ in true },
                 by less: (Entity, Entity) -> Bool) -> Entity? {
        guard let (state, bins) = bounds(team: team, minimumX: range.lowerBound, maximumX: range.upperBound) else { return nil }
        var best: Entry?
        for index in bins {
            guard let bucket = state.buckets[state.occupied[index]] else { continue }
            for entry in bucket.entries where range.contains(entry.x) && predicate(entry.entity) {
                if let current = best {
                    if less(entry.entity, current.entity) ||
                        (!less(current.entity, entry.entity) && entry.order < current.order) { best = entry }
                } else { best = entry }
            }
        }
        return best?.entity
    }
    func furthestX(team: Team, increasing: Bool, where predicate: (Entity) -> Bool = { _ in true }) -> Entity? {
        guard let state = teams[team] else { return nil }
        let count = state.occupied.count
        for offset in 0..<count {
            let index = increasing ? count - 1 - offset : offset
            guard let bucket = state.buckets[state.occupied[index]] else { continue }
            var best: Entry?
            for entry in bucket.entries where predicate(entry.entity) {
                if let current = best {
                    let better = increasing ? entry.x > current.x : entry.x < current.x
                    if better || (entry.x == current.x && entry.order < current.order) { best = entry }
                } else { best = entry }
            }
            if let best { return best.entity }
        }
        return nil
    }
    /// Range effects keep the original array order. Scratch storage is reused
    /// per nesting depth rather than allocating per fighter/query each frame.
    @discardableResult func forEach(inXRange range: ClosedRange<Double>, team: Team,
                                   where predicate: (Entity) -> Bool = { _ in true },
                                   _ body: (Entity) -> Void) -> Int {
        guard let (state, bins) = bounds(team: team, minimumX: range.lowerBound, maximumX: range.upperBound) else { return 0 }
        var candidates = visitorBuffers.popLast() ?? []
        candidates.removeAll(keepingCapacity: true)
        for index in bins {
            guard let bucket = state.buckets[state.occupied[index]] else { continue }
            for entry in bucket.entries where range.contains(entry.x) && predicate(entry.entity) {
                candidates.append(Candidate(entity: entry.entity, order: entry.order))
            }
        }
        candidates.sort { $0.order < $1.order }
        let count = candidates.count
        for candidate in candidates { body(candidate.entity) }
        candidates.removeAll(keepingCapacity: true); visitorBuffers.append(candidates)
        return count
    }
}
