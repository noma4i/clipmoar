import Cocoa
import SwiftUI

final class LookEditorModel: ObservableObject {
    let settings: SettingsStore
    @Published var theme: Int
    @Published var fontSize: Int
    @Published var accent: Int
    @Published var largeTypeFontSize: Int

    init(settings: SettingsStore) {
        self.settings = settings
        theme = settings.panelTheme
        fontSize = settings.panelFontSize
        accent = settings.panelAccentColor
        largeTypeFontSize = settings.largeTypeFontSize
    }

    func syncToSettings() {
        settings.panelTheme = theme
        settings.panelFontSize = fontSize
        settings.panelAccentColor = accent
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
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 352),
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
            onChanged: { [weak self] in self?.clipViewController?.refresh() }
        )
        let editorHosting = NSHostingController(rootView: editorView)
        editor.contentViewController = editorHosting

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.visibleFrame
        let totalWidth: CGFloat = 460 + 12 + 300
        let x = screenFrame.midX - totalWidth / 2
        let y = screenFrame.midY - 176

        mock.setFrameOrigin(NSPoint(x: x, y: y))
        editor.setFrameOrigin(NSPoint(x: x + 460 + 12, y: y))

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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Panel")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(nsColor: NSColor(calibratedWhite: 0.9, alpha: 1.0)))

            HStack {
                Text("Theme:")
                    .frame(width: 80, alignment: .trailing)
                Picker("", selection: $model.theme) {
                    ForEach(PanelTheme.allCases, id: \.rawValue) { t in
                        Text(t.title).tag(t.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: model.theme) { _, _ in model.syncToSettings(); onChanged?() }
            }

            HStack {
                Text("Font size:")
                    .frame(width: 80, alignment: .trailing)
                Picker("", selection: $model.fontSize) {
                    ForEach(PanelFontSize.allCases, id: \.rawValue) { s in
                        Text(s.title).tag(s.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: model.fontSize) { _, _ in model.syncToSettings(); onChanged?() }
            }

            HStack {
                Text("Accent:")
                    .frame(width: 80, alignment: .trailing)
                HStack(spacing: 6) {
                    ForEach(AccentColor.allCases, id: \.rawValue) { c in
                        Circle()
                            .fill(Color(nsColor: c.color))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: model.accent == c.rawValue ? 2 : 0)
                            )
                            .onTapGesture {
                                model.accent = c.rawValue
                                model.syncToSettings()
                                onChanged?()
                            }
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))

            Text("Large Type")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(nsColor: NSColor(calibratedWhite: 0.9, alpha: 1.0)))

            HStack {
                Text("Size:")
                    .frame(width: 80, alignment: .trailing)
                Slider(value: Binding(
                    get: { Double(model.largeTypeFontSize) },
                    set: {
                        model.largeTypeFontSize = Int($0)
                        model.syncToSettings()
                    }
                ), in: 24 ... 120, step: 4)
                    .frame(width: 120)
                Text("\(model.largeTypeFontSize)pt")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 36)
            }

            largeTypePreview
                .frame(height: 80)

            Spacer()

            HStack {
                Text("ESC to close")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: NSColor(calibratedWhite: 0.45, alpha: 1.0)))
                Spacer()
                Button("Done") { onDone() }
                    .keyboardShortcut(.return)
                    .controlSize(.regular)
            }
        }
        .padding(16)
        .frame(width: 300, height: 352)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.13, alpha: 1.0)))
        .environment(\.colorScheme, .dark)
    }

    private var largeTypePreview: some View {
        ZStack {
            Color.black.opacity(0.6)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(white: 0.08, alpha: 0.9)))
                .padding(8)
            Text("ClipMoar")
                .font(.system(size: CGFloat(model.largeTypeFontSize) * 0.35, weight: .medium))
                .foregroundColor(.white)
        }
        .cornerRadius(6)
    }
}
