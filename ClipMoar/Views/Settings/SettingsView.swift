import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "general"
    let settings: SettingsStore
    let hotkeyRecorder: HotkeyRecorder
    var onVisibilityChange: (() -> Void)?
    var onEditLook: (() -> Void)?
    var updateService: UpdateService?

    init(
        settings: SettingsStore,
        hotkeyRecorder: HotkeyRecorder,
        onVisibilityChange: (() -> Void)? = nil,
        onEditLook: (() -> Void)? = nil,
        updateService: UpdateService? = nil,
        initialTab: String = "general"
    ) {
        self.settings = settings
        self.hotkeyRecorder = hotkeyRecorder
        self.onVisibilityChange = onVisibilityChange
        self.onEditLook = onEditLook
        self.updateService = updateService
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
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
                case "general":
                    GeneralSettingsView(settings: settings, onVisibilityChange: onVisibilityChange)
                case "hotkeys":
                    HotkeySettingsView(recorder: hotkeyRecorder)
                case "rules":
                    RulesSettingsView()
                case "lookfeel":
                    GeneralSettingsView(settings: settings, onVisibilityChange: onVisibilityChange)
                case "transforms":
                    TransformsSettingsView()
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
    }
}
