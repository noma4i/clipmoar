import SwiftUI

struct AboutSettingsView: View {
    var updateService: UpdateService?
    @State private var showLicense = false
    @State private var showPermissionsAlert = false

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            if let image = loadHeaderImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280)
            }

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("Highly opinionated clipboard manager for macOS")
                .font(.system(size: 14))

            Text("MIT License - 2026 Alexander Tsirel")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                Button("Show License") {
                    showLicense = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )

                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/noma4i/clipmoar")!)
                } label: {
                    HStack(spacing: 4) {
                        if let icon = loadAssetImage("github") {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 12, height: 12)
                        }
                        Text("GitHub")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
            }

            if let updateService {
                Divider()
                    .padding(.horizontal, 40)
                updateSection(updateService)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showLicense) {
            licenseSheet
        }
        .alert("Accessibility Permissions", isPresented: $showPermissionsAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("After updating, macOS resets Accessibility permissions.\nRe-add ClipMoar in System Settings > Privacy & Security > Accessibility.")
        }
    }

    @ViewBuilder
    private func updateSection(_ service: UpdateService) -> some View {
        switch service.state {
        case .idle:
            Button("Check for Updates") {
                service.checkForUpdates()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
            )

        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for updates...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                Text("You're up to date")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        case let .available(version, notes, _):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    Text("Version \(version) available")
                        .font(.system(size: 13, weight: .medium))
                }

                if !notes.isEmpty {
                    ScrollView {
                        Text(notes)
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxWidth: 400, maxHeight: 120)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }

                Button("Update Now") {
                    showPermissionsAlert = true
                    service.downloadAndInstall()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

        case let .downloading(progress):
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .frame(width: 200)
                Text("Downloading... \(Int(progress * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

        case .installing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Installing...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        case let .error(message):
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Button("Retry") {
                    service.checkForUpdates()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
            }
        }
    }

    private var licenseSheet: some View {
        VStack(spacing: 12) {
            Text("MIT License")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 16)

            ScrollView {
                Text(loadLicenseText())
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }

            Button("Close") {
                showLicense = false
            }
            .keyboardShortcut(.cancelAction)
            .padding(.bottom, 12)
        }
        .frame(width: 480, height: 340)
    }

    private func loadHeaderImage() -> NSImage? {
        if let path = Bundle.main.path(forResource: "header", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        let devPath = ProcessInfo.processInfo.environment["PWD"].map { $0 + "/assets/header.png" }
            ?? "assets/header.png"
        return NSImage(contentsOfFile: devPath)
    }

    private func loadLicenseText() -> String {
        if let path = Bundle.main.path(forResource: "LICENSE", ofType: nil),
           let text = try? String(contentsOfFile: path)
        {
            return text
        }
        let devPath = ProcessInfo.processInfo.environment["PWD"].map { $0 + "/LICENSE" }
            ?? "LICENSE"
        return (try? String(contentsOfFile: devPath, encoding: .utf8)) ?? "MIT License"
    }

    private func loadAssetImage(_ name: String) -> NSImage? {
        if let path = Bundle.main.path(forResource: name, ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        let devPath = ProcessInfo.processInfo.environment["PWD"].map { $0 + "/assets/\(name).png" }
            ?? "assets/\(name).png"
        return NSImage(contentsOfFile: devPath)
    }
}
