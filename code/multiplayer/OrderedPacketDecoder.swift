// Adapted project-authored example. Synthetic generic protocol; no original game data.
import Foundation

final class OrderedPacketDecoder<Value: Decodable> {
    private let queue: DispatchQueue
    private let decoder = PropertyListDecoder()
    private let lock = NSLock()
    private let maximumPackets: Int
    private let maximumBytes: Int
    private var generation: UInt64 = 0
    private var packets = 0
    private var bytes = 0

    init(queue: DispatchQueue = DispatchQueue(label: "showcase.packet-decode"),
         maximumPackets: Int = 256, maximumBytes: Int = 4 * 1024 * 1024) {
        self.queue = queue
        self.maximumPackets = max(1, maximumPackets)
        self.maximumBytes = max(1, maximumBytes)
    }
    var pending: Int { lock.lock(); defer { lock.unlock() }; return packets }
    func invalidate() {
        lock.lock(); defer { lock.unlock() }
        generation &+= 1; packets = 0; bytes = 0
    }
    private func current(_ token: UInt64) -> Bool {
        lock.lock(); defer { lock.unlock() }; return token == generation
    }
    private func release(_ token: UInt64, count: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard token == generation else { return false }
        packets -= 1; bytes -= count; return true
    }
    @discardableResult
    func submit(_ data: Data, completion: @escaping (Result<Value, Error>) -> Void) -> Bool {
        lock.lock()
        guard !data.isEmpty, packets < maximumPackets, data.count <= maximumBytes - bytes else {
            lock.unlock(); return false
        }
        let token = generation; packets += 1; bytes += data.count; lock.unlock()
        queue.async { [weak self] in
            guard let self, self.current(token) else { return }
            let result = Result { try self.decoder.decode(Value.self, from: data) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.release(token, count: data.count) else { return }
                completion(result)
            }
        }
        return true
    }
}
