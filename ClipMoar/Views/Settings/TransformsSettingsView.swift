import SwiftUI

struct TransformsSettingsView: View {
    @State private var selectedType: ClipboardTransformType = .trimWhitespace
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var selectedRegexId: UUID?
    @StateObject private var regexStore: RegexStore

    init(regexStore: RegexStore = RegexStore()) {
        _regexStore = StateObject(wrappedValue: regexStore)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            transformList
            Divider()
            playground
        }
        .padding(24)
    }

    private var transformList: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            Spacer()
        }
        .frame(width: 200)
    }

    private var playground: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedType.displayName)
                .font(.system(size: 13, weight: .semibold))

            Text(descriptionFor(selectedType))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(height: 30, alignment: .topLeading)

            regexFields
                .frame(height: 50)
                .opacity(selectedType == .regexReplace ? 1 : 0)

            Text("Input").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)

            TextField("Paste text here...", text: $inputText, axis: .vertical)
                .lineLimit(4 ... 8)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(6)
                .frame(height: 80, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                .onChange(of: inputText) { runTransform() }

            HStack {
                Text("Output").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text(statusText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, statusText.isEmpty ? 0 : 6)
                    .padding(.vertical, statusText.isEmpty ? 0 : 2)
                    .background(statusText == "Modified" ? Capsule().fill(Color.green) : nil)
            }
            .frame(height: 16)

            ScrollView {
                Text(outputText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
            }
            .frame(height: 80)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Button("Paste") {
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
        .frame(width: 320)
    }

    private var statusText: String {
        guard !inputText.isEmpty else { return "" }
        return outputText != inputText ? "Modified" : "No change"
    }

    private var statusColor: Color {
        statusText == "Modified" ? .white : .secondary
    }

    private var selectedRegex: SavedRegex? {
        guard let id = selectedRegexId else { return nil }
        return regexStore.patterns.first { $0.id == id }
    }

    private var regexFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Regex:")
                    .font(.system(size: 11))
                    .frame(width: 60, alignment: .trailing)
                Picker("", selection: $selectedRegexId) {
                    Text("Select...").tag(nil as UUID?)
                    ForEach(regexStore.patterns) { p in
                        Text(p.name).tag(p.id as UUID?)
                    }
                }
                .labelsHidden()
                .onChange(of: selectedRegexId) { runTransform() }
            }
            if let r = selectedRegex {
                Text("\(r.pattern) -> \(r.replacement)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 68)
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

        let regex = selectedRegex
        let transform = ClipboardTransform(
            type: selectedType,
            pattern: regex?.pattern ?? "",
            replacement: regex?.replacement ?? ""
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
            return "Joins multi-line shell commands into a single line."
        case .stripShellPrompts:
            return "Removes $ and # prompts from terminal commands."
        case .removeBoxDrawing:
            return "Removes box-drawing characters from terminal output."
        case .repairWrappedURL:
            return "Repairs URLs broken across multiple lines."
        case .quotePathsWithSpaces:
            return "Wraps file paths with spaces in double quotes."
        case .regexReplace:
            return "Replace text matching a regex pattern."
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
