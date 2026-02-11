import SwiftUI

struct LookAndFeelSettingsView: View {
    let settings: SettingsStore
    var onEditLook: (() -> Void)?
    @State private var largeTypeFontSize: Int

    init(settings: SettingsStore, onEditLook: (() -> Void)? = nil) {
        self.settings = settings
        self.onEditLook = onEditLook
        _largeTypeFontSize = State(initialValue: settings.largeTypeFontSize)
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

            Spacer().frame(height: 10)

            Text("Large Type").font(.system(size: 13, weight: .semibold))

            HStack {
                Text("Font size:")
                    .frame(width: 80, alignment: .trailing)
                Slider(value: Binding(
                    get: { Double(largeTypeFontSize) },
                    set: { largeTypeFontSize = Int($0); settings.largeTypeFontSize = Int($0) }
                ), in: 24 ... 120, step: 4)
                    .frame(width: 200)
                Text("\(largeTypeFontSize)pt")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 40)
            }

            Spacer()
        }
        .padding(24)
    }
}
