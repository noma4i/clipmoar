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
    let settings: SettingsStore

    init(recorder: HotkeyRecorder, transformRecorder: HotkeyRecorder? = nil, settings: SettingsStore = UserDefaultsSettingsStore()) {
        _model = StateObject(wrappedValue: HotkeySettingsModel(recorder: recorder))
        let tr = transformRecorder ?? recorder
        _transformModel = StateObject(wrappedValue: HotkeySettingsModel(recorder: tr))
        self.settings = settings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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

                transformTimingSettings

                Divider()
                    .padding(.vertical, 4)

                Text("Panel shortcuts")
                    .font(.system(size: 14, weight: .semibold))

                shortcutsTable
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @State private var holdDelay = ""
    @State private var pasteDelay = ""
    @State private var restoreDelay = ""

    private var transformTimingSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 4)

            Text("Transform timing")
                .font(.system(size: 12, weight: .semibold))

            timingRow(
                label: "Hold delay",
                hint: "How long to hold before showing preset overlay",
                value: $holdDelay,
                save: { settings.transformHoldDelay = max(100, $0) }
            )

            timingRow(
                label: "Paste delay",
                hint: "Delay before sending Cmd+V after activating target app",
                value: $pasteDelay,
                save: { settings.transformPasteDelay = max(50, $0) }
            )

            timingRow(
                label: "Restore delay",
                hint: "Delay before restoring original clipboard content",
                value: $restoreDelay,
                save: { settings.transformRestoreDelay = max(100, $0) }
            )
        }
        .onAppear {
            holdDelay = "\(settings.transformHoldDelay)"
            pasteDelay = "\(settings.transformPasteDelay)"
            restoreDelay = "\(settings.transformRestoreDelay)"
        }
    }

    private func timingRow(
        label: String,
        hint: String,
        value: Binding<String>,
        step: Int = 50,
        save: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11))
                    .frame(width: 100, alignment: .trailing)
                TextField("", text: value)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: value.wrappedValue) {
                        if let v = Int(value.wrappedValue) { save(v) }
                    }
                VStack(spacing: 0) {
                    Button {
                        if let v = Int(value.wrappedValue) {
                            let newVal = v + step
                            value.wrappedValue = "\(newVal)"
                            save(newVal)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .frame(width: 16, height: 11)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        if let v = Int(value.wrappedValue) {
                            let newVal = max(0, v - step)
                            value.wrappedValue = "\(newVal)"
                            save(newVal)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .frame(width: 16, height: 11)
                    }
                    .buttonStyle(.borderless)
                }
                Text("ms")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Text(hint)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.leading, 108)
        }
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
