import SwiftUI

private struct TransformInfo: Decodable {
    let description: String
    let exampleInput: String
    let exampleOutput: String
}

private let transformCatalog: [String: TransformInfo] = {
    if let url = Bundle.main.url(forResource: "TransformCatalog", withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let catalog = try? JSONDecoder().decode([String: TransformInfo].self, from: data)
    {
        return catalog
    }

    guard let path = ProcessInfo.processInfo.environment["PWD"] ?? Optional(""),
          let data = try? Data(contentsOf: URL(fileURLWithPath: path).appendingPathComponent("ClipMoar/Resources/TransformCatalog.json")),
          let catalog = try? JSONDecoder().decode([String: TransformInfo].self, from: data)
    else { return [:] }
    return catalog
}()

struct TransformsSettingsView: View {
    @State private var selectedType: ClipboardTransformType = .trimWhitespace
    @State private var inputText = ""
    @State private var outputText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            transformList
            Divider()
            playground
        }
        .padding(24)
    }

    private var transformList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(ClipboardTransformType.grouped, id: \.0) { group, types in
                    Text(group.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.top, group == .cleanup ? 0 : 8)
                        .padding(.bottom, 2)

                    ForEach(types, id: \.self) { type in
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
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedType == type ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 200)
    }

    private var info: TransformInfo? {
        transformCatalog[selectedType.rawValue]
    }

    private var playground: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedType.displayName)
                .font(.system(size: 13, weight: .semibold))

            Text(info?.description ?? "")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(height: 30, alignment: .topLeading)

            Text("Input").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)

            numberedEditor(text: $inputText, editable: true)
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

            numberedEditor(text: .constant(outputText), editable: false)

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

            Divider()

            exampleView
        }
        .frame(width: 320)
    }

    private func numberedEditor(text: Binding<String>, editable: Bool) -> some View {
        let lines = text.wrappedValue.isEmpty ? [""] : text.wrappedValue.components(separatedBy: "\n")
        let gutterWidth: CGFloat = max(20, CGFloat(String(lines.count).count) * 8 + 8)

        return ScrollView {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, _ in
                        Text("\(idx + 1)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                            .frame(height: 15)
                    }
                }
                .frame(width: gutterWidth)
                .padding(.trailing, 4)

                if editable {
                    TextField("Paste text here...", text: text, axis: .vertical)
                        .lineLimit(4 ... 8)
                        .font(.system(size: 11, design: .monospaced))
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                } else {
                    Text(text.wrappedValue)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(height: 80)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
    }

    private var statusText: String {
        guard !inputText.isEmpty else { return "" }
        return outputText != inputText ? "Modified" : "No change"
    }

    private var statusColor: Color {
        statusText == "Modified" ? .white : .secondary
    }

    private func runTransform() {
        guard !inputText.isEmpty else {
            outputText = ""
            return
        }

        let transform = ClipboardTransform(
            type: selectedType,
            pattern: "",
            replacement: ""
        )

        let rule = ClipboardRule(
            name: "Test",
            transforms: [transform]
        )

        let testEngine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]))
        let result = testEngine.apply(to: inputText)
        outputText = result.text
    }

    private var exampleView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Example")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)

            exampleBlock(label: "IN", color: .orange, text: info?.exampleInput ?? "")
            exampleBlock(label: "OUT", color: .green, text: info?.exampleOutput ?? "")
        }
    }

    private func exampleBlock(label: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(color))
                .padding(.leading, 6)
                .offset(y: 4)

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.2)))
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
