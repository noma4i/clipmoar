import Foundation

public struct DisplayInfo: Codable, Equatable {
    public let id: UInt32
    public let name: String
    public let width: Int
    public let height: Int
    public let isMain: Bool

    public init(id: UInt32, name: String, width: Int, height: Int, isMain: Bool) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.isMain = isMain
    }
}

public struct WindowFrame: Codable, Equatable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let app: String
    public let title: String
    public let children: [WindowFrame]

    public init(x: Int, y: Int, width: Int, height: Int, app: String, title: String, children: [WindowFrame] = []) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.app = app
        self.title = title
        self.children = children
    }
}

public enum Message: Equatable {
    case hello(deviceId: String)
    case pairRequest(deviceId: String, deviceName: String)
    case pairGranted(key: Data)
    case listDisplays
    case displays([DisplayInfo])
    case capture(displayId: UInt32?)
    case screenshot(png: Data, windows: [WindowFrame])
    case paste(png: Data, session: String)
    case ok
    case error(String)

    private enum Small: Codable {
        case hello(deviceId: String)
        case pairRequest(deviceId: String, deviceName: String)
        case pairGranted(key: Data)
        case listDisplays
        case displays([DisplayInfo])
        case capture(displayId: UInt32?)
        case ok
        case error(String)
    }

    public func encode() throws -> Data {
        let frame: Frame
        switch self {
        case let .screenshot(png, windows):
            let json = try JSONEncoder().encode(windows)
            guard json.count <= 1024 * 1024 else { throw FrameError.tooLarge }
            let length = UInt32(json.count)
            var payload = Data([UInt8(length >> 24), UInt8((length >> 16) & 255), UInt8((length >> 8) & 255), UInt8(length & 255)])
            payload.append(json)
            payload.append(png)
            frame = Frame(type: 1, payload: payload)
        case let .paste(png, session):
            let bytes = Data(session.utf8)
            guard !bytes.isEmpty, bytes.count <= 128 else { throw FrameError.invalidSession }
            var payload = Data([UInt8(bytes.count >> 8), UInt8(bytes.count & 255)])
            payload.append(bytes)
            payload.append(png)
            frame = Frame(type: 2, payload: payload)
        default:
            let value: Small
            switch self {
            case let .hello(deviceId): value = .hello(deviceId: deviceId)
            case let .pairRequest(deviceId, deviceName): value = .pairRequest(deviceId: deviceId, deviceName: deviceName)
            case let .pairGranted(key): value = .pairGranted(key: key)
            case .listDisplays: value = .listDisplays
            case let .displays(displays): value = .displays(displays)
            case let .capture(displayId): value = .capture(displayId: displayId)
            case .ok: value = .ok
            case let .error(message): value = .error(message)
            case .screenshot, .paste: preconditionFailure()
            }
            frame = try Frame(type: 0, payload: JSONEncoder().encode(value))
        }
        return try frame.encode()
    }

    public init(frame: Frame) throws {
        switch frame.type {
        case 1:
            let bytes = [UInt8](frame.payload)
            guard bytes.count >= 4 else { throw FrameError.truncated }
            let length = bytes.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
            guard length <= 1024 * 1024 else { throw FrameError.tooLarge }
            guard bytes.count > 4 + length else { throw FrameError.truncated }
            let windows = try JSONDecoder().decode([WindowFrame].self, from: Data(bytes[4 ..< 4 + length]))
            self = .screenshot(png: Data(bytes[(4 + length)...]), windows: windows)
        case 2:
            let bytes = [UInt8](frame.payload)
            guard bytes.count >= 2 else { throw FrameError.truncated }
            let length = Int(bytes[0]) << 8 | Int(bytes[1])
            guard length > 0, length <= 128 else { throw FrameError.invalidSession }
            guard bytes.count > 2 + length else { throw FrameError.truncated }
            guard let session = String(bytes: bytes[2 ..< 2 + length], encoding: .utf8) else { throw FrameError.invalidSession }
            self = .paste(png: Data(bytes[(2 + length)...]), session: session)
        case 0:
            switch try JSONDecoder().decode(Small.self, from: frame.payload) {
            case let .hello(deviceId): self = .hello(deviceId: deviceId)
            case let .pairRequest(deviceId, deviceName): self = .pairRequest(deviceId: deviceId, deviceName: deviceName)
            case let .pairGranted(key): self = .pairGranted(key: key)
            case .listDisplays: self = .listDisplays
            case let .displays(displays): self = .displays(displays)
            case let .capture(displayId): self = .capture(displayId: displayId)
            case .ok: self = .ok
            case let .error(message): self = .error(message)
            }
        default: throw FrameError.invalidType
        }
    }
}
