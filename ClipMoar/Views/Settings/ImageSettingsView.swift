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
    @State private var imageQuality: Double
    @State private var selectedResolution: ImageResolution
    @State private var convertToPNG: Bool
    @State private var convertToJPEG: Bool
    @State private var stripMetadata: Bool
    @State private var autoEnhance: Bool
    @State private var grayscale: Bool
    @State private var autoRotate: Bool
    @State private var trimWhitespace: Bool
    @State private var sharpen: Bool
    @State private var reduceNoise: Bool

    init(settings: SettingsStore) {
        self.settings = settings
        _imageQuality = State(initialValue: Double(settings.imageQuality))
        let w = settings.imageMaxWidth
        let h = settings.imageMaxHeight
        let match = ImageResolution.presets.first { $0.width == w && $0.height == h }
            ?? ImageResolution.presets[0]
        _selectedResolution = State(initialValue: match)
        _convertToPNG = State(initialValue: settings.imageConvertToPNG)
        _convertToJPEG = State(initialValue: settings.imageConvertToJPEG)
        _stripMetadata = State(initialValue: settings.imageStripMetadata)
        _autoEnhance = State(initialValue: settings.imageAutoEnhance)
        _grayscale = State(initialValue: settings.imageGrayscale)
        _autoRotate = State(initialValue: settings.imageAutoRotate)
        _trimWhitespace = State(initialValue: settings.imageTrimWhitespace)
        _sharpen = State(initialValue: settings.imageSharpen)
        _reduceNoise = State(initialValue: settings.imageReduceNoise)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            rescaleSection
            Divider()
            processingSection
        }
        .padding(20)
    }

    private var rescaleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rescale")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Max resolution")
                    Spacer()
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
                        settings.compressImages = selectedResolution.width > 0
                    }
                }
                Text("Images exceeding this resolution will be scaled down proportionally.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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
            .disabled(selectedResolution.width == 0)
            .opacity(selectedResolution.width > 0 ? 1.0 : 0.5)
        }
    }

    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processing")
                .font(.title2.bold())

            Text("Applied automatically when an image is copied to clipboard.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Format").font(.headline).padding(.top, 4)
                    toggle($convertToPNG, key: \.imageConvertToPNG,
                           label: "To PNG", hint: "Lossless, transparency")
                    toggle($convertToJPEG, key: \.imageConvertToJPEG,
                           label: "To JPEG", hint: "Smaller size")
                    toggle($stripMetadata, key: \.imageStripMetadata,
                           label: "Strip EXIF", hint: "Remove metadata")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Cleanup").font(.headline).padding(.top, 4)
                    toggle($autoRotate, key: \.imageAutoRotate,
                           label: "Auto rotate", hint: "EXIF orientation")
                    toggle($trimWhitespace, key: \.imageTrimWhitespace,
                           label: "Trim borders", hint: "Crop margins")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Enhance").font(.headline).padding(.top, 4)
                    toggle($autoEnhance, key: \.imageAutoEnhance,
                           label: "Auto enhance", hint: "Brightness, contrast")
                    toggle($sharpen, key: \.imageSharpen,
                           label: "Sharpen", hint: "Edge clarity")
                    toggle($reduceNoise, key: \.imageReduceNoise,
                           label: "Denoise", hint: "Smooth noise")
                    toggle($grayscale, key: \.imageGrayscale,
                           label: "Grayscale", hint: "Black and white")
                }
            }
        }
    }

    private func toggle(_ binding: Binding<Bool>, key: ReferenceWritableKeyPath<SettingsStore, Bool>,
                        label: String, hint: String) -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(label, isOn: binding)
                .onChange(of: binding.wrappedValue) { settings[keyPath: key] = binding.wrappedValue }
            Text(hint)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 20)
        }
    }
}
