import Foundation

protocol ClipboardRemoteSender {
    func send(text: String, host: String, method: RemoteCopyMethod, keyPath: String)
    func sendImage(_ data: Data, host: String, method: RemoteCopyMethod, keyPath: String)
}

enum ImageMime {
    static func detect(_ data: Data) -> String? {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        return nil
    }
}

enum SSHOptions {
    static func keyFileExists(keyPath: String) -> Bool {
        keyPath.isEmpty || FileManager.default.fileExists(atPath: NSString(string: keyPath).expandingTildeInPath)
    }

    static func arguments(keyPath: String) -> [String] {
        guard !keyPath.isEmpty else { return [] }
        return ["-i", NSString(string: keyPath).expandingTildeInPath, "-o", "IdentitiesOnly=yes"]
    }
}

enum RemoteCopyMethod: String, CaseIterable {
    case auto
    case pbcopy
    case wlCopy
    case xclip

    var title: String {
        switch self {
        case .auto: "Auto"
        case .pbcopy: "pbcopy"
        case .wlCopy: "wl-copy"
        case .xclip: "xclip"
        }
    }

    var copyCommand: String {
        switch self {
        case .auto: RemoteClipboardCommand.copy
        case .pbcopy: "pbcopy"
        case .wlCopy: "sh -c '" + RemoteClipboardCommand.wlCopyScript() + "'"
        case .xclip: "sh -c '" + RemoteClipboardCommand.xclipScript() + "'"
        }
    }

    func imageCopyCommand(mime: String) -> String? {
        switch self {
        case .auto:
            "sh -c '"
                + "if command -v wl-copy >/dev/null 2>&1; then " + RemoteClipboardCommand.wlCopyScript("--type " + mime) + "; "
                + "elif command -v xclip >/dev/null 2>&1; then " + RemoteClipboardCommand.xclipScript("-t " + mime + " -i") + "; "
                + "else exit 127; fi'"
        case .pbcopy: nil
        case .wlCopy: "sh -c '" + RemoteClipboardCommand.wlCopyScript("--type " + mime) + "'"
        case .xclip: "sh -c '" + RemoteClipboardCommand.xclipScript("-t " + mime + " -i") + "'"
        }
    }

    var probeCommand: String {
        switch self {
        case .auto: RemoteClipboardCommand.probe
        case .pbcopy: "command -v pbcopy"
        case .wlCopy: "command -v wl-copy"
        case .xclip: "command -v xclip"
        }
    }
}

enum RemoteClipboardCommand {
    static func wlCopyScript(_ arguments: String = "") -> String {
        "export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}; "
            + "export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-$(cd $XDG_RUNTIME_DIR && ls -d wayland-? 2>/dev/null | head -1)}; "
            + "exec wl-copy \(arguments) >/dev/null 2>&1"
    }

    static func xclipScript(_ arguments: String = "") -> String {
        "export DISPLAY=${DISPLAY:-:0}; exec xclip -selection clipboard \(arguments) >/dev/null 2>&1"
    }

    static let copy = "sh -c '"
        + "if command -v pbcopy >/dev/null 2>&1; then exec pbcopy; "
        + "elif command -v wl-copy >/dev/null 2>&1; then " + wlCopyScript() + "; "
        + "elif command -v xclip >/dev/null 2>&1; then " + xclipScript() + "; "
        + "else exit 127; fi'"

    static let probe = "command -v pbcopy || command -v wl-copy || command -v xclip"
}

final class SSHClipboardSender: ClipboardRemoteSender {
    private let queue = DispatchQueue(label: "clipmoar.ssh-sync")
    private let logger: ClipboardLogger

    init(logger: ClipboardLogger = SystemClipboardLogger()) {
        self.logger = logger
    }

    func send(text: String, host: String, method: RemoteCopyMethod, keyPath: String) {
        run(command: method.copyCommand, input: Data(text.utf8), host: host, keyPath: keyPath)
    }

    func sendImage(_ data: Data, host: String, method: RemoteCopyMethod, keyPath: String) {
        guard let mime = ImageMime.detect(data), let command = method.imageCopyCommand(mime: mime) else {
            logger.log("[ClipMoar] ssh sync skipped: image not supported by method")
            return
        }
        run(command: command, input: data, host: host, keyPath: keyPath)
    }

    private func run(command: String, input data: Data, host: String, keyPath: String) {
        queue.async { [logger] in
            guard SSHOptions.keyFileExists(keyPath: keyPath) else {
                logger.log("[ClipMoar] ssh sync skipped: key file not found")
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=3"] + SSHOptions.arguments(keyPath: keyPath) + ["--", host, command]
            let input = Pipe()
            process.standardInput = input
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                input.fileHandleForWriting.write(data)
                try input.fileHandleForWriting.close()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    logger.log("[ClipMoar] ssh sync to %@ failed: exit %d", host, process.terminationStatus)
                }
            } catch {
                logger.log("[ClipMoar] ssh sync to %@ failed: %@", host, error.localizedDescription)
            }
        }
    }
}

enum SSHHostCheck {
    static func isReachable(host: String, method: RemoteCopyMethod, keyPath: String) -> Bool {
        guard SSHOptions.keyFileExists(keyPath: keyPath) else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=3"] + SSHOptions.arguments(keyPath: keyPath) + ["--", host, method.probeCommand]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
