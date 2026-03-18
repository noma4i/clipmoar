#if DEBUG
    import AppKit
    import SwiftUI

    struct FloatingClipboardPreviewHost: NSViewControllerRepresentable {
        let scenario: PanelPreviewScenario
        let settings: PreviewSettingsStore

        func makeNSViewController(context _: Context) -> FloatingClipboardViewController {
            let controller = FloatingClipboardViewController(
                repository: PreviewFixtures.makePanelRepository(scenario: scenario),
                actionService: PreviewClipboardActionService(),
                settings: settings,
                isPreviewRenderer: true
            )
            controller.previewOnly = true
            controller.loadViewIfNeeded()
            controller.refresh()
            return controller
        }

        func updateNSViewController(_ controller: FloatingClipboardViewController, context _: Context) {
            let layout = settings.panelConfiguration().layout
            let width = layout.listWidth + (scenario.wantsExpandedPreview ? layout.previewWidth : 0)
            controller.view.frame = NSRect(x: 0, y: 0, width: width, height: layout.panelHeight)
        }
    }

    struct ClipboardHistoryPreviewHost: NSViewControllerRepresentable {
        let context: NSManagedObjectContext

        func makeNSViewController(context _: Context) -> ClipboardHistoryViewController {
            let repository = CoreDataClipboardRepository(context: context)
            let controller = ClipboardHistoryViewController(
                repository: repository,
                actionService: PreviewClipboardActionService(),
                context: context
            )
            controller.loadViewIfNeeded()
            return controller
        }

        func updateNSViewController(_: ClipboardHistoryViewController, context _: Context) {}
    }

    private struct FauxWindowSurface<Content: View>: View {
        let title: String
        let content: Content

        init(title: String, @ViewBuilder content: () -> Content) {
            self.title = title
            self.content = content()
        }

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 10, height: 10)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 10, height: 10)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                    Spacer()
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Color.clear.frame(width: 46, height: 1)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Color(nsColor: NSColor.windowBackgroundColor))

                content
                    .background(Color(nsColor: NSColor.controlBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.1)))
            .shadow(color: Color.black.opacity(0.12), radius: 14, y: 8)
        }
    }

    private struct LargeTypePreviewScene: View {
        let scenario: LargeTypePreviewScenario
        let settings: PreviewSettingsStore

        var body: some View {
            ZStack {
                Color.black.opacity(0.62)

                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: NSColor(white: 0.08, alpha: 0.92)))
                    .frame(width: scenario == .text ? 520 : 420, height: scenario == .text ? 220 : 300)
                    .overlay {
                        content
                            .padding(24)
                    }
            }
            .frame(width: 760, height: 420)
        }

        @ViewBuilder
        private var content: some View {
            switch scenario {
            case .text:
                Text("ClipMoar")
                    .font(.system(size: CGFloat(settings.largeTypeFontSize), weight: .medium))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.4)
            case .image:
                if let image = NSImage(data: PreviewFixtures.makePreviewImageData(size: NSSize(width: 420, height: 240))) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
        }
    }

    private struct LookEditorPreviewScene: View {
        let settings: PreviewSettingsStore

        var body: some View {
            let model = LookEditorModel(settings: settings)

            return ZStack {
                Color.black.opacity(0.55)

                HStack(alignment: .center, spacing: 12) {
                    FauxWindowSurface(title: "Mock Panel") {
                        MockPanelView(model: model)
                    }
                    .frame(width: 720, height: 352)

                    FauxWindowSurface(title: "Look Editor") {
                        EditorControlsView(model: model)
                    }
                    .frame(width: 500)
                }
                .padding(32)
            }
            .frame(width: 1360, height: 720)
        }
    }

    @available(macOS 14.0, *)
    #Preview("Settings - General") {
        let settings = PreviewFixtures.makeSettings(theme: .dark)
        let recorder = PreviewFixtures.makeHotkeyRecorder(settings: settings)
        return FauxWindowSurface(title: "Preferences") {
            SettingsView(
                settings: settings,
                hotkeyRecorder: recorder,
                onVisibilityChange: {},
                onEditLook: {},
                initialTab: "general"
            )
        }
        .frame(width: 860, height: 540)
    }

    @available(macOS 14.0, *)
    #Preview("Settings - Hotkeys") {
        let settings = PreviewFixtures.makeSettings(theme: .dark)
        let recorder = PreviewFixtures.makeHotkeyRecorder(settings: settings)
        return HotkeySettingsView(recorder: recorder)
            .frame(width: 520, height: 260)
    }

    @available(macOS 14.0, *)
    #Preview("Settings - Rules") {
        RulesSettingsView(
            model: PreviewFixtures.makeRulesModel(),
            regexStore: PreviewFixtures.makeRegexStore()
        )
        .frame(width: 860, height: 620)
    }

    @available(macOS 14.0, *)
    #Preview("Settings - Transforms") {
        TransformsSettingsView(regexStore: PreviewFixtures.makeRegexStore())
            .frame(width: 620, height: 360)
    }

    @available(macOS 14.0, *)
    #Preview("Settings - Regex") {
        RegexSettingsView(store: PreviewFixtures.makeRegexStore())
            .frame(width: 620, height: 360)
    }

    @available(macOS 14.0, *)
    #Preview("Settings - About") {
        AboutSettingsView()
            .frame(width: 520, height: 380)
    }

    @available(macOS 14.0, *)
    #Preview("Floating Panel - Empty") {
        let settings = PreviewFixtures.makeSettings(theme: .dark)
        return FloatingClipboardPreviewHost(scenario: .empty, settings: settings)
            .frame(width: 460, height: settings.panelConfiguration().layout.panelHeight)
    }

    @available(macOS 14.0, *)
    #Preview("Floating Panel - List Light") {
        let settings = PreviewFixtures.makeSettings(theme: .light)
        return FloatingClipboardPreviewHost(scenario: .list, settings: settings)
            .frame(width: 460, height: settings.panelConfiguration().layout.panelHeight)
    }

    @available(macOS 14.0, *)
    #Preview("Floating Panel - Text Preview") {
        let settings = PreviewFixtures.makeSettings(theme: .dark)
        let layout = settings.panelConfiguration().layout
        return FloatingClipboardPreviewHost(scenario: .textPreview, settings: settings)
            .frame(width: layout.listWidth + layout.previewWidth, height: layout.panelHeight)
    }

    @available(macOS 14.0, *)
    #Preview("Floating Panel - Image Preview") {
        let settings = PreviewFixtures.makeSettings(theme: .dark)
        let layout = settings.panelConfiguration().layout
        return FloatingClipboardPreviewHost(scenario: .imagePreview, settings: settings)
            .frame(width: layout.listWidth + layout.previewWidth, height: layout.panelHeight)
    }

    @available(macOS 14.0, *)
    #Preview("History Window") {
        FauxWindowSurface(title: "ClipMoar") {
            ClipboardHistoryPreviewHost(context: PreviewFixtures.makeHistoryContext())
        }
        .frame(width: 400, height: 600)
    }

    @available(macOS 14.0, *)
    #Preview("General Settings") {
        let settings = PreviewFixtures.makeSettings(theme: .dark)
        return GeneralSettingsView(
            settings: settings,
            repository: PreviewFixtures.makePanelRepository(scenario: .list),
            onVisibilityChange: {},
            launchAtLoginProvider: { false }
        )
        .frame(width: 760, height: 520)
    }

    @available(macOS 14.0, *)
    #Preview("Look And Feel") {
        LookAndFeelSettingsView(settings: PreviewFixtures.makeSettings(theme: .dark), onEditLook: {})
            .frame(width: 420, height: 340)
    }

    @available(macOS 14.0, *)
    #Preview("Large Type - Text") {
        LargeTypePreviewScene(scenario: .text, settings: PreviewFixtures.makeSettings(theme: .dark))
    }

    @available(macOS 14.0, *)
    #Preview("Large Type - Image") {
        LargeTypePreviewScene(scenario: .image, settings: PreviewFixtures.makeSettings(theme: .dark))
    }

    @available(macOS 14.0, *)
    #Preview("Look Editor Scene") {
        LookEditorPreviewScene(settings: PreviewFixtures.makeSettings(theme: .dark))
    }
#endif
