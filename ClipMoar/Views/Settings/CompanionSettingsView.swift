import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI

struct CompanionSettingsView: View {
    let settings: SettingsStore
    let server: CompanionServer?
    let onChange: (() -> Void)?
    @State private var enabled: Bool
    @State private var screenGranted = CGPreflightScreenCaptureAccess()

    init(settings: SettingsStore, server: CompanionServer?, onChange: (() -> Void)?) {
        self.settings = settings
        self.server = server
        self.onChange = onChange
        _enabled = State(initialValue: settings.companionEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Companion").font(.title2.bold())
            Toggle("Enable DrawMoar companion", isOn: $enabled)
                .onChange(of: enabled) {
                    settings.companionEnabled = enabled
                    onChange?()
                }
            HStack {
                Text("Screen Recording")
                Spacer()
                if screenGranted {
                    Text("Granted").foregroundStyle(.secondary)
                } else {
                    Button("Request access") { screenGranted = CGRequestScreenCaptureAccess() }
                        .frame(width: 120)
                }
            }
            Divider()
            HStack(alignment: .top, spacing: 20) {
                Button("Pair device") { server?.startPairing() }
                    .disabled(!enabled || server == nil || server?.invite != nil)
                    .frame(width: 120)
                if let invite = server?.invite {
                    VStack(spacing: 8) {
                        if let image = qrImage(for: invite.url) {
                            Image(nsImage: image)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 220, height: 220)
                                .padding(12)
                                .background(.white)
                        }
                        Text("Scan with your iPhone or iPad camera")
                        Text("\(server?.secondsRemaining ?? 0) s remaining").foregroundStyle(.secondary)
                        Button("Cancel") { server?.closePairing() }
                    }
                }
            }
            Text("Paired devices").font(.headline)
            if let devices = server?.devices, !devices.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(devices) { device in
                            HStack {
                                Text(device.name).lineLimit(1).truncationMode(.tail)
                                Spacer()
                                Button("Revoke") { server?.revoke(device.id) }
                                    .frame(width: 80)
                            }
                        }
                    }
                }
            } else {
                Text("No paired devices").foregroundStyle(.secondary)
            }
            if let error = server?.error {
                Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            screenGranted = CGPreflightScreenCaptureAccess()
        }
    }

    private func qrImage(for url: URL) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage, let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
