import SwiftUI

struct LookAndFeelSettingsView: View {
    let settings: SettingsStore
    @State private var panelFontSize: Int
    @State private var panelTheme: Int
    @State private var accentColor: Int
    @State private var largeTypeFontSize: Int

    init(settings: SettingsStore) {
        self.settings = settings
        _panelFontSize = State(initialValue: settings.panelFontSize)
        _panelTheme = State(initialValue: settings.panelTheme)
        _accentColor = State(initialValue: settings.panelAccentColor)
        _largeTypeFontSize = State(initialValue: settings.largeTypeFontSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Panel").font(.system(size: 13, weight: .semibold))

            HStack {
                Text("Theme:")
                    .frame(width: 80, alignment: .trailing)
                Picker("", selection: $panelTheme) {
                    ForEach(PanelTheme.allCases, id: \.rawValue) { t in
                        Text(t.title).tag(t.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: panelTheme) { _, val in settings.panelTheme = val }
            }

            HStack {
                Text("Font size:")
                    .frame(width: 80, alignment: .trailing)
                Picker("", selection: $panelFontSize) {
                    ForEach(PanelFontSize.allCases, id: \.rawValue) { s in
                        Text(s.title).tag(s.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: panelFontSize) { _, val in settings.panelFontSize = val }
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
                                Circle().stroke(Color.white, lineWidth: accentColor == c.rawValue ? 2 : 0)
                            )
                            .onTapGesture {
                                accentColor = c.rawValue
                                settings.panelAccentColor = c.rawValue
                            }
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 16) {
                panelPreview
                    .frame(width: 240, height: 160)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Large Type").font(.system(size: 13, weight: .semibold))

                    HStack {
                        Text("Font size:")
                            .frame(width: 80, alignment: .trailing)
                        Slider(value: Binding(
                            get: { Double(largeTypeFontSize) },
                            set: { largeTypeFontSize = Int($0); settings.largeTypeFontSize = Int($0) }
                        ), in: 24 ... 120, step: 4)
                            .frame(width: 150)
                        Text("\(largeTypeFontSize)pt")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 40)
                    }

                    largeTypePreview
                        .frame(height: 100)
                }
            }
        }
        .padding(24)
    }

    private var previewThemeAppearance: NSAppearance? {
        let theme = PanelTheme(rawValue: panelTheme) ?? .dark
        switch theme {
        case .dark: return NSAppearance(named: .darkAqua)
        case .light: return NSAppearance(named: .aqua)
        case .system: return nil
        }
    }

    private var previewBgColor: Color {
        let theme = PanelTheme(rawValue: panelTheme) ?? .dark
        switch theme {
        case .dark: return Color(nsColor: NSColor(calibratedWhite: 0.13, alpha: 1.0))
        case .light: return Color(nsColor: NSColor(calibratedWhite: 0.95, alpha: 1.0))
        case .system: return Color(nsColor: NSColor.windowBackgroundColor)
        }
    }

    private var previewTextColor: Color {
        let theme = PanelTheme(rawValue: panelTheme) ?? .dark
        switch theme {
        case .dark: return Color(nsColor: NSColor(calibratedWhite: 0.9, alpha: 1.0))
        case .light: return Color(nsColor: NSColor(calibratedWhite: 0.1, alpha: 1.0))
        case .system: return .primary
        }
    }

    private var previewAccent: Color {
        Color(nsColor: (AccentColor(rawValue: accentColor) ?? .blue).color)
    }

    private struct PreviewRow: Identifiable {
        let id: Int
        let text: String
        let icon: String
        let isSelected: Bool
    }

    private var previewRows: [PreviewRow] {
        [
            PreviewRow(id: 0, text: "Hello World", icon: "doc.on.clipboard", isSelected: true),
            PreviewRow(id: 1, text: "Screenshot.png", icon: "photo", isSelected: false),
            PreviewRow(id: 2, text: "git commit -m \"fix\"", icon: "terminal", isSelected: false),
            PreviewRow(id: 3, text: "/usr/local/bin/app", icon: "folder", isSelected: false),
            PreviewRow(id: 4, text: "https://example.com", icon: "link", isSelected: false),
        ]
    }

    private var previewSelectionColor: Color {
        let accent = AccentColor(rawValue: accentColor) ?? .blue
        return Color(nsColor: accent.color).opacity(0.85)
    }

    private var previewShortcutColor: Color {
        let theme = PanelTheme(rawValue: panelTheme) ?? .dark
        switch theme {
        case .dark: return Color(nsColor: NSColor(calibratedWhite: 0.45, alpha: 1.0))
        case .light: return Color(nsColor: NSColor(calibratedWhite: 0.5, alpha: 1.0))
        case .system: return .secondary
        }
    }

    private var panelPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: CGFloat(panelFontSize) - 4))
                    .foregroundColor(previewTextColor.opacity(0.3))
                Text("Type to search...")
                    .font(.system(size: CGFloat(panelFontSize) - 2))
                    .foregroundColor(previewTextColor.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Rectangle()
                .fill(previewTextColor.opacity(0.15))
                .frame(height: 1)

            ForEach(previewRows) { row in
                HStack(spacing: 8) {
                    Image(systemName: row.icon)
                        .font(.system(size: CGFloat(panelFontSize) - 4))
                        .frame(width: 18)
                        .foregroundColor(row.isSelected ? .white : previewTextColor.opacity(0.7))

                    Text(row.text)
                        .font(.system(size: CGFloat(panelFontSize)))
                        .foregroundColor(row.isSelected ? .white : previewTextColor)
                        .lineLimit(1)

                    Spacer()

                    Text("\u{2318}\(row.id + 1)")
                        .font(.system(size: CGFloat(panelFontSize) - 4, design: .monospaced))
                        .foregroundColor(row.isSelected ? .white.opacity(0.6) : previewShortcutColor)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(row.isSelected ? previewSelectionColor : Color.clear)
            }

            Spacer()
        }
        .background(previewBgColor)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
    }

    private var largeTypePreview: some View {
        ZStack {
            Color.black.opacity(0.6)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: NSColor(white: 0.08, alpha: 0.9)))
                .padding(12)
            Text("ClipMoar")
                .font(.system(size: CGFloat(largeTypeFontSize) * 0.5, weight: .medium))
                .foregroundColor(.white)
        }
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
    }
}
