import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("ClipMoar")
                .font(.system(size: 28, weight: .bold))

            Text("Version 0.1.0")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("Clipboard manager for macOS")
                .font(.system(size: 14))

            Text("MIT License - 2026 noma4i")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
