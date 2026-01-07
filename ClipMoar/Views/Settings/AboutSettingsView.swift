import SwiftUI

struct AboutSettingsView: View {
    @State private var showLicense = false

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            if let image = loadHeaderImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280)
            }

            Text("Version 0.1.0")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("Clipboard manager for macOS")
                .font(.system(size: 14))

            Text("MIT License - 2026 Alexander Tsirel")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Button("Show License") {
                showLicense = true
            }
            .buttonStyle(.link)
            .font(.system(size: 12))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showLicense) {
            licenseSheet
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
           let text = try? String(contentsOfFile: path) {
            return text
        }
        let devPath = ProcessInfo.processInfo.environment["PWD"].map { $0 + "/LICENSE" }
            ?? "LICENSE"
        return (try? String(contentsOfFile: devPath, encoding: .utf8)) ?? "MIT License"
    }
}
