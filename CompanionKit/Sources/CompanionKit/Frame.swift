import Foundation

public let maxFrameSize = 64 * 1024 * 1024
public let bonjourServiceType = "_clipmoar._tcp"

public struct Frame: Equatable {
    public let type: UInt8
    public let payload: Data

    public init(type: UInt8, payload: Data) {
        self.type = type
        self.payload = payload
    }

    public func encode() throws -> Data {
        guard payload.count <= maxFrameSize else { throw FrameError.tooLarge }
        let length = UInt32(payload.count)
        var result = Data([UInt8(length >> 24), UInt8((length >> 16) & 255), UInt8((length >> 8) & 255), UInt8(length & 255), type])
        result.append(payload)
        return result
    }
}

public enum FrameError: Error {
    case tooLarge
    case invalidType
    case truncated
    case invalidSession
}

public struct FrameDecoder {
    private var header = [UInt8]()
    private var payload = Data()
    private var length: Int?

    public init() {}

    public mutating func append(_ data: Data) throws -> [Frame] {
        var frames = [Frame]()
        var index = data.startIndex
        while index < data.endIndex {
            if length == nil {
                let count = min(5 - header.count, data.distance(from: index, to: data.endIndex))
                let end = data.index(index, offsetBy: count)
                header.append(contentsOf: data[index ..< end])
                index = end
                if header.count >= 4 {
                    let size = header.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
                    guard size <= maxFrameSize else { throw FrameError.tooLarge }
                    if header.count == 5 { length = size }
                }
            }
            if let length {
                let count = min(length - payload.count, data.distance(from: index, to: data.endIndex))
                let end = data.index(index, offsetBy: count)
                payload.append(contentsOf: data[index ..< end])
                index = end
                if payload.count == length {
                    frames.append(Frame(type: header[4], payload: payload))
                    header.removeAll(keepingCapacity: true)
                    payload = Data()
                    self.length = nil
                }
            }
        }
        return frames
    }
}
