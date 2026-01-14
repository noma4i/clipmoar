import SwiftUI

final class HotkeySettingsModel: ObservableObject {
    let recorder: HotkeyRecorder
    @Published var shortcutString: String
    @Published var statusText: String = ""
    @Published var statusColor: Color = .green
    @Published var isRecording = false

    init(recorder: HotkeyRecorder) {
        self.recorder = recorder
        shortcutString = recorder.currentShortcutString
        updateStatus()

        recorder.onResult = { [weak self] result in
            DispatchQueue.main.async { self?.handleResult(result) }
        }
    }

    func clearHotkey() {
        recorder.clearHotkey()
        shortcutString = "Not assigned"
        statusText = "No shortcut assigned"
        statusColor = .secondary
    }

    func startRecording() {
        isRecording = true
        shortcutString = "Press shortcut..."
        statusText = "Use Cmd, Opt, Ctrl or Shift + key. Escape to cancel."
        statusColor = .secondary
        recorder.startRecording()
    }

    private func handleResult(_ result: HotkeyRecorderResult) {
        isRecording = false
        switch result {
        case .recorded:
            updateStatus()
        case .cancelled:
            updateStatus()
        case let .rejected(shortcut):
            shortcutString = shortcut
            statusText = "This shortcut is reserved by macOS"
            statusColor = .red
        case .needsModifier:
            statusText = "At least one modifier key required"
            statusColor = .orange
        }
    }

    private func updateStatus() {
        shortcutString = recorder.currentShortcutString
        if recorder.isReserved(shortcutString) {
            statusText = "This shortcut is reserved by macOS"
            statusColor = .red
        } else {
            statusText = "Shortcut assigned"
            statusColor = .green
        }
    }
}

struct HotkeySettingsView: View {
    @StateObject private var model: HotkeySettingsModel

    init(recorder: HotkeyRecorder) {
        _model = StateObject(wrappedValue: HotkeySettingsModel(recorder: recorder))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hotkeys")
                .font(.system(size: 18, weight: .semibold))

            Text("Global shortcut to show clipboard:")
                .font(.system(size: 13))

            HStack(spacing: 12) {
                TextField("", text: .constant(model.shortcutString))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 200)
                    .disabled(true)

                Button("Record Hotkey") {
                    model.startRecording()
                }

                Button("Clear") {
                    model.clearHotkey()
                }
                .disabled(model.isRecording)
            }

            if !model.statusText.isEmpty {
                Text(model.statusText)
                    .font(.system(size: 11))
                    .foregroundColor(model.statusColor)
            }

            Spacer()
        }
        .padding(24)
    }
}
