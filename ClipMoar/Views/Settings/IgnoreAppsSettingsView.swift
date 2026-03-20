import SwiftUI

struct IgnoreAppsSettingsView: View {
    let settings: SettingsStore
    @State private var ignoredIds: [String]
    @State private var selectedApp = ""

    init(settings: SettingsStore) {
        self.settings = settings
        _ignoredIds = State(initialValue: settings.ignoredAppBundleIds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ignored Applications")
                .font(.title2.bold())

            Text("Clipboard content from these applications will not be saved to history.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("", selection: $selectedApp) {
                Text("Select application to ignore...").tag("")
                Divider()
                ForEach(availableApps, id: \.bundleId) { app in
                    Label {
                        Text(app.name)
                    } icon: {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                        }
                    }
                    .tag(app.bundleId)
                }
            }
            .labelsHidden()
            .onChange(of: selectedApp) {
                guard !selectedApp.isEmpty, !ignoredIds.contains(selectedApp) else { return }
                ignoredIds.append(selectedApp)
                settings.ignoredAppBundleIds = ignoredIds
                selectedApp = ""
            }

            if ignoredIds.isEmpty {
                Text("No ignored applications")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(ignoredIds.enumerated()), id: \.element) { index, bundleId in
                        HStack(spacing: 8) {
                            if let icon = appIcon(for: bundleId) {
                                Image(nsImage: icon)
                                    .frame(width: 20, height: 20)
                            }
                            Text(appName(for: bundleId))
                                .font(.system(size: 12))
                            Spacer()
                            Text(bundleId)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Button {
                                ignoredIds.remove(at: index)
                                settings.ignoredAppBundleIds = ignoredIds
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(index % 2 == 0 ? Color.primary.opacity(0.03) : Color.clear)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08)))
            }

            Spacer()
        }
        .padding(20)
    }

    private var availableApps: [(bundleId: String, name: String, icon: NSImage?)] {
        var seen = Set<String>(ignoredIds)
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bundleId = app.bundleIdentifier,
                  !seen.contains(bundleId),
                  app.activationPolicy == .regular else { return nil }
            seen.insert(bundleId)
            let icon = app.icon
            icon?.size = NSSize(width: 16, height: 16)
            return (bundleId, app.localizedName ?? bundleId, icon)
        }
    }

    private func appName(for bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleId
    }

    private func appIcon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 20, height: 20)
        return icon
    }
}
