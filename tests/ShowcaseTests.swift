import Foundation

@main struct ShowcaseTests {
    struct Packet: Codable { let sequence: Int }
    static func main() throws {
        var checks = 0
        func check(_ condition: Bool, _ text: String) {
            precondition(condition, text); checks += 1
        }
        func wait(_ condition: () -> Bool) {
            let deadline = Date().addingTimeInterval(3)
            while !condition() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.001)) }
            check(condition(), "bounded asynchronous completion")
        }
        var budget = PresentationFrameBudget(limit: 2)
        budget.beginFrame(1); check(budget.claim(), "first allowance")
        budget.beginFrame(1); check(budget.claim() && !budget.claim(), "same frame cannot replenish allowance")
        budget.beginFrame(2); check(budget.claim(), "next frame replenishes")
        let cancellation = WorkCancellation(); check(!cancellation.isCancelled, "starts active")
        cancellation.cancel(); check(cancellation.isCancelled, "cancellation recorded")
        let corners: [SIMD2<Float>] = [SIMD2(0,0),SIMD2(1,0),SIMD2(0,1),SIMD2(1,1)]
        let key = WarpDestinationKey(corners[0],corners[1],corners[2],corners[3])
        for i in 0..<4 { for axis in 0..<2 {
            var changed = corners; changed[i][axis] = changed[i][axis].nextUp
            check(WarpDestinationKey(changed[0],changed[1],changed[2],changed[3]) != key, "one ULP must not alias")
        } }
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        let first = try encoder.encode(Packet(sequence: 1)), second = try encoder.encode(Packet(sequence: 2))
        let worker = DispatchQueue(label: "test.worker"); worker.suspend()
        let decoder = OrderedPacketDecoder<Packet>(queue: worker, maximumPackets: 2, maximumBytes: first.count+second.count)
        var delivered: [Int] = []
        let receive: (Result<Packet,Error>) -> Void = { result in
            check(Thread.isMainThread, "completion is on main")
            switch result { case .success(let packet): delivered.append(packet.sequence); case .failure: preconditionFailure("unexpected malformed packet") }
        }
        check(decoder.submit(first, completion: receive), "first admitted")
        check(decoder.submit(second, completion: receive), "second admitted")
        check(!decoder.submit(first, completion: receive), "count/bytes stay bounded")
        worker.resume(); wait { delivered.count == 2 }
        check(delivered == [1,2] && decoder.pending == 0, "FIFO and released budget")
        var stale = false
        decoder.submit(first) { _ in stale = true }; worker.sync {}; decoder.invalidate()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        check(!stale && decoder.pending == 0, "already decoded stale callback suppressed")
        var malformed = false
        decoder.submit(Data([1,2,3])) { result in if case .failure = result { malformed = true } }
        wait { malformed }

        // CombatTargetIndex against brute-force reference queries on seeded data.
        final class Unit { let id: Int; var team: Int; var x: Double; var health: Double
            init(_ id: Int, _ team: Int, _ x: Double, _ health: Double) { self.id = id; self.team = team; self.x = x; self.health = health } }
        var seed: UInt64 = 0x5EED
        func random() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }
        var units = (0..<160).map { Unit($0, $0 % 2, (random() * 3500).rounded() - 500, 1 + (random() * 9).rounded()) }
        let index = CombatTargetIndex<Unit, Int, Int>(binWidth: 128, id: { $0.id }, team: { $0.team }, x: { $0.x })
        index.rebuild(units)
        check(index.count == units.count, "index holds every rebuilt unit")
        var mismatches = 0, queries = 0
        func compare(_ indexed: Unit?, _ reference: Unit?) { queries += 1; if indexed?.id != reference?.id { mismatches += 1 } }
        for round in 0..<40 {
            for _ in 0..<12 {
                // Moves, team changes, removals and inserts between queries.
                let unit = units[Int(random() * Double(units.count))]
                unit.x = (random() * 3500).rounded() - 500
                if random() < 0.1 { unit.team ^= 1 }
                index.update(unit)
            }
            if round % 5 == 0 {
                let victim = Int(random() * Double(units.count))
                index.remove(id: units[victim].id); units.remove(at: victim)
            }
            if round % 7 == 0 { let added = Unit(1000 + round, round % 2, (random() * 3000).rounded(), 5); units.append(added); index.insert(added) }
            for _ in 0..<10 {
                let origin = (random() * 3500).rounded() - 500, team = Int(random() * 2)
                let low = origin - 300, high = origin + 300, members = units.filter { $0.team == team }
                let strong: (Unit) -> Bool = { $0.health > 3 }
                compare(index.nearest(to: origin, team: team), members.min { abs($0.x - origin) < abs($1.x - origin) })
                compare(index.nearest(to: origin, team: team, where: strong), members.filter(strong).min { abs($0.x - origin) < abs($1.x - origin) })
                compare(index.first(inXRange: low...high, team: team), members.first { (low...high).contains($0.x) })
                compare(index.minimum(inXRange: low...high, team: team, by: { $0.health < $1.health }),
                        members.filter { (low...high).contains($0.x) }.min { $0.health < $1.health })
                compare(index.furthestX(team: team, increasing: true),
                        members.reduce(nil as Unit?) { best, unit in best.map { unit.x > $0.x ? unit : $0 } ?? unit })
                queries += 1
                if index.hasAny(inXRange: low...high, team: team) != members.contains(where: { (low...high).contains($0.x) }) { mismatches += 1 }
                var visited: [Int] = []
                index.forEach(inXRange: low...high, team: team) { visited.append($0.id) }
                queries += 1
                if visited != members.filter({ (low...high).contains($0.x) }).map(\.id) { mismatches += 1 }
            }
        }
        check(mismatches == 0, "indexed nearest, range, minimum, furthest and visit order match brute force over \(queries) queries")
        let tieA = Unit(9001, 0, 100, 1), tieB = Unit(9002, 0, 140, 1)
        let ties = CombatTargetIndex<Unit, Int, Int>(id: { $0.id }, team: { $0.team }, x: { $0.x })
        ties.rebuild([tieA, tieB])
        check(ties.nearest(to: 120, team: 0)?.id == 9001, "equal distances keep the first unit in array order")

        // GuestPresentationClock: interpolation delay, jitter and starvation bounds.
        check(GuestPresentationClock().delay == 0.15 && GuestPresentationClock(delay: 5).delay == 0.15 &&
              GuestPresentationClock.delay(fromMilliseconds: "100") == 0.1 && GuestPresentationClock.delay(fromMilliseconds: "x") == 0.15,
              "the buffer defaults to 150 ms and rejects out-of-range values")
        var clock = GuestPresentationClock(), snapshot = 0.0, arrival = 0.0, presented: [Double] = []
        for frame in 0...600 {
            let now = Double(frame) / 120
            // 20 Hz snapshots whose arrival wobbles by up to ±12 ms.
            if frame % 6 == 0 { snapshot = now; arrival = now + (random() - 0.5) * 0.024 }
            presented.append(clock.advance(snapshotTime: snapshot, age: max(0, now - arrival), dt: 1.0 / 120,
                                           oldestTime: max(0, snapshot - 0.35)))
        }
        check(zip(presented, presented.dropFirst()).allSatisfy { $1 >= $0 }, "presentation time never rewinds under jitter")
        let lag = Double(600) / 120 - presented.last!
        check(abs(lag - 0.15) < 0.03, "steady delivery presents about one buffer delay behind")
        var stalled = clock, stallTime = presented.last!
        for frame in 1...120 { stallTime = stalled.advance(snapshotTime: snapshot, age: Double(frame) / 120, dt: 1.0 / 120, oldestTime: snapshot - 0.35) }
        check(stallTime <= snapshot + 0.15 + 1e-9, "a one-second outage cannot run presentation past the newest snapshot plus 150 ms")
        let resumed = stalled.advance(snapshotTime: snapshot + 1.05, age: 0, dt: 1.0 / 120, oldestTime: snapshot + 0.7)
        check(resumed > stallTime && snapshot + 1.05 - resumed < 0.2, "recovery rebases forward instead of slowly replaying stale state")

        // SnapshotCadence: 20 Hz phase, no burst after a hitch.
        var cadence = SnapshotCadence(), published = 0
        for frame in 0..<120 where cadence.shouldPublish(at: Double(frame) / 120) { published += 1 }
        check(published == 20, "one second at 120 Hz publishes 20 snapshots")
        check(cadence.shouldPublish(at: 1.3) && !cadence.shouldPublish(at: 1.3 + 1.0 / 120),
              "a 300 ms hitch publishes once instead of replaying missed snapshots")
        check(cadence.shouldPublish(at: 1.3 + 1.0 / 120, force: true), "forced publication bypasses the cadence")
        print("PASS \(checks) showcase correctness checks")
    }
}
