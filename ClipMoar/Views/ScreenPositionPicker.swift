import Cocoa

final class ScreenPositionPicker: NSView {
    var positionX: Double = 0.5 { didSet { needsDisplay = true } }
    var positionY: Double = 0.65 { didSet { needsDisplay = true } }
    var onChange: ((Double, Double) -> Void)?

    private let miniWindowRatio: CGFloat = 0.2
    private let gridLines = 4

    override var isFlipped: Bool { false }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let screenRect = bounds.insetBy(dx: 2, dy: 2)

        NSColor(calibratedWhite: 0.18, alpha: 1.0).setFill()
        let bg = NSBezierPath(roundedRect: screenRect, xRadius: 4, yRadius: 4)
        bg.fill()

        drawGrid(in: screenRect)

        NSColor(calibratedWhite: 0.35, alpha: 1.0).setStroke()
        bg.lineWidth = 1
        bg.stroke()

        drawMiniWindow(in: screenRect)
    }

    private func drawGrid(in rect: NSRect) {
        NSColor(calibratedWhite: 0.25, alpha: 0.6).setStroke()
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 0.5

        let dashPattern: [CGFloat] = [2, 3]
        gridPath.setLineDash(dashPattern, count: 2, phase: 0)

        for i in 1..<gridLines {
            let x = rect.origin.x + rect.width * CGFloat(i) / CGFloat(gridLines)
            gridPath.move(to: NSPoint(x: x, y: rect.origin.y))
            gridPath.line(to: NSPoint(x: x, y: rect.maxY))
        }

        for i in 1..<gridLines {
            let y = rect.origin.y + rect.height * CGFloat(i) / CGFloat(gridLines)
            gridPath.move(to: NSPoint(x: rect.origin.x, y: y))
            gridPath.line(to: NSPoint(x: rect.maxX, y: y))
        }

        gridPath.stroke()
    }

    private func drawMiniWindow(in screenRect: NSRect) {
        let winW = screenRect.width * miniWindowRatio
        let winH = winW * 0.75
        let cx = screenRect.origin.x + screenRect.width * positionX
        let cy = screenRect.origin.y + screenRect.height * positionY
        let winRect = NSRect(
            x: cx - winW / 2,
            y: cy - winH / 2,
            width: winW,
            height: winH
        ).intersection(screenRect)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()

        NSColor(calibratedWhite: 0.13, alpha: 0.95).setFill()
        let winPath = NSBezierPath(roundedRect: winRect, xRadius: 2, yRadius: 2)
        winPath.fill()

        NSShadow().set()

        NSColor.controlAccentColor.withAlphaComponent(0.8).setStroke()
        winPath.lineWidth = 1.5
        winPath.stroke()

        let titleBarH: CGFloat = 3
        let titleBar = NSRect(
            x: winRect.origin.x + 1,
            y: winRect.maxY - titleBarH - 1,
            width: winRect.width - 2,
            height: titleBarH
        )
        NSColor.controlAccentColor.withAlphaComponent(0.4).setFill()
        NSBezierPath(rect: titleBar).fill()

        let lineY = winRect.origin.y + winRect.height * 0.5
        let lineInset: CGFloat = 4
        NSColor(calibratedWhite: 0.35, alpha: 0.6).setStroke()
        let contentLine = NSBezierPath()
        contentLine.lineWidth = 1
        for i in 0..<3 {
            let y = lineY + CGFloat(i) * 4
            if y < winRect.maxY - titleBarH - 2 {
                contentLine.move(to: NSPoint(x: winRect.origin.x + lineInset, y: y))
                contentLine.line(to: NSPoint(x: winRect.maxX - lineInset, y: y))
            }
        }
        contentLine.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        updatePosition(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updatePosition(with: event)
    }

    private func updatePosition(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let screenRect = bounds.insetBy(dx: 2, dy: 2)
        let rawX = (loc.x - screenRect.origin.x) / screenRect.width
        let rawY = (loc.y - screenRect.origin.y) / screenRect.height
        positionX = max(0.05, min(0.95, snapToGrid(rawX)))
        positionY = max(0.05, min(0.95, snapToGrid(rawY)))
        onChange?(positionX, positionY)
    }

    private func snapToGrid(_ value: Double) -> Double {
        let step = 1.0 / Double(gridLines)
        let snapped = (value / step).rounded() * step
        let threshold = 0.03
        return abs(value - snapped) < threshold ? snapped : value
    }
}
