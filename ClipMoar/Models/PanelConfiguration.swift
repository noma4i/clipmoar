import Cocoa

/// Typography values used by list rows inside the floating panel.
struct PanelTypographyConfiguration {
    let fontName: String
    let fontSize: CGFloat
    let fontWeight: NSFont.Weight
    let iconSize: CGFloat
    let textColor: NSColor
    let accentColor: NSColor
}

/// Search field styling is derived once from SettingsStore and reused by UI consumers.
struct PanelSearchConfiguration {
    let fontName: String
    let fontSize: CGFloat
    let textColor: NSColor
    let placeholderColor: NSColor
}

/// Preview pane styling is shared between the real panel and the look editor mock.
struct PanelPreviewConfiguration {
    let fontName: String
    let fontSize: CGFloat
    let padding: CGFloat
    let textColor: NSColor
    let backgroundColor: NSColor
    let metaFontSize: CGFloat
    let metaFontName: String
    let metaTextColor: NSColor
    let metaBgColor: NSColor
}

struct PanelBorderConfiguration {
    let borderColor: NSColor?
    let borderWidth: CGFloat
    let shadowEnabled: Bool
    let shadowColor: NSColor
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
}

/// Layout values keep all panel sizing math in one place.
struct PanelLayoutConfiguration {
    let listWidth: CGFloat
    let previewWidth: CGFloat
    let visibleRows: Int
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cornerRadius: CGFloat
    let margin: CGFloat
    let rowHeight: CGFloat
    let searchFieldHeight: CGFloat

    var panelHeight: CGFloat {
        CGFloat(visibleRows) * rowHeight + searchFieldHeight + 12
    }

    var availableTextWidth: CGFloat {
        listWidth - 80
    }
}

/// PanelConfiguration is the single snapshot consumed by the panel UI.
struct PanelConfiguration {
    let theme: PanelTheme
    let backgroundColor: NSColor
    let typography: PanelTypographyConfiguration
    let search: PanelSearchConfiguration
    let preview: PanelPreviewConfiguration
    let layout: PanelLayoutConfiguration
    let border: PanelBorderConfiguration
    let largeTypeFontSize: CGFloat?
}

extension SettingsStore {
    func panelConfiguration() -> PanelConfiguration {
        let theme = PanelTheme(rawValue: panelTheme) ?? .dark
        let fontWeight: NSFont.Weight
        switch panelFontWeight {
        case 1: fontWeight = .medium
        case 2: fontWeight = .bold
        default: fontWeight = .regular
        }

        let panelTextColor = panelTextColorHex.isEmpty
            ? (theme == .dark
                ? NSColor(calibratedWhite: 0.9, alpha: 1.0)
                : NSColor(calibratedWhite: 0.1, alpha: 1.0))
            : NSColor(hex: panelTextColorHex)

        let searchTextColor = searchTextColorHex.isEmpty ? panelTextColor : NSColor(hex: searchTextColorHex)
        let placeholderColor = searchPlaceholderColorHex.isEmpty
            ? NSColor(calibratedWhite: 0.4, alpha: 1.0)
            : NSColor(hex: searchPlaceholderColorHex)

        let previewTextColor = previewTextColorHex.isEmpty
            ? (theme == .dark
                ? NSColor(calibratedWhite: 0.85, alpha: 1.0)
                : NSColor(calibratedWhite: 0.15, alpha: 1.0))
            : NSColor(hex: previewTextColorHex)

        let previewBackground = previewBgColorHex.isEmpty
            ? (theme == .dark
                ? NSColor(calibratedWhite: 0.10, alpha: 1.0)
                : NSColor(calibratedWhite: 0.92, alpha: 1.0))
            : NSColor(hex: previewBgColorHex)

        let searchFontSize = CGFloat(max(searchFontSize, 10))
        let verticalPadding = CGFloat(max(panelPaddingV, 0))
        let listFontSize = CGFloat(max(panelFontSize, 10))
        let visibleRows = max(panelVisibleRows, 5)
        let rowHeight = max(listFontSize + verticalPadding * 2 + 8, 28)

        return PanelConfiguration(
            theme: theme,
            backgroundColor: theme == .dark
                ? NSColor(calibratedWhite: 0.13, alpha: 1.0)
                : NSColor(calibratedWhite: 0.95, alpha: 1.0),
            typography: PanelTypographyConfiguration(
                fontName: panelFontName,
                fontSize: listFontSize,
                fontWeight: fontWeight,
                iconSize: CGFloat(max(panelIconSize, 12)),
                textColor: panelTextColor,
                accentColor: NSColor(hex: panelAccentHex)
            ),
            search: PanelSearchConfiguration(
                fontName: searchFontName,
                fontSize: searchFontSize,
                textColor: searchTextColor,
                placeholderColor: placeholderColor
            ),
            preview: PanelPreviewConfiguration(
                fontName: previewFontName,
                fontSize: CGFloat(max(previewFontSize, 8)),
                padding: CGFloat(max(previewPadding, 0)),
                textColor: previewTextColor,
                backgroundColor: previewBackground,
                metaFontSize: CGFloat(max(metaFontSize, 8)),
                metaFontName: metaFontName,
                metaTextColor: NSColor(hex: metaTextColorHex.isEmpty ? "B3B3B3" : metaTextColorHex),
                metaBgColor: NSColor(hex: metaBgColorHex.isEmpty ? "000000" : metaBgColorHex)
            ),
            layout: PanelLayoutConfiguration(
                listWidth: 460,
                previewWidth: 260,
                visibleRows: visibleRows,
                horizontalPadding: CGFloat(max(panelPaddingH, 4)),
                verticalPadding: verticalPadding,
                cornerRadius: CGFloat(max(panelCornerRadius, 0)),
                margin: CGFloat(max(panelMargin, 0)),
                rowHeight: rowHeight,
                searchFieldHeight: rowHeight
            ),
            border: PanelBorderConfiguration(
                borderColor: panelBorderColorHex.isEmpty ? nil : NSColor(hex: panelBorderColorHex),
                borderWidth: CGFloat(max(panelBorderWidth, 0)),
                shadowEnabled: panelShadowEnabled,
                shadowColor: NSColor(hex: panelShadowColorHex.isEmpty ? "000000" : panelShadowColorHex),
                shadowRadius: CGFloat(max(panelShadowRadius, 0)),
                shadowOffset: CGSize(width: CGFloat(panelShadowOffsetX), height: CGFloat(panelShadowOffsetY))
            ),
            largeTypeFontSize: largeTypeFontSize > 0 ? CGFloat(largeTypeFontSize) : nil
        )
    }
}
