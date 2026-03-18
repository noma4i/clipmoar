import ServiceManagement
import SwiftUI

struct ScreenPositionPickerRepresentable: NSViewRepresentable {
    @Binding var positionX: Double
    @Binding var positionY: Double

    func makeNSView(context _: Context) -> ScreenPositionPicker {
        let picker = ScreenPositionPicker()
        picker.positionX = positionX
        picker.positionY = positionY
        picker.onChange = { x, y in
            positionX = x
            positionY = y
        }
        return picker
    }

    func updateNSView(_ picker: ScreenPositionPicker, context _: Context) {
        picker.positionX = positionX
        picker.positionY = positionY
    }
}

struct GeneralSettingsView: View {
    let settings: SettingsStore
    let repository: ClipboardRepository
    let launchAtLoginProvider: () -> Bool
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
    @State private var launchAtLogin: Bool = false
    @State private var stats: StorageStats = .init()

    init(
        settings: SettingsStore,
        repository: ClipboardRepository = CoreDataClipboardRepository(),
        onVisibilityChange: (() -> Void)? = nil,
        launchAtLoginProvider: @escaping () -> Bool = { SMAppService.mainApp.status == .enabled }
    ) {
        self.settings = settings
        self.repository = repository
        self.onVisibilityChange = onVisibilityChange
        self.launchAtLoginProvider = launchAtLoginProvider
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

                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }

                    Toggle("Show in Dock", isOn: $showInDock)
                        .onChange(of: showInDock) {
                            settings.showInDock = showInDock
                            onVisibilityChange?()
                        }

                    Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                        .onChange(of: showInMenuBar) {
                            settings.showInMenuBar = showInMenuBar
                            onVisibilityChange?()
                        }

                    Spacer().frame(height: 12)

                    Text("History").font(.system(size: 13, weight: .semibold))

                    HStack {
                        Text("Max items:")
                        TextField("500", value: $maxHistorySize, format: .number)
                            .frame(width: 70)
                            .onChange(of: maxHistorySize) { settings.maxHistorySize = max(10, maxHistorySize) }
                    }

                    Spacer().frame(height: 4)

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Keep Plain Text", isOn: $storeText)
                                .onChange(of: storeText) { settings.storeText = storeText }

                            Picker("", selection: $textRetentionHours) {
                                ForEach(TextRetention.allCases, id: \.rawValue) { p in
                                    Text(p.title).tag(p.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            .disabled(!storeText)
                            .onChange(of: textRetentionHours) { settings.textRetentionHours = textRetentionHours }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Keep Images", isOn: $storeImages)
                                .onChange(of: storeImages) { settings.storeImages = storeImages }

                            Picker("", selection: $imageRetentionHours) {
                                ForEach(ImageRetention.allCases, id: \.rawValue) { p in
                                    Text(p.title).tag(p.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            .disabled(!storeImages)
                            .onChange(of: imageRetentionHours) { settings.imageRetentionHours = imageRetentionHours }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                    }

                    Spacer().frame(height: 12)

                    storageSection
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
                    .onChange(of: positionX) { settings.panelPositionX = positionX }
                    .onChange(of: positionY) { settings.panelPositionY = positionY }

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
                        .onChange(of: screenMode) { settings.panelScreenMode = screenMode }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(24)
        .onAppear {
            refreshStats()
            launchAtLogin = launchAtLoginProvider()
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Storage").font(.system(size: 13, weight: .semibold))

            VStack(spacing: 0) {
                HStack {
                    Text("Type")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text("Count")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    Text("Size")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Divider().padding(.horizontal, 6)

                storageRow(label: "Texts", count: stats.textCount + stats.fileCount, size: stats.textBytes) {
                    repository.clearAll(contentType: ClipboardItemType.text.rawValue)
                    repository.clearAll(contentType: ClipboardItemType.file.rawValue)
                    refreshStats()
                }

                Divider().padding(.horizontal, 6)

                storageRow(label: "Images", count: stats.imageCount, size: stats.imageBytes) {
                    repository.clearAll(contentType: ClipboardItemType.image.rawValue)
                    refreshStats()
                }

                Divider().padding(.horizontal, 6)

                HStack {
                    Text("Total")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 70, alignment: .leading)
                    Text("\(stats.textCount + stats.fileCount + stats.imageCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 50, alignment: .trailing)
                    Text(stats.formatted(stats.totalBytes))
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 70, alignment: .trailing)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        }
    }

    private func storageRow(label: String, count: Int, size: Int64, onClear: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 70, alignment: .leading)
            Text("\(count)")
                .font(.system(size: 11))
                .frame(width: 50, alignment: .trailing)
            Text(stats.formatted(size))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Spacer()
            Button("Clear") { onClear() }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.red.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }

    private func refreshStats() {
        stats = repository.storageStats()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            launchAtLogin = !enabled
        }
    }
}
