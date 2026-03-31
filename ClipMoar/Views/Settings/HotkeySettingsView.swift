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
    @StateObject private var transformModel: HotkeySettingsModel

    init(recorder: HotkeyRecorder, transformRecorder: HotkeyRecorder? = nil) {
        _model = StateObject(wrappedValue: HotkeySettingsModel(recorder: recorder))
        let tr = transformRecorder ?? recorder
        _transformModel = StateObject(wrappedValue: HotkeySettingsModel(recorder: tr))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hotkeys")
                .font(.system(size: 18, weight: .semibold))

            Text("Global shortcut to show clipboard:")
                .font(.system(size: 13))

            hotkeyRow(model: model)

            Divider()
                .padding(.vertical, 4)

            Text("Global shortcut to paste transformed:")
                .font(.system(size: 13))

            Text("Applies transform rules and pastes the result. Clipboard keeps the original text.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            hotkeyRow(model: transformModel)

            Divider()
                .padding(.vertical, 4)

            Text("Panel shortcuts")
                .font(.system(size: 14, weight: .semibold))

            shortcutsTable

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func hotkeyRow(model: HotkeySettingsModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
    }

    private var shortcutsTable: some View {
        let shortcuts: [(String, String)] = [
            ("Return", "Paste selected item"),
            ("Escape", "Close panel"),
            ("Up / Down", "Navigate list"),
            ("Right", "Open image in Preview.app"),
            ("Tab", "Large Type preview"),
            ("Cmd + 1-9", "Paste by number"),
            ("Cmd + Delete", "Delete item"),
            ("Cmd + ,", "Open preferences"),
        ]

        return VStack(spacing: 0) {
            ForEach(Array(shortcuts.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.0)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 130, alignment: .leading)
                    Text(item.1)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(index % 2 == 0 ? Color.primary.opacity(0.03) : Color.clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08)))
    }
}
