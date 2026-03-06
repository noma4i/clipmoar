import Cocoa
import SwiftUI

private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

final class LookEditorModel: ObservableObject {
    let settings: SettingsStore
    @Published var theme: Int
    @Published var fontName: String
    @Published var fontSize: Int
    @Published var fontWeight: Int
    @Published var iconSize: Int
    @Published var visibleRows: Int
    @Published var accentHex: String
    @Published var textColorHex: String
    @Published var cornerRadius: Int
    @Published var paddingH: Int
    @Published var paddingV: Int
    @Published var margin: Int
    @Published var previewFontName: String
    @Published var previewFontSize: Int
    @Published var previewPadding: Int
    @Published var previewTextColorHex: String
    @Published var previewBgColorHex: String
    @Published var searchFontName: String
    @Published var searchFontSize: Int
    @Published var searchTextColorHex: String
    @Published var searchPlaceholderColorHex: String
    @Published var metaFontSize: Int
    @Published var largeTypeFontSize: Int

    init(settings: SettingsStore) {
        self.settings = settings
        theme = settings.panelTheme
        fontName = settings.panelFontName
        fontSize = settings.panelFontSize
        fontWeight = settings.panelFontWeight
        iconSize = settings.panelIconSize
        visibleRows = settings.panelVisibleRows
        accentHex = settings.panelAccentHex
        textColorHex = settings.panelTextColorHex
        cornerRadius = settings.panelCornerRadius
        paddingH = settings.panelPaddingH
        paddingV = settings.panelPaddingV
        margin = settings.panelMargin
        previewFontName = settings.previewFontName
        previewFontSize = settings.previewFontSize
        previewPadding = settings.previewPadding
        previewTextColorHex = settings.previewTextColorHex
        previewBgColorHex = settings.previewBgColorHex
        searchFontName = settings.searchFontName
        searchFontSize = settings.searchFontSize
        searchTextColorHex = settings.searchTextColorHex
        searchPlaceholderColorHex = settings.searchPlaceholderColorHex
        metaFontSize = settings.metaFontSize
        largeTypeFontSize = settings.largeTypeFontSize
    }

    func syncToSettings() {
        settings.panelTheme = theme
        settings.panelFontName = fontName
        settings.panelFontSize = fontSize
        settings.panelFontWeight = fontWeight
        settings.panelIconSize = iconSize
        settings.panelVisibleRows = visibleRows
        settings.panelAccentHex = accentHex
        settings.panelTextColorHex = textColorHex
        settings.panelCornerRadius = cornerRadius
        settings.panelPaddingH = paddingH
        settings.panelPaddingV = paddingV
        settings.panelMargin = margin
        settings.previewFontName = previewFontName
        settings.previewFontSize = previewFontSize
        settings.previewPadding = previewPadding
        settings.previewTextColorHex = previewTextColorHex
        settings.previewBgColorHex = previewBgColorHex
        settings.searchFontName = searchFontName
        settings.searchFontSize = searchFontSize
        settings.searchTextColorHex = searchTextColorHex
        settings.searchPlaceholderColorHex = searchPlaceholderColorHex
        settings.metaFontSize = metaFontSize
        settings.largeTypeFontSize = largeTypeFontSize
    }
}

final class LookEditorController {
    private var overlayWindow: NSWindow?
    private var mockPanel: NSPanel?
    private var editorPanel: NSPanel?
    private var clipViewController: FloatingClipboardViewController?
    private let settings: SettingsStore
    private let repository: ClipboardRepository
    private let actionService: ClipboardActionServicing
    private let onDismiss: () -> Void
    private var escapeMonitor: Any?
    private var moveObserver: Any?
    private var isSnapping = false

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

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.frame

        let overlay = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        overlay.level = .floating
        overlay.isOpaque = false
        overlay.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.5)
        overlay.ignoresMouseEvents = true
        overlay.collectionBehavior = [.canJoinAllSpaces]

        let gridView = GridOverlayView(frame: NSRect(origin: .zero, size: screenFrame.size))
        overlay.contentView = gridView
        overlay.orderFront(nil)
        overlayWindow = overlay

        let rows = CGFloat(max(settings.panelVisibleRows, 5))
        let rowH = max(CGFloat(settings.panelFontSize) + CGFloat(settings.panelPaddingV) * 2 + 8, 28)
        let mockH = rows * rowH + 44

        let mock = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: mockH),
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
            contentRect: .zero,
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

        let visibleFrame = screen.visibleFrame
        let mockWidth: CGFloat = 460
        let mockX = visibleFrame.origin.x + (visibleFrame.width - mockWidth) * settings.panelPositionX
        let mockY = visibleFrame.origin.y + (visibleFrame.height - mockH) * settings.panelPositionY

        mock.setFrameOrigin(NSPoint(x: mockX, y: mockY))
        editorHosting.view.layoutSubtreeIfNeeded()
        let editorSize = editorHosting.view.fittingSize
        editor.setContentSize(editorSize)
        let editorY = mockY + (mockH - editorSize.height) / 2
        editor.setFrameOrigin(NSPoint(x: mockX + mockWidth + 260 + 12, y: editorY))

        mock.orderFront(nil)
        mock.addChildWindow(editor, ordered: .above)
        editor.makeKeyAndOrderFront(nil)

        mockPanel = mock
        editorPanel = editor

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: mock,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.isSnapping, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
            let frame = mock.frame
            let sf = screen.visibleFrame
            let panelW: CGFloat = 460
            let rows = CGFloat(max(self.settings.panelVisibleRows, 5))
            let rowH = max(CGFloat(self.settings.panelFontSize) + CGFloat(self.settings.panelPaddingV) * 2 + 8, 28)
            let panelH = rows * rowH + 44

            let snapThreshold: CGFloat = 12
            var x = frame.origin.x
            var y = frame.origin.y

            let gridCols: [CGFloat] = [0.25, 0.5, 0.75]
            let gridRows: [CGFloat] = [1.0 / 3, 0.5, 2.0 / 3]

            for col in gridCols {
                let guideX = sf.origin.x + sf.width * col - panelW / 2
                if abs(x - guideX) < snapThreshold { x = guideX }
            }
            for row in gridRows {
                let guideY = sf.origin.y + sf.height * row - panelH / 2
                if abs(y - guideY) < snapThreshold { y = guideY }
            }

            if x != frame.origin.x || y != frame.origin.y {
                self.isSnapping = true
                DispatchQueue.main.async {
                    mock.setFrameOrigin(NSPoint(x: x, y: y))
                    self.isSnapping = false
                }
            }

            let posX = (x - sf.origin.x) / max(sf.width - panelW, 1)
            let posY = (y - sf.origin.y) / max(sf.height - panelH, 1)
            self.settings.panelPositionX = Double(max(0, min(1, posX)))
            self.settings.panelPositionY = Double(max(0, min(1, posY)))
        }

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
        if let obs = moveObserver {
            NotificationCenter.default.removeObserver(obs)
            moveObserver = nil
        }
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        if let editor = editorPanel, let mock = mockPanel {
            mock.removeChildWindow(editor)
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
        }
    }

    private var textColor: Color {
        let theme = PanelTheme(rawValue: model.theme) ?? .dark
        switch theme {
        case .dark: return Color(nsColor: NSColor(calibratedWhite: 0.9, alpha: 1.0))
        case .light: return Color(nsColor: NSColor(calibratedWhite: 0.1, alpha: 1.0))
        }
    }

    private var shortcutColor: Color {
        let theme = PanelTheme(rawValue: model.theme) ?? .dark
        switch theme {
        case .dark: return Color(nsColor: NSColor(calibratedWhite: 0.45, alpha: 1.0))
        case .light: return Color(nsColor: NSColor(calibratedWhite: 0.5, alpha: 1.0))
        }
    }

    private var selectionColor: Color {
        Color(nsColor: NSColor(hex: model.accentHex))
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
            HStack(alignment: .top, spacing: 20) {
                listSettings
                Divider()
                panelSettings
            }

            Divider()

            paletteSection

            HStack {
                Button("Reset") { resetDefaults() }
                    .controlSize(.small)
                Spacer()
                Text("ESC")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Button("Done") { onDone() }
                    .keyboardShortcut(.return)
                    .controlSize(.regular)
            }
        }
        .padding(20)
        .frame(width: 500)
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
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .background(
                            model.theme == theme.rawValue
                                ? RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: NSColor(hex: model.accentHex)))
                                : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
        .frame(maxWidth: .infinity)
    }

    private let fontOptions = ["", "SF Mono", "Menlo", "Monaco", "Helvetica Neue", "Courier New"]
    private let fontLabels = ["System", "SF Mono", "Menlo", "Monaco", "Helvetica", "Courier"]

    private func fontPicker(selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(Array(zip(fontOptions, fontLabels)), id: \.0) { value, label in
                Text(label).tag(value)
            }
        }
        .labelsHidden()
        .frame(width: 100)
        .onChange(of: selection.wrappedValue) { _, _ in changed() }
    }

    private var listSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("List")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            settingRow("Font:") { fontPicker(selection: $model.fontName) }
            sliderRow("Size:", value: $model.fontSize, range: 10 ... 24, suffix: "px")
            sliderRow("Weight:", value: $model.fontWeight, range: 0 ... 2, labels: ["Reg", "Med", "Bold"])
            sliderRow("Icon:", value: $model.iconSize, range: 12 ... 36, suffix: "px")
            sliderRow("Rows:", value: $model.visibleRows, range: 5 ... 20, suffix: "")
            sliderRow("Pad H:", value: $model.paddingH, range: 4 ... 24, suffix: "px")
            sliderRow("Pad V:", value: $model.paddingV, range: 0 ... 12, suffix: "px")
            settingRow("Text:") { colorPickerFor(hex: $model.textColorHex) }
            settingRow("Accent:") { colorPickerFor(hex: $model.accentHex) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var panelSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Panel")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            sliderRow("Corner:", value: $model.cornerRadius, range: 0 ... 20, suffix: "px")
            sliderRow("Margin:", value: $model.margin, range: 0 ... 16, suffix: "px")

            Divider()

            Text("Preview")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            settingRow("Font:") { fontPicker(selection: $model.previewFontName) }
            sliderRow("Size:", value: $model.previewFontSize, range: 8 ... 18, suffix: "px")
            sliderRow("Padding:", value: $model.previewPadding, range: 4 ... 20, suffix: "px")
            settingRow("Text:") { colorPickerFor(hex: $model.previewTextColorHex) }
            settingRow("BG:") { colorPickerFor(hex: $model.previewBgColorHex) }

            Divider()

            Text("Search")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            settingRow("Font:") { fontPicker(selection: $model.searchFontName) }
            sliderRow("Size:", value: $model.searchFontSize, range: 10 ... 24, suffix: "px")
            settingRow("Text:") { colorPickerFor(hex: $model.searchTextColorHex) }
            settingRow("Holder:") { colorPickerFor(hex: $model.searchPlaceholderColorHex) }

            Divider()

            Text("Meta")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            sliderRow("Size:", value: $model.metaFontSize, range: 8 ... 16, suffix: "px")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct PalettePreset: Identifiable {
        let id: String
        let name: String
        let theme: Int
        let accentHex: String
        let textHex: String
        let colors: [Color]
    }

    private let palettes: [PalettePreset] = [
        PalettePreset(id: "midnight", name: "Midnight", theme: 0, accentHex: "2A9D8F", textHex: "E9C46A",
                      colors: [Color(hex: "264653"), Color(hex: "2A9D8F"), Color(hex: "E9C46A")]),
        PalettePreset(id: "ocean", name: "Ocean", theme: 0, accentHex: "669BBC", textHex: "FDF0D5",
                      colors: [Color(hex: "003049"), Color(hex: "669BBC"), Color(hex: "FDF0D5")]),
        PalettePreset(id: "sunset", name: "Sunset", theme: 0, accentHex: "E76F51", textHex: "F4A261",
                      colors: [Color(hex: "582F0E"), Color(hex: "E76F51"), Color(hex: "F4A261")]),
        PalettePreset(id: "lavender", name: "Lavender", theme: 0, accentHex: "8D99AE", textHex: "EDF2F4",
                      colors: [Color(hex: "2B2D42"), Color(hex: "8D99AE"), Color(hex: "EDF2F4")]),
        PalettePreset(id: "forest", name: "Forest", theme: 0, accentHex: "40916C", textHex: "B7E4C7",
                      colors: [Color(hex: "1B4332"), Color(hex: "40916C"), Color(hex: "B7E4C7")]),
        PalettePreset(id: "sand", name: "Sand", theme: 1, accentHex: "DDA15E", textHex: "606C38",
                      colors: [Color(hex: "FEFAE0"), Color(hex: "DDA15E"), Color(hex: "606C38")]),
        PalettePreset(id: "rose", name: "Rose", theme: 1, accentHex: "C9184A", textHex: "590D22",
                      colors: [Color(hex: "FFF0F3"), Color(hex: "C9184A"), Color(hex: "590D22")]),
        PalettePreset(id: "mono", name: "Mono", theme: 0, accentHex: "6C757D", textHex: "F8F9FA",
                      colors: [Color(hex: "212529"), Color(hex: "6C757D"), Color(hex: "F8F9FA")]),
        PalettePreset(id: "nordic", name: "Nordic", theme: 0, accentHex: "5E81AC", textHex: "ECEFF4",
                      colors: [Color(hex: "2E3440"), Color(hex: "5E81AC"), Color(hex: "ECEFF4")]),
        PalettePreset(id: "coral", name: "Coral", theme: 0, accentHex: "FF6B6B", textHex: "FFE66D",
                      colors: [Color(hex: "353535"), Color(hex: "FF6B6B"), Color(hex: "FFE66D")]),
        PalettePreset(id: "mint", name: "Mint", theme: 1, accentHex: "2EC4B6", textHex: "011627",
                      colors: [Color(hex: "F0FFF0"), Color(hex: "2EC4B6"), Color(hex: "011627")]),
        PalettePreset(id: "coffee", name: "Coffee", theme: 0, accentHex: "D4A373", textHex: "FEFAE0",
                      colors: [Color(hex: "3C2415"), Color(hex: "D4A373"), Color(hex: "FEFAE0")]),
        PalettePreset(id: "aurora", name: "Aurora", theme: 0, accentHex: "3A86FF", textHex: "E0AAFF",
                      colors: [Color(hex: "0B132B"), Color(hex: "3A86FF"), Color(hex: "8338EC")]),
        PalettePreset(id: "earth", name: "Earth", theme: 0, accentHex: "A68A64", textHex: "ECE2D0",
                      colors: [Color(hex: "2D3319"), Color(hex: "A68A64"), Color(hex: "ECE2D0")]),
        PalettePreset(id: "berry", name: "Berry", theme: 0, accentHex: "E63946", textHex: "F1FAEE",
                      colors: [Color(hex: "2B0A3D"), Color(hex: "E63946"), Color(hex: "F1FAEE")]),
        PalettePreset(id: "snow", name: "Snow", theme: 1, accentHex: "ADB5BD", textHex: "343A40",
                      colors: [Color(hex: "F8F9FA"), Color(hex: "ADB5BD"), Color(hex: "343A40")]),
        PalettePreset(id: "dusk", name: "Dusk", theme: 0, accentHex: "C77DFF", textHex: "E0AAFF",
                      colors: [Color(hex: "1A1423"), Color(hex: "C77DFF"), Color(hex: "E0AAFF")]),
        PalettePreset(id: "steel", name: "Steel", theme: 0, accentHex: "495057", textHex: "CED4DA",
                      colors: [Color(hex: "1B1B1E"), Color(hex: "495057"), Color(hex: "CED4DA")]),
        PalettePreset(id: "autumn", name: "Autumn", theme: 0, accentHex: "CB997E", textHex: "FFE8D6",
                      colors: [Color(hex: "3D2B1F"), Color(hex: "CB997E"), Color(hex: "FFE8D6")]),
        PalettePreset(id: "marine", name: "Marine", theme: 0, accentHex: "1B4965", textHex: "BEE9E8",
                      colors: [Color(hex: "0D1B2A"), Color(hex: "1B4965"), Color(hex: "BEE9E8")]),
        PalettePreset(id: "candy", name: "Candy", theme: 0, accentHex: "FF6B6B", textHex: "FFD93D",
                      colors: [Color(hex: "2D0320"), Color(hex: "FF6B6B"), Color(hex: "FFD93D")]),
    ]

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Palette")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(palettes) { preset in
                        Button {
                            model.theme = preset.theme
                            model.accentHex = preset.accentHex
                            model.textColorHex = preset.textHex
                            changed()
                        } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 2) {
                                    ForEach(0 ..< preset.colors.count, id: \.self) { i in
                                        preset.colors[i]
                                            .frame(width: 16, height: 16)
                                    }
                                }
                                .cornerRadius(4)

                                Text(preset.name)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func resetDefaults() {
        model.theme = PanelTheme.dark.rawValue
        model.fontName = ""
        model.fontSize = 15
        model.fontWeight = 0
        model.iconSize = 22
        model.visibleRows = 9
        model.accentHex = "2672B5"
        model.textColorHex = "E6E6E6"
        model.cornerRadius = 0
        model.paddingH = 12
        model.paddingV = 4
        model.margin = 0
        model.previewFontName = ""
        model.previewFontSize = 11
        model.previewPadding = 10
        model.previewTextColorHex = "D9D9D9"
        model.previewBgColorHex = "1A1A1A"
        model.searchFontName = ""
        model.searchFontSize = 16
        model.searchTextColorHex = "E6E6E6"
        model.searchPlaceholderColorHex = "666666"
        model.metaFontSize = 10
        changed()
    }

    private func colorPickerFor(hex: Binding<String>) -> some View {
        let color = Binding<Color>(
            get: { Color(nsColor: NSColor(hex: hex.wrappedValue)) },
            set: { newColor in
                let ns = NSColor(newColor)
                hex.wrappedValue = ns.hexString
                changed()
            }
        )
        return ColorPicker("", selection: color).labelsHidden()
    }

    private func settingRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 70, alignment: .trailing)
            content()
        }
    }

    private func sliderRow(_ label: String, value: Binding<Int>, range: ClosedRange<Double>, suffix: String = "", labels: [String]? = nil) -> some View {
        settingRow(label) {
            HStack(spacing: 4) {
                Slider(value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0); changed() }
                ), in: range, step: 1)
                    .frame(width: 80)
                if let labels = labels {
                    Text(labels[min(value.wrappedValue, labels.count - 1)])
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32)
                } else {
                    Text("\(value.wrappedValue)\(suffix)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32)
                }
            }
        }
    }
}

private final class GridOverlayView: NSView {
    override func draw(_: NSRect) {
        let dash: [CGFloat] = [6, 4]
        let w = bounds.width
        let h = bounds.height

        let lineColor = NSColor(calibratedWhite: 1, alpha: 0.15)
        let centerColor = NSColor(calibratedWhite: 1, alpha: 0.25)

        func drawLine(from: NSPoint, to: NSPoint, color: NSColor) {
            color.setStroke()
            let path = NSBezierPath()
            path.move(to: from)
            path.line(to: to)
            path.setLineDash(dash, count: 2, phase: 0)
            path.lineWidth = 1
            path.stroke()
        }

        for i in 1 ..< 4 {
            let x = w * CGFloat(i) / 4
            let color = i == 2 ? centerColor : lineColor
            drawLine(from: NSPoint(x: x, y: 0), to: NSPoint(x: x, y: h), color: color)
        }

        for i in 1 ..< 3 {
            let y = h * CGFloat(i) / 3
            drawLine(from: NSPoint(x: 0, y: y), to: NSPoint(x: w, y: y), color: lineColor)
        }

        let cy = h / 2
        drawLine(from: NSPoint(x: 0, y: cy), to: NSPoint(x: w, y: cy), color: centerColor)
    }
}
