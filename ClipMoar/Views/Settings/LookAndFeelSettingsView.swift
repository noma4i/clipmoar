import SwiftUI

struct LookAndFeelSettingsView: View {
    let settings: SettingsStore
    var onEditLook: (() -> Void)?
    @State private var largeTypeFontSize: Int
    @State private var largeTypeEnabled: Bool

    init(settings: SettingsStore, onEditLook: (() -> Void)? = nil) {
        self.settings = settings
        self.onEditLook = onEditLook
        _largeTypeFontSize = State(initialValue: settings.largeTypeFontSize)
        _largeTypeEnabled = State(initialValue: settings.largeTypeEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Panel").font(.system(size: 13, weight: .semibold))

            Button {
                onEditLook?()
            } label: {
                Label("Edit Look", systemImage: "paintbrush")
            }
            .controlSize(.large)

            Spacer().frame(height: 6)

            Text("Large Type").font(.system(size: 13, weight: .semibold))

            Toggle("Enable Large Type (Tab)", isOn: $largeTypeEnabled)
                .onChange(of: largeTypeEnabled) { _, val in settings.largeTypeEnabled = val }

            HStack {
                Text("Font size:")
                    .frame(width: 80, alignment: .trailing)
                Slider(value: Binding(
                    get: { Double(largeTypeFontSize) },
                    set: { largeTypeFontSize = Int($0); settings.largeTypeFontSize = Int($0) }
                ), in: 24 ... 120, step: 4)
                    .frame(width: 200)
                Text("\(largeTypeFontSize)px")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 40)
            }
            .disabled(!largeTypeEnabled)

            largeTypePreview
                .frame(height: 120)
                .opacity(largeTypeEnabled ? 1 : 0.4)

            Spacer()
        }
        .padding(24)
    }

    private var largeTypePreview: some View {
        ZStack {
            Color.black.opacity(0.6)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: NSColor(white: 0.08, alpha: 0.9)))
                .padding(12)
            Text("ClipMoar")
                .font(.system(size: CGFloat(largeTypeFontSize) * 0.4, weight: .medium))
                .foregroundColor(.white)
        }
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
    }
}
