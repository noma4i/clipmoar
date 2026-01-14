import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "general"
    let settings: SettingsStore
    let hotkeyRecorder: HotkeyRecorder
    var onVisibilityChange: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedTab) {
                Label("General", systemImage: "gearshape")
                    .tag("general")
                Label("Hotkeys", systemImage: "keyboard")
                    .tag("hotkeys")
                Label("Rules", systemImage: "wand.and.stars")
                    .tag("rules")
                Label("Transforms", systemImage: "wand.and.rays")
                    .tag("transforms")

                Divider()

                Label("About", systemImage: "info.circle")
                    .tag("about")
            }
            .listStyle(.sidebar)
            .frame(width: 160)

            Divider()

            Group {
                switch selectedTab {
                case "general":
                    GeneralSettingsView(settings: settings, onVisibilityChange: onVisibilityChange)
                case "hotkeys":
                    HotkeySettingsView(recorder: hotkeyRecorder)
                case "rules":
                    RulesSettingsView()
                case "transforms":
                    TransformsSettingsView()
                case "about":
                    AboutSettingsView()
                default:
                    GeneralSettingsView(settings: settings, onVisibilityChange: onVisibilityChange)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
