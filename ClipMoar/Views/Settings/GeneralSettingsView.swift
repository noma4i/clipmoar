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
    @State private var showInDock: Bool
    @State private var showInMenuBar: Bool
    @State private var maxHistorySize: Int
    @State private var storeImages: Bool
    @State private var positionX: Double
    @State private var positionY: Double
    @State private var screenMode: Int

    init(settings: SettingsStore) {
        self.settings = settings
        _showInDock = State(initialValue: settings.showInDock)
        _showInMenuBar = State(initialValue: settings.showInMenuBar)
        _maxHistorySize = State(initialValue: settings.maxHistorySize)
        _storeImages = State(initialValue: settings.storeImages)
        _positionX = State(initialValue: settings.panelPositionX)
        _positionY = State(initialValue: settings.panelPositionY)
        _screenMode = State(initialValue: settings.panelScreenMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("General")
                .font(.system(size: 18, weight: .semibold))
                .padding(.bottom, 20)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Visibility").font(.system(size: 13, weight: .semibold))

                    Toggle("Show in Dock", isOn: $showInDock)
                        .onChange(of: showInDock) { settings.showInDock = $0 }

                    Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                        .onChange(of: showInMenuBar) { settings.showInMenuBar = $0 }

                    Spacer().frame(height: 12)

                    Text("History").font(.system(size: 13, weight: .semibold))

                    HStack {
                        Text("Max items:")
                        TextField("500", value: $maxHistorySize, format: .number)
                            .frame(width: 70)
                            .onChange(of: maxHistorySize) { settings.maxHistorySize = max(10, $0) }
                    }

                    Toggle("Store images in history", isOn: $storeImages)
                        .onChange(of: storeImages) { settings.storeImages = $0 }
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(24)
    }
}
