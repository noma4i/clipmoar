import Cocoa
import SwiftUI

struct OverlayTransformOption {
    let name: String
    let icon: String
    let transformed: String
}

final class TransformOverlayController {
    private let ruleEngine: ClipboardRuleEngine
    private let settings: SettingsStore
    private let clipboardService: ClipboardService
    private let presetStore: PresetStore

    private var overlayWindow: NSWindow?
    private(set) var isActive = false
    private var selectedIndex = 0
    private var options: [OverlayTransformOption] = []
    private var originalText = ""
    private var targetApp: NSRunningApplication?
    private var hostingView: NSHostingView<OverlayContentView>?

    init(
        ruleEngine: ClipboardRuleEngine,
        settings: SettingsStore,
        clipboardService: ClipboardService,
        presetStore: PresetStore
    ) {
        self.ruleEngine = ruleEngine
        self.settings = settings
        self.clipboardService = clipboardService
        self.presetStore = presetStore
    }

    var transformKeyCode: Int {
        settings.transformHotkeyKeyCode
    }

    var transformModifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(settings.transformHotkeyModifiers))
            .intersection([.command, .option, .control, .shift])
    }

    func show() {
        guard !isActive else { return }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        originalText = text
        targetApp = NSWorkspace.shared.frontmostApplication

        presetStore.load()
        var result: [OverlayTransformOption] = []

        for preset in presetStore.presets where !preset.transformTypes.isEmpty && preset.isQuick {
            let rule = ClipboardRule(name: preset.name, transforms: preset.transformTypes.map { ClipboardTransform(type: $0) })
            let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]))
            let transformed = engine.apply(to: text).text
            result.append(OverlayTransformOption(name: preset.name, icon: preset.icon, transformed: transformed))
        }

        guard !result.isEmpty else { return }
        options = result
        isActive = true
        selectedIndex = 0

        showWindow()
    }

    func selectNext() {
        guard isActive, !options.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % options.count
        updateView()
    }

    func dismiss(paste: Bool) {
        guard isActive else { return }

        if paste, !options.isEmpty {
            let transformed = options[selectedIndex].transformed
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(transformed, forType: .string)
            pasteboard.setData(Data(), forType: ClipboardActionService.markerType)

            let pasteDelay = TimeInterval(settings.transformPasteDelay) / 1000.0
            let restoreDelay = TimeInterval(settings.transformRestoreDelay) / 1000.0
            targetApp?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
                guard let source = CGEventSource(stateID: .hidSystemState),
                      let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                else { return }
                down.flags = .maskCommand
                up.flags = .maskCommand
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }

            let original = originalText
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                pasteboard.clearContents()
                pasteboard.setString(original, forType: .string)
                pasteboard.setData(Data(), forType: ClipboardActionService.markerType)
            }
        }

        hideWindow()
        isActive = false
        options = []
        originalText = ""
        targetApp = nil
    }

    private func showWindow() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let width: CGFloat = 580
        let height: CGFloat = 400
        let x = screen.frame.midX - width / 2
        let y = screen.frame.midY - height / 2

        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = OverlayContentView(options: options, selectedIndex: selectedIndex, shortcutHint: shortcutString)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        window.contentView = hosting
        hostingView = hosting
        window.orderFront(nil)
        overlayWindow = window
    }

    private var shortcutString: String {
        let kc = transformKeyCode
        let mods = transformModifiers
        return KeyboardShortcutFormatter.string(for: kc, modifiers: mods)
    }

    private func updateView() {
        hostingView?.rootView = OverlayContentView(options: options, selectedIndex: selectedIndex, shortcutHint: shortcutString)
    }

    private func hideWindow() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        hostingView = nil
    }
}

struct OverlayContentView: View {
    let options: [OverlayTransformOption]
    let selectedIndex: Int
    let shortcutHint: String

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 2) {
                            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                                HStack(spacing: 8) {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 11))
                                        .foregroundColor(index == selectedIndex ? .white : .white.opacity(0.5))
                                        .frame(width: 16)
                                    Text(option.name)
                                        .font(.system(size: 12))
                                        .foregroundColor(index == selectedIndex ? .white : .white.opacity(0.7))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(index == selectedIndex ? Color.accentColor : Color.clear)
                                )
                                .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .frame(width: 200)
                    .onChange(of: selectedIndex) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(selectedIndex, anchor: .center)
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 6) {
                    if selectedIndex < options.count {
                        Text(options[selectedIndex].name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 10)
                            .padding(.horizontal, 12)
                    }

                    ScrollView {
                        Text(selectedIndex < options.count ? options[selectedIndex].transformed : "")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2))
            }

            HStack(spacing: 4) {
                Text(shortcutHint)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Text("to cycle")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("Release to paste")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: NSColor(calibratedWhite: 0.15, alpha: 1)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
