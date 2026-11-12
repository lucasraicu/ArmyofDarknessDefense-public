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
        print("PASS \(checks) showcase correctness checks")
    }
}
