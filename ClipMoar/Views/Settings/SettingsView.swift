import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "general"
    let settings: SettingsStore
    let hotkeyRecorder: HotkeyRecorder

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("General", systemImage: "gearshape")
                    .tag("general")
                Label("Hotkeys", systemImage: "keyboard")
                    .tag("hotkeys")
                Label("Rules", systemImage: "wand.and.stars")
                    .tag("rules")

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
                    GeneralSettingsView(settings: settings)
                case "hotkeys":
                    HotkeySettingsView(recorder: hotkeyRecorder)
                case "rules":
                    RulesSettingsView()
                case "about":
                    AboutSettingsView()
                default:
                    GeneralSettingsView(settings: settings)
                }
            }
        }
        .toolbar(.hidden)
        .navigationSplitViewStyle(.balanced)
    }
}
