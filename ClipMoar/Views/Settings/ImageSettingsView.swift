import SwiftUI

private struct ImageResolution: Hashable {
    let width: Int
    let height: Int
    let label: String

    static let presets: [ImageResolution] = [
        ImageResolution(width: 0, height: 0, label: "No limit"),
        ImageResolution(width: 640, height: 480, label: "640x480 (VGA)"),
        ImageResolution(width: 800, height: 600, label: "800x600 (SVGA)"),
        ImageResolution(width: 1024, height: 768, label: "1024x768 (XGA)"),
        ImageResolution(width: 1280, height: 720, label: "1280x720 (HD)"),
        ImageResolution(width: 1920, height: 1080, label: "1920x1080 (Full HD)"),
        ImageResolution(width: 2560, height: 1440, label: "2560x1440 (QHD)"),
        ImageResolution(width: 3840, height: 2160, label: "3840x2160 (4K)"),
    ]
}

struct ImageSettingsView: View {
    let settings: SettingsStore
    @State private var compressImages: Bool
    @State private var imageQuality: Double
    @State private var selectedResolution: ImageResolution

    init(settings: SettingsStore) {
        self.settings = settings
        _compressImages = State(initialValue: settings.compressImages)
        _imageQuality = State(initialValue: Double(settings.imageQuality))

        let w = settings.imageMaxWidth
        let h = settings.imageMaxHeight
        let match = ImageResolution.presets.first { $0.width == w && $0.height == h }
            ?? ImageResolution.presets[0]
        _selectedResolution = State(initialValue: match)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Image Compression")
                .font(.title2.bold())

            Toggle("Compress images when copied", isOn: $compressImages)
                .onChange(of: compressImages) { settings.compressImages = compressImages }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Quality")
                        Spacer()
                        Text("\(Int(imageQuality))%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $imageQuality, in: 10 ... 100, step: 5)
                        .onChange(of: imageQuality) { settings.imageQuality = Int(imageQuality) }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Max resolution")
                    Picker("", selection: $selectedResolution) {
                        ForEach(ImageResolution.presets, id: \.self) { res in
                            Text(res.label).tag(res)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                    .onChange(of: selectedResolution) {
                        settings.imageMaxWidth = selectedResolution.width
                        settings.imageMaxHeight = selectedResolution.height
                    }
                }

                Text("Images exceeding the selected resolution will be scaled down proportionally.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .disabled(!compressImages)
            .opacity(compressImages ? 1.0 : 0.5)

            Spacer()
        }
        .padding(20)
    }
}
