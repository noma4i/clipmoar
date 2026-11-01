import Foundation
import Network

public final class CompanionConnection {
    public let connection: NWConnection
    public let messages: AsyncThrowingStream<Message, Error>
    private let continuation: AsyncThrowingStream<Message, Error>.Continuation
    private let queue = DispatchQueue(label: "CompanionConnection")
    private var decoder = FrameDecoder()

    public init(_ connection: NWConnection) {
        self.connection = connection
        var captured: AsyncThrowingStream<Message, Error>.Continuation!
        messages = AsyncThrowingStream { captured = $0 }
        continuation = captured
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case let .failed(error): self?.continuation.finish(throwing: error)
            case .cancelled: self?.continuation.finish()
            default: break
            }
        }
        continuation.onTermination = { [weak connection] _ in connection?.cancel() }
        connection.start(queue: queue)
        receive()
    }

    public func send(_ message: Message) async throws {
        let data = try message.encode()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self else { return }
            do {
                if let data {
                    for frame in try self.decoder.append(data) {
                        try self.continuation.yield(Message(frame: frame))
                    }
                }
                if let error { throw error }
                if complete {
                    self.continuation.finish()
                } else {
                    self.receive()
                }
            } catch {
                self.continuation.finish(throwing: error)
                self.connection.cancel()
            }
        }
    }
}
