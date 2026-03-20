import SwiftUI

struct AISettingsView: View {
    var body: some View {
        if let path = Bundle.main.path(forResource: "ai", ofType: "png"),
           let image = NSImage(contentsOfFile: path)
        {
            imageView(image)
        } else if let path = devPath(),
                  let image = NSImage(contentsOfFile: path)
        {
            imageView(image)
        }
    }

    private func imageView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .cornerRadius(12)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func devPath() -> String? {
        guard let pwd = ProcessInfo.processInfo.environment["PWD"] else { return nil }
        let path = pwd + "/assets/ai.png"
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}
