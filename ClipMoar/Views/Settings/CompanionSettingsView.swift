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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Companion").font(.title2.bold())
                Toggle("Enable DrawMoar companion", isOn: $enabled)
                    .onChange(of: enabled) {
                        settings.companionEnabled = enabled
                        onChange?()
                    }
                HStack {
                    Text("Companion server")
                    Spacer()
                    if server?.isRunning != true {
                        status("Off", color: .gray)
                    } else if let error = server?.error {
                        status(error, color: .red)
                    } else {
                        status("Running", color: .green)
                    }
                }
                if let port = server?.listeningPort {
                    Text("Port: \(port)")
                    Text("Hosts: \(server?.hosts.joined(separator: ", ") ?? "")")
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Text("Screen Recording")
                    Spacer()
                    status(screenGranted ? "Granted" : "Not granted", color: screenGranted ? .green : .red)
                    if !screenGranted {
                        Button("Request access") { PermissionDragWindow.show(.screenRecording) }
                    }
                }
                Divider()
                Text("Pair device").font(.system(size: 13, weight: .semibold))
                VStack(spacing: 8) {
                    if let invite = server?.invite {
                        if let image = qrImage(for: invite.url) {
                            Image(nsImage: image)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 220, height: 220)
                                .padding(12)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black, lineWidth: 1.5))
                        }
                        Text("Scan with your iPhone or iPad camera")
                        Text("\(server?.secondsRemaining ?? 0) s remaining")
                            .monospacedDigit()
                            .frame(width: 120)
                            .foregroundStyle(.secondary)
                        Button("Cancel") { server?.closePairing() }
                    } else {
                        Button("Pair device") { server?.startPairing() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!enabled || server == nil)
                        Text("Shows a QR code to scan with DrawMoar")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                Divider()
                Text("Paired devices").font(.system(size: 13, weight: .semibold))
                if let devices = server?.devices, !devices.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(devices) { device in
                            HStack {
                                Image(systemName: device.name.localizedCaseInsensitiveContains("ipad") ? "ipad" : "iphone")
                                    .frame(width: 20)
                                Text(device.name).lineLimit(1).truncationMode(.tail)
                                Spacer()
                                Button("Revoke") { server?.revoke(device.id) }
                            }
                        }
                    }
                } else {
                    Text("No paired devices").foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            screenGranted = CGPreflightScreenCaptureAccess()
        }
    }

    private func status(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).fixedSize(horizontal: false, vertical: true)
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
