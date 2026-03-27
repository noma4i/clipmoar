import Cocoa
import Foundation

@Observable
final class UpdateService: NSObject {
    private(set) var state: UpdateState = .idle
    private let settings: SettingsStore
    private let currentVersion: SemanticVersion
    private let bundlePath: String
    private let session: URLSession
    private var downloadDelegate: DownloadDelegate?

    private static let releaseURL = URL(string: "https://api.github.com/repos/noma4i/clipmoar/releases/latest")!
    private static let assetName = "ClipMoar.app.zip"
    private static let minCheckInterval: TimeInterval = 24 * 3600
    private static let maxCheckInterval: TimeInterval = 48 * 3600

    init(
        settings: SettingsStore,
        session: URLSession = .shared,
        currentVersion: String? = nil,
        bundlePath: String? = nil
    ) {
        self.settings = settings
        self.currentVersion = SemanticVersion(string: currentVersion
            ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0.0.0") ?? SemanticVersion(string: "0.0.0")!
        self.bundlePath = bundlePath ?? Bundle.main.bundlePath
        self.session = session
        super.init()
    }

    func checkForUpdates() {
        state = .checking
        var request = URLRequest(url: Self.releaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ClipMoar/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleCheckResponse(data: data, response: response, error: error)
            }
        }.resume()
    }

    func downloadAndInstall() {
        guard case let .available(_, _, downloadURL) = state else { return }
        state = .downloading(progress: 0)

        let delegate = DownloadDelegate { [weak self] progress in
            DispatchQueue.main.async {
                self?.state = .downloading(progress: progress)
            }
        } onComplete: { [weak self] location, error in
            DispatchQueue.main.async {
                if let error {
                    self?.state = .error(error.localizedDescription)
                    return
                }
                guard let location else {
                    self?.state = .error("Download failed")
                    return
                }
                self?.installUpdate(from: location)
            }
        }
        downloadDelegate = delegate

        let downloadSession = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
        downloadSession.downloadTask(with: downloadURL).resume()
    }

    func scheduleAutomaticCheck() {
        guard settings.autoCheckUpdates else { return }
        if let lastCheck = settings.lastUpdateCheck {
            let randomInterval = TimeInterval.random(in: Self.minCheckInterval ... Self.maxCheckInterval)
            let elapsed = Date().timeIntervalSince(lastCheck)
            if elapsed < randomInterval { return }
        }
        checkForUpdates()
    }

    private func handleCheckResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error {
            state = .error(error.localizedDescription)
            return
        }
        guard let data else {
            state = .error("No data received")
            return
        }
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            state = .error("GitHub API error: \(httpResponse.statusCode)")
            return
        }
        do {
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let remoteVersion = SemanticVersion(string: release.tagName) else {
                state = .error("Invalid version: \(release.tagName)")
                return
            }
            settings.lastUpdateCheck = Date()
            if remoteVersion > currentVersion {
                let asset = release.assets.first { $0.name == Self.assetName }
                    ?? release.assets.first { $0.name.hasSuffix(".zip") }
                guard let asset, let url = URL(string: asset.browserDownloadUrl) else {
                    state = .error("No download asset found")
                    return
                }
                state = .available(
                    version: remoteVersion.description,
                    notes: release.body ?? "",
                    downloadURL: url
                )
            } else {
                state = .upToDate
            }
        } catch {
            state = .error("Failed to parse response: \(error.localizedDescription)")
        }
    }

    private func installUpdate(from tempFile: URL) {
        state = .installing
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let stablePath = tempDir.appendingPathComponent("download.zip")
            try fm.copyItem(at: tempFile, to: stablePath)

            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-o", "-q", stablePath.path, "-d", tempDir.path]
            try unzip.run()
            unzip.waitUntilExit()
            guard unzip.terminationStatus == 0 else {
                state = .error("Failed to unzip update")
                return
            }

            let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
                state = .error("No .app found in archive")
                return
            }

            let xattr = Process()
            xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattr.arguments = ["-cr", newApp.path]
            try xattr.run()
            xattr.waitUntilExit()

            let appDir = URL(fileURLWithPath: bundlePath).deletingLastPathComponent()
            guard fm.isWritableFile(atPath: appDir.path) else {
                state = .error("Cannot write to \(appDir.path) - move app to a writable location")
                try? fm.removeItem(at: tempDir)
                return
            }

            let currentApp = URL(fileURLWithPath: bundlePath)
            var trashedURL: NSURL?
            try fm.trashItem(at: currentApp, resultingItemURL: &trashedURL)
            let destination = appDir.appendingPathComponent(currentApp.lastPathComponent)
            try fm.copyItem(at: newApp, to: destination)
            try? fm.removeItem(at: tempDir)

            let open = Process()
            open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            open.arguments = [destination.path]
            try open.run()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            state = .error("Install failed: \(error.localizedDescription)")
            try? fm.removeItem(at: tempDir)
        }
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void
    let onComplete: (URL?, Error?) -> Void

    init(onProgress: @escaping (Double) -> Void, onComplete: @escaping (URL?, Error?) -> Void) {
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didWriteData _: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }

    func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL)
    {
        onComplete(location, nil)
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            onComplete(nil, error)
        }
    }
}
