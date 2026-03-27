import SwiftUI

struct AISettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            if let image = loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
            }

            Text("MOAR Poop coming")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func loadImage() -> NSImage? {
        if let path = Bundle.main.path(forResource: "ai", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        let devPath = ProcessInfo.processInfo.environment["PWD"].map { $0 + "/assets/ai.png" }
            ?? "assets/ai.png"
        return NSImage(contentsOfFile: devPath)
    }
}
