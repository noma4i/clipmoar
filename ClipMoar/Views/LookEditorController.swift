import Cocoa
import SwiftUI

final class LookEditorModel: ObservableObject {
    let settings: SettingsStore
    @Published var theme: Int
    @Published var fontSize: Int
    @Published var accent: Int
    @Published var cornerRadius: Int
    @Published var padding: Int
    @Published var fontWeight: Int
    @Published var largeTypeFontSize: Int

    init(settings: SettingsStore) {
        self.settings = settings
        theme = settings.panelTheme
        fontSize = settings.panelFontSize
        accent = settings.panelAccentColor
        cornerRadius = settings.panelCornerRadius
        padding = settings.panelPadding
        fontWeight = settings.panelFontWeight
        largeTypeFontSize = settings.largeTypeFontSize
    }

    func syncToSettings() {
        settings.panelTheme = theme
        settings.panelFontSize = fontSize
        settings.panelAccentColor = accent
        settings.panelCornerRadius = cornerRadius
        settings.panelPadding = padding
        settings.panelFontWeight = fontWeight
        settings.largeTypeFontSize = largeTypeFontSize
    }
}

final class LookEditorController {
    private var mockPanel: NSPanel?
    private var editorPanel: NSPanel?
    private var clipViewController: FloatingClipboardViewController?
    private let settings: SettingsStore
    private let repository: ClipboardRepository
    private let actionService: ClipboardActionServicing
    private let onDismiss: () -> Void
    private var escapeMonitor: Any?

    init(settings: SettingsStore, repository: ClipboardRepository, actionService: ClipboardActionServicing, onDismiss: @escaping () -> Void) {
        self.settings = settings
        self.repository = repository
        self.actionService = actionService
        self.onDismiss = onDismiss
    }

    func show() {
        if let m = mockPanel, m.isVisible, let e = editorPanel, e.isVisible {
            m.makeKeyAndOrderFront(nil)
            e.makeKeyAndOrderFront(nil)
            return
        }

        cleanup()

        let model = LookEditorModel(settings: settings)

        let vc = FloatingClipboardViewController(
            repository: repository,
            actionService: actionService,
            settings: settings
        )
        vc.previewOnly = true
        clipViewController = vc

        let mock = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 352),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        mock.level = .floating
        mock.isOpaque = true
        mock.backgroundColor = .black
        mock.hasShadow = true
        mock.hidesOnDeactivate = false
        mock.isMovableByWindowBackground = true
        mock.contentView = vc.view

        vc.refresh()

        let editor = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        editor.level = .floating
        editor.isOpaque = true
        editor.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1.0)
        editor.hasShadow = true
        editor.hidesOnDeactivate = false
        editor.isMovableByWindowBackground = true

        let editorView = EditorControlsView(
            model: model,
            onDone: { [weak self] in self?.dismiss() },
            onChanged: { [weak self] in self?.clipViewController?.applyTheme() }
        )
        let editorHosting = NSHostingController(rootView: editorView)
        editor.contentViewController = editorHosting

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.visibleFrame
        let mockWidth: CGFloat = 460
        let mockX = screenFrame.midX - mockWidth / 2
        let mockY = screenFrame.midY - 176

        mock.setFrameOrigin(NSPoint(x: mockX, y: mockY))
        editor.setFrameOrigin(NSPoint(x: mockX + mockWidth + 260 + 12, y: mockY - 34))

        mock.orderFront(nil)
        editor.makeKeyAndOrderFront(nil)

        mockPanel = mock
        editorPanel = editor

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53,
                  self?.editorPanel?.isVisible == true || self?.mockPanel?.isVisible == true
            else { return event }
            self?.dismiss()
            return nil
        }
    }

    func dismiss() {
        cleanup()
        onDismiss()
    }

    private func cleanup() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
        mockPanel?.orderOut(nil)
        mockPanel = nil
        editorPanel?.orderOut(nil)
        editorPanel = nil
        clipViewController = nil
    }
}

private struct MockPanelView: View {
    @ObservedObject var model: LookEditorModel

    private var bgColor: Color {
        let theme = PanelTheme(rawValue: model.theme) ?? .dark
        switch theme {
        case .dark: return Color(nsColor: NSColor(calibratedWhite: 0.13, alpha: 1.0))
        case .light: return Color(nsColor: NSColor(calibratedWhite: 0.95, alpha: 1.0))
        case .system: return Color(nsColor: .windowBackgroundColor)
        }
    }

    private var textColor: Color {
        let theme = PanelTheme(rawValue: model.theme) ?? .dark
        switch theme {
        case .dark: return Color(nsColor: NSColor(calibratedWhite: 0.9, alpha: 1.0))
        case .light: return Color(nsColor: NSColor(calibratedWhite: 0.1, alpha: 1.0))
        case .system: return .primary
        }
    }

    private var shortcutColor: Color {
        let theme = PanelTheme(rawValue: model.theme) ?? .dark
        switch theme {
        case .dark: return Color(nsColor: NSColor(calibratedWhite: 0.45, alpha: 1.0))
        case .light: return Color(nsColor: NSColor(calibratedWhite: 0.5, alpha: 1.0))
        case .system: return .secondary
        }
    }

    private var selectionColor: Color {
        Color(nsColor: (AccentColor(rawValue: model.accent) ?? .blue).color)
    }

    private var fontSize: CGFloat {
        CGFloat(model.fontSize)
    }

    private let sampleRows: [(text: String, icon: String)] = [
        ("Hello World", "doc.on.clipboard"),
        ("Screenshot.png", "photo"),
        ("git commit -m \"fix\"", "terminal"),
        ("/usr/local/bin/app", "folder"),
        ("https://example.com", "link"),
        ("SELECT * FROM users", "cylinder"),
        ("Lorem ipsum dolor sit", "doc.text"),
        ("config.yaml", "gearshape"),
    ]

    private var previewBgColor: Color {
        let theme = PanelTheme(rawValue: model.theme) ?? .dark
        switch theme {
        case .dark: return Color(nsColor: NSColor(calibratedWhite: 0.10, alpha: 1.0))
        case .light: return Color(nsColor: NSColor(calibratedWhite: 0.90, alpha: 1.0))
        case .system: return Color(nsColor: .controlBackgroundColor)
        }
    }

    private var metaPillColor: Color {
        Color(nsColor: NSColor(calibratedWhite: 0.0, alpha: 0.5))
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: fontSize - 4))
                        .foregroundColor(textColor.opacity(0.3))
                    Text("Type to search...")
                        .font(.system(size: fontSize))
                        .foregroundColor(textColor.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Rectangle()
                    .fill(textColor.opacity(0.15))
                    .frame(height: 1)

                ForEach(Array(sampleRows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 8) {
                        Image(systemName: row.icon)
                            .font(.system(size: fontSize - 4))
                            .frame(width: 22)
                            .foregroundColor(index == 0 ? .white : textColor.opacity(0.7))

                        Text(row.text)
                            .font(.system(size: fontSize))
                            .foregroundColor(index == 0 ? .white : textColor)
                            .lineLimit(1)

                        Spacer()

                        if index < 9 {
                            Text("\u{2318}\(index + 1)")
                                .font(.system(size: fontSize - 4, design: .monospaced))
                                .foregroundColor(index == 0 ? .white.opacity(0.6) : shortcutColor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: max(fontSize * 2.2, 28))
                    .background(index == 0 ? selectionColor : Color.clear)
                }

                Spacer()
            }
            .frame(width: 460)

            VStack(alignment: .leading, spacing: 0) {
                Text("Hello World")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.85))
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack {
                    Spacer()
                    Text("2 words; 11 chars  Copied Today 00:01")
                        .font(.system(size: 10))
                        .foregroundColor(textColor.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(metaPillColor))
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            .frame(width: 260)
            .background(previewBgColor)
        }
        .frame(width: 720, height: 352)
        .background(bgColor)
    }
}

private struct EditorControlsView: View {
    @ObservedObject var model: LookEditorModel
    let onDone: () -> Void
    var onChanged: (() -> Void)?

    private func changed() {
        model.syncToSettings()
        onChanged?()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            themePills

            Divider()

            HStack(alignment: .top, spacing: 20) {
                listSettings
                Divider()
                panelSettings
            }

            Spacer()

            HStack {
                Text("ESC to close")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") { onDone() }
                    .keyboardShortcut(.return)
                    .controlSize(.regular)
            }
        }
        .padding(16)
        .frame(width: 460, height: 420)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.13, alpha: 1.0)))
        .environment(\.colorScheme, .dark)
    }

    private var themePills: some View {
        HStack(spacing: 0) {
            ForEach(PanelTheme.allCases, id: \.rawValue) { theme in
                Button {
                    model.theme = theme.rawValue
                    changed()
                } label: {
                    Text(theme.title)
                        .font(.system(size: 12, weight: model.theme == theme.rawValue ? .semibold : .regular))
                        .foregroundColor(model.theme == theme.rawValue ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            model.theme == theme.rawValue
                                ? RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: (AccentColor(rawValue: model.accent) ?? .blue).color))
                                : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
    }

    private var listSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("List")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            settingRow("Font size:") {
                Picker("", selection: Binding(
                    get: { model.fontSize },
                    set: { model.fontSize = $0; changed() }
                )) {
                    ForEach(PanelFontSize.allCases, id: \.rawValue) { s in
                        Text(s.title).tag(s.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }

            settingRow("Font weight:") {
                Picker("", selection: Binding(
                    get: { model.fontWeight },
                    set: { model.fontWeight = $0; changed() }
                )) {
                    Text("Regular").tag(0)
                    Text("Medium").tag(1)
                    Text("Bold").tag(2)
                }
                .labelsHidden()
                .frame(width: 100)
            }

            settingRow("Accent:") {
                HStack(spacing: 5) {
                    ForEach(AccentColor.allCases, id: \.rawValue) { c in
                        Circle()
                            .fill(Color(nsColor: c.color))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: model.accent == c.rawValue ? 2 : 0)
                            )
                            .onTapGesture {
                                model.accent = c.rawValue
                                changed()
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var panelSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Panel")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            settingRow("Corner:") {
                HStack(spacing: 4) {
                    Slider(value: Binding(
                        get: { Double(model.cornerRadius) },
                        set: { model.cornerRadius = Int($0); changed() }
                    ), in: 0 ... 20, step: 2)
                        .frame(width: 80)
                    Text("\(model.cornerRadius)px")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32)
                }
            }

            settingRow("Padding:") {
                HStack(spacing: 4) {
                    Slider(value: Binding(
                        get: { Double(model.padding) },
                        set: { model.padding = Int($0); changed() }
                    ), in: 4 ... 24, step: 2)
                        .frame(width: 80)
                    Text("\(model.padding)px")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var largeTypeSection: some View {
        HStack {
            Text("Large Type:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Slider(value: Binding(
                get: { Double(model.largeTypeFontSize) },
                set: { model.largeTypeFontSize = Int($0); model.syncToSettings() }
            ), in: 24 ... 120, step: 4)
                .frame(width: 120)
            Text("\(model.largeTypeFontSize)pt")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 32)
        }
    }

    private func settingRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 70, alignment: .trailing)
            content()
        }
    }
}
