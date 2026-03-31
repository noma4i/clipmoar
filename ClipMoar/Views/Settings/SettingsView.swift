import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "general"
    let settings: SettingsStore
    let hotkeyRecorder: HotkeyRecorder
    var transformHotkeyRecorder: HotkeyRecorder?
    var onVisibilityChange: (() -> Void)?
    var onEditLook: (() -> Void)?
    var updateService: UpdateService?
    var statsService: StatsService?

    init(
        settings: SettingsStore,
        hotkeyRecorder: HotkeyRecorder,
        transformHotkeyRecorder: HotkeyRecorder? = nil,
        onVisibilityChange: (() -> Void)? = nil,
        onEditLook: (() -> Void)? = nil,
        updateService: UpdateService? = nil,
        statsService: StatsService? = nil,
        initialTab: String = "stats"
    ) {
        self.settings = settings
        self.hotkeyRecorder = hotkeyRecorder
        self.transformHotkeyRecorder = transformHotkeyRecorder
        self.onVisibilityChange = onVisibilityChange
        self.onEditLook = onEditLook
        self.updateService = updateService
        self.statsService = statsService
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("Stats", systemImage: "chart.bar.fill")
                    .tag("stats")
                Label("General", systemImage: "gearshape")
                    .tag("general")
                Label("Hotkeys", systemImage: "keyboard")
                    .tag("hotkeys")
                Label("Look", systemImage: "paintbrush")
                    .tag("lookfeel")

                Divider()

                Label("Rules", systemImage: "wand.and.stars")
                    .tag("rules")
                Label("Transforms", systemImage: "wand.and.rays")
                    .tag("transforms")
                Label("Presets", systemImage: "tray.2")
                    .tag("presets")
                Label("Regex", systemImage: "number.circle")
                    .tag("regex")
                Label("Images", systemImage: "photo")
                    .tag("images")
                Label("Ignore Apps", systemImage: "nosign")
                    .tag("ignore")
                Label("AI", systemImage: "brain")
                    .tag("ai")

                Divider()

                Label("About", systemImage: "info.circle")
                    .tag("about")
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(160)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selectedTab {
                case "stats":
                    if let statsService {
                        StatsSettingsView(statsService: statsService)
                    }
                case "general":
                    GeneralSettingsView(settings: settings, onVisibilityChange: onVisibilityChange)
                case "hotkeys":
                    HotkeySettingsView(recorder: hotkeyRecorder, transformRecorder: transformHotkeyRecorder, settings: settings)
                case "rules":
                    RulesSettingsView()
                case "lookfeel":
                    GeneralSettingsView(settings: settings, onVisibilityChange: onVisibilityChange)
                case "transforms":
                    TransformsSettingsView()
                case "presets":
                    PresetSettingsView()
                case "regex":
                    RegexSettingsView()
                case "images":
                    ImageSettingsView(settings: settings)
                case "ignore":
                    IgnoreAppsSettingsView(settings: settings)
                case "ai":
                    AISettingsView()
                case "about":
                    AboutSettingsView(updateService: updateService)
                default:
                    GeneralSettingsView(settings: settings, onVisibilityChange: onVisibilityChange)
                }
            }
        }
        .toolbar(.hidden)
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedTab) {
            if selectedTab == "lookfeel" {
                selectedTab = "general"
                onEditLook?()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsSelectTab)) { notification in
            if let tab = notification.object as? String {
                selectedTab = tab
            }
        }
    }
}
