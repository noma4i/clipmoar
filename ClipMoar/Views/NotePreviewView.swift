import Cocoa
import CompanionKit

private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

final class NoteMarkBadge: NSView {
    static let side: CGFloat = 18
    private let ring = CALayer()
    private let digit = CATextLayer()

    init(number: Int) {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.side, height: Self.side))
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        ring.frame = bounds
        ring.backgroundColor = NSColor.white.cgColor
        ring.cornerRadius = 5
        ring.borderWidth = 1
        ring.borderColor = NSColor(calibratedWhite: 0.1, alpha: 0.7).cgColor
        let lineHeight = ceil(font.ascender - font.descender)
        digit.frame = CGRect(x: 0, y: (Self.side - lineHeight) / 2, width: Self.side, height: lineHeight)
        digit.string = NSAttributedString(string: "\(number)", attributes: [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: { let style = NSMutableParagraphStyle(); style.alignment = .center; return style }(),
        ])
        digit.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        ring.addSublayer(digit)
        layer?.addSublayer(ring)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
        ])
    }

    required init?(coder _: NSCoder) {
        nil
    }

    func pulse() {
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1, 1.15, 1]
        animation.keyTimes = [0, 0.5, 1]
        animation.duration = 0.6
        ring.add(animation, forKey: "pulse")
    }

    func stopPulse() {
        ring.removeAnimation(forKey: "pulse")
    }
}

private final class NotePhraseRow: NSView {
    static let pillWidth: CGFloat = 52
    private let highlight = CALayer()
    private let badges: [NoteMarkBadge]
    private let accent: NSColor

    init(time: Double?, text: String, marks: [Int], configuration: PanelConfiguration, font: NSFont) {
        accent = configuration.typography.accentColor
        badges = marks.map { NoteMarkBadge(number: $0) }
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        highlight.cornerRadius = 6
        layer?.addSublayer(highlight)

        let pill = NSView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 9
        pill.layer?.backgroundColor = accent.withAlphaComponent(0.3).cgColor
        let timeLabel = NSTextField(labelWithString: time.map(Self.format) ?? "")
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .monospacedDigitSystemFont(ofSize: max(font.pointSize - 3, 10), weight: .medium)
        timeLabel.textColor = configuration.preview.textColor
        timeLabel.alignment = .center
        pill.addSubview(timeLabel)
        pill.isHidden = time == nil

        let label = NSTextField(wrappingLabelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.textColor = configuration.preview.textColor
        label.drawsBackground = false
        label.isSelectable = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: badges)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(pill)
        addSubview(label)
        addSubview(stack)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            pill.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            pill.widthAnchor.constraint(equalToConstant: Self.pillWidth),
            pill.heightAnchor.constraint(equalToConstant: 18),
            timeLabel.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: pill.centerYAnchor),

            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            label.leadingAnchor.constraint(equalTo: pill.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: stack.leadingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
        ])
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        highlight.frame = bounds
    }

    static func format(_ value: Double) -> String {
        let seconds = max(0, Int(value))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func setActive(_ active: Bool) {
        highlight.backgroundColor = active ? accent.withAlphaComponent(0.55).cgColor : NSColor.clear.cgColor
        for badge in badges {
            active ? badge.pulse() : badge.stopPulse()
        }
    }
}

final class NotePreviewView: NSView {
    private let imageView = NSImageView()
    private let scrollView = NSScrollView()
    private let stack = NSStackView()
    private var rows: [NotePhraseRow] = []
    private var starts: [Double] = []
    private var current: NotePreview?
    private var schedule: NoteAnimationSchedule?
    private var timer: Timer?
    private var startedAt = Date()
    private var activeRow: Int?
    private var shownWithReduceMotion = false
    private var occlusionObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = document

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        document.addSubview(stack)

        addSubview(imageView)
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.4),

            scrollView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])
    }

    required init?(coder _: NSCoder) {
        nil
    }

    deinit {
        timer?.invalidate()
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
    }

    func show(_ preview: NotePreview, configuration: PanelConfiguration, reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
        if preview == current, reduceMotion == shownWithReduceMotion {
            if schedule != nil, timer == nil { startTimer() }
            return
        }
        stop()
        current = preview
        shownWithReduceMotion = reduceMotion
        imageView.image = preview.annotated.flatMap { NSImage(contentsOf: $0) }
        imageView.isHidden = imageView.image == nil
        rebuildRows(preview.note, configuration: configuration)
        schedule = NoteAnimationSchedule(starts: starts, reduceMotion: reduceMotion)
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        setActive(nil)
    }

    private func rebuildRows(_ note: Note, configuration: PanelConfiguration) {
        rows.forEach { $0.removeFromSuperview() }
        rows = []
        starts = []
        let name = configuration.preview.fontName
        let size = configuration.preview.fontSize
        let font = (name.isEmpty ? nil : NSFont(name: name, size: size)) ?? .systemFont(ofSize: size)
        func add(time: Double?, text: String, marks: [Int]) {
            let row = NotePhraseRow(time: time, text: text, marks: marks, configuration: configuration, font: font)
            stack.addArrangedSubview(row)
            row.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
            row.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
            rows.append(row)
        }
        var used = Set<Int>()
        for phrase in note.phrases {
            add(time: phrase.start, text: phrase.text, marks: phrase.marks)
            starts.append(phrase.start)
            used.formUnion(phrase.marks)
        }
        for mark in note.marks where !used.contains(mark.number) {
            add(time: mark.start, text: mark.on.map { "in \($0)" } ?? "at \(mark.x),\(mark.y)", marks: [mark.number])
        }
    }

    private func startTimer() {
        guard schedule != nil else { return }
        startedAt = Date()
        tick()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let schedule else { return }
        let index = schedule.activeIndex(at: Date().timeIntervalSince(startedAt))
        guard index != activeRow else { return }
        setActive(index)
    }

    private func setActive(_ index: Int?) {
        if let activeRow, rows.indices.contains(activeRow) { rows[activeRow].setActive(false) }
        activeRow = index
        if let index, rows.indices.contains(index) {
            rows[index].setActive(true)
            rows[index].scrollToVisible(rows[index].bounds)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
        occlusionObserver = nil
        guard let window else {
            stop()
            return
        }
        occlusionObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
            guard let self, let window = self.window else { return }
            if window.occlusionState.contains(.visible) {
                if self.schedule != nil, self.timer == nil, !self.isHidden { self.startTimer() }
            } else {
                self.stop()
            }
        }
    }
}
