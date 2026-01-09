import SwiftUI

struct ScreenPositionPickerRepresentable: NSViewRepresentable {
    @Binding var positionX: Double
    @Binding var positionY: Double

    func makeNSView(context: Context) -> ScreenPositionPicker {
        let picker = ScreenPositionPicker()
        picker.positionX = positionX
        picker.positionY = positionY
        picker.onChange = { x, y in
            positionX = x
            positionY = y
        }
        return picker
    }

    func updateNSView(_ picker: ScreenPositionPicker, context: Context) {
        picker.positionX = positionX
        picker.positionY = positionY
    }
}

struct GeneralSettingsView: View {
    let settings: SettingsStore
    var onVisibilityChange: (() -> Void)?
    @State private var showInDock: Bool
    @State private var showInMenuBar: Bool
    @State private var maxHistorySize: Int
    @State private var storeText: Bool
    @State private var storeImages: Bool
    @State private var textRetentionHours: Int
    @State private var imageRetentionHours: Int
    @State private var positionX: Double
    @State private var positionY: Double
    @State private var screenMode: Int
    @State private var largeTypeEnabled: Bool

    init(settings: SettingsStore, onVisibilityChange: (() -> Void)? = nil) {
        self.settings = settings
        self.onVisibilityChange = onVisibilityChange
        _showInDock = State(initialValue: settings.showInDock)
        _showInMenuBar = State(initialValue: settings.showInMenuBar)
        _maxHistorySize = State(initialValue: settings.maxHistorySize)
        _storeText = State(initialValue: settings.storeText)
        _storeImages = State(initialValue: settings.storeImages)
        _textRetentionHours = State(initialValue: settings.textRetentionHours)
        _imageRetentionHours = State(initialValue: settings.imageRetentionHours)
        _positionX = State(initialValue: settings.panelPositionX)
        _positionY = State(initialValue: settings.panelPositionY)
        _screenMode = State(initialValue: settings.panelScreenMode)
        _largeTypeEnabled = State(initialValue: settings.largeTypeEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Visibility").font(.system(size: 13, weight: .semibold))

                    Toggle("Show in Dock", isOn: $showInDock)
                        .onChange(of: showInDock) { settings.showInDock = $0; onVisibilityChange?() }

                    Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                        .onChange(of: showInMenuBar) { settings.showInMenuBar = $0; onVisibilityChange?() }

                    Spacer().frame(height: 12)

                    Text("History").font(.system(size: 13, weight: .semibold))

                    HStack {
                        Text("Max items:")
                        TextField("500", value: $maxHistorySize, format: .number)
                            .frame(width: 70)
                            .onChange(of: maxHistorySize) { settings.maxHistorySize = max(10, $0) }
                    }

                    Spacer().frame(height: 4)

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Keep Plain Text", isOn: $storeText)
                                .onChange(of: storeText) { settings.storeText = $0 }

                            Picker("", selection: $textRetentionHours) {
                                ForEach(TextRetention.allCases, id: \.rawValue) { p in
                                    Text(p.title).tag(p.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            .disabled(!storeText)
                            .onChange(of: textRetentionHours) { settings.textRetentionHours = $0 }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Keep Images", isOn: $storeImages)
                                .onChange(of: storeImages) { settings.storeImages = $0 }

                            Picker("", selection: $imageRetentionHours) {
                                ForEach(ImageRetention.allCases, id: \.rawValue) { p in
                                    Text(p.title).tag(p.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            .disabled(!storeImages)
                            .onChange(of: imageRetentionHours) { settings.imageRetentionHours = $0 }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Panel Position").font(.system(size: 13, weight: .semibold))

                    ScreenPositionPickerRepresentable(
                        positionX: $positionX,
                        positionY: $positionY
                    )
                    .frame(height: 150)
                    .onChange(of: positionX) { settings.panelPositionX = $0 }
                    .onChange(of: positionY) { settings.panelPositionY = $0 }

                    Text("Drag to set panel position")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Show on:")
                        Picker("", selection: $screenMode) {
                            ForEach(PanelScreenMode.allCases, id: \.rawValue) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: screenMode) { settings.panelScreenMode = $0 }
                    }

                    Spacer().frame(height: 12)

                    Text("Large Type").font(.system(size: 13, weight: .semibold))

                    Toggle("Enable Large Type (Tab)", isOn: $largeTypeEnabled)
                        .onChange(of: largeTypeEnabled) { settings.largeTypeEnabled = $0 }

                    Text("Press Tab to preview selected item in large text or Quick Look")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(24)
    }
}
