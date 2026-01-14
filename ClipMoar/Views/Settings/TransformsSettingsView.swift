import SwiftUI

struct TransformsSettingsView: View {
    @State private var selectedType: ClipboardTransformType = .trimWhitespace
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var regexPattern = ""
    @State private var regexReplacement = ""

    private let engine = ClipboardRuleEngine()

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            transformList

            Divider()

            playground
        }
        .padding(24)
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
    }

    private func moveSelection(by offset: Int) {
        let all = ClipboardTransformType.allCases
        guard let idx = all.firstIndex(of: selectedType) else { return }
        let newIdx = min(max(idx + offset, 0), all.count - 1)
        selectedType = all[newIdx]
        runTransform()
    }

    private var transformList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transforms").font(.system(size: 13, weight: .semibold))

            ForEach(ClipboardTransformType.allCases, id: \.self) { type in
                Button {
                    selectedType = type
                    runTransform()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .frame(width: 16)
                            .foregroundColor(selectedType == type ? .accentColor : .secondary)
                        Text(type.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(selectedType == type ? .primary : .secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedType == type ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 220)
    }

    private var playground: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedType.displayName)
                .font(.system(size: 13, weight: .semibold))

            Text(descriptionFor(selectedType))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            regexFields
                .opacity(selectedType == .regexReplace ? 1 : 0)
                .frame(height: selectedType == .regexReplace ? nil : 0)
                .clipped()

            Text("Input").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)

            TextField("Paste text here...", text: $inputText, axis: .vertical)
                .lineLimit(5 ... 10)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(6)
                .frame(height: 100, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                .onChange(of: inputText) { _ in runTransform() }

            HStack {
                Text("Output").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                statusBadge
            }
            .frame(height: 16)

            ScrollView {
                Text(outputText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
            }
            .frame(height: 100)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Button("Paste from Clipboard") {
                    if let str = NSPasteboard.general.string(forType: .string) {
                        inputText = str
                    }
                }
                .controlSize(.small)

                Button("Clear") {
                    inputText = ""
                    outputText = ""
                }
                .controlSize(.small)

                Spacer()

                Button("Copy Output") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(outputText, forType: .string)
                }
                .controlSize(.small)
                .disabled(outputText.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if outputText != inputText && !inputText.isEmpty {
            Text("Modified")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green))
        } else {
            Text(inputText.isEmpty ? "" : "No change")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private var regexFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Pattern:")
                    .font(.system(size: 11))
                    .frame(width: 65, alignment: .trailing)
                TextField("Regular expression", text: $regexPattern)
                    .font(.system(size: 11, design: .monospaced))
                    .onChange(of: regexPattern) { _ in runTransform() }
            }
            HStack(spacing: 8) {
                Text("Replace:")
                    .font(.system(size: 11))
                    .frame(width: 65, alignment: .trailing)
                TextField("Replacement", text: $regexReplacement)
                    .font(.system(size: 11, design: .monospaced))
                    .onChange(of: regexReplacement) { _ in runTransform() }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
    }

    private func runTransform() {
        guard !inputText.isEmpty else {
            outputText = ""
            return
        }

        let transform = ClipboardTransform(
            type: selectedType,
            pattern: regexPattern,
            replacement: regexReplacement
        )

        let rule = ClipboardRule(
            name: "Test",
            transforms: [transform]
        )

        let testEngine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]))
        let result = testEngine.apply(to: inputText)
        outputText = result.text
    }

    private func descriptionFor(_ type: ClipboardTransformType) -> String {
        switch type {
        case .trimWhitespace:
            return "Removes leading and trailing whitespace and newlines."
        case .flattenMultiline:
            return "Joins multi-line shell commands (with \\, |, &&) into a single line. Does not touch regular text."
        case .stripShellPrompts:
            return "Removes $ and # prompts from copied terminal commands. Only strips if the text after the prompt looks like a real command."
        case .removeBoxDrawing:
            return "Removes box-drawing characters (│, ┃, etc.) often copied from terminal tables and UI."
        case .repairWrappedURL:
            return "Repairs URLs broken across multiple lines back into a single valid URL."
        case .quotePathsWithSpaces:
            return "Wraps file paths containing spaces in double quotes for shell use."
        case .regexReplace:
            return "Replace text matching a regular expression pattern with a replacement string. Use $1, $2 for capture groups."
        }
    }
}

final class InMemoryRuleStore: ClipboardRuleStore {
    var rules: [ClipboardRule]

    init(rules: [ClipboardRule]) {
        self.rules = rules
    }

    func save() {}
    func load() {}
}
