import SwiftUI

struct SavedRegex: Codable, Identifiable {
    var id = UUID()
    var name: String
    var pattern: String
    var replacement: String
}

final class RegexStore: ObservableObject {
    private let key = "savedRegexPatterns"
    @Published var patterns: [SavedRegex] = []

    init() {
        load()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(patterns) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedRegex].self, from: data) else { return }
        patterns = decoded
    }

    func add() {
        patterns.append(SavedRegex(name: "New Pattern", pattern: "", replacement: ""))
        save()
    }

    func remove(id: UUID) -> UUID? {
        patterns.removeAll { $0.id == id }
        save()
        return patterns.last?.id
    }
}

struct RegexSettingsView: View {
    @StateObject private var store = RegexStore()
    @State private var selectedId: UUID?
    @State private var testInput = ""
    @State private var testOutput = ""
    @State private var testError = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                patternList
                Divider()
                editor
            }
            Spacer()
        }
        .padding(24)
    }

    private var selectedPattern: SavedRegex? {
        guard let id = selectedId else { return nil }
        return store.patterns.first { $0.id == id }
    }

    private var selectedIndex: Int? {
        guard let id = selectedId else { return nil }
        return store.patterns.firstIndex { $0.id == id }
    }

    private var patternList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(store.patterns) { pattern in
                Button {
                    selectedId = pattern.id
                    runTest()
                } label: {
                    HStack {
                        Text(pattern.name)
                            .font(.system(size: 12))
                            .foregroundColor(selectedId == pattern.id ? .primary : .secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedId == pattern.id ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button(action: {
                    store.add()
                    selectedId = store.patterns.last?.id
                }) {
                    Image(systemName: "plus").font(.system(size: 12))
                }
                .buttonStyle(.borderless)

                Button(action: {
                    if let id = selectedId {
                        selectedId = store.remove(id: id)
                    }
                }) {
                    Image(systemName: "minus").font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .disabled(selectedId == nil)

                Spacer()
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(width: 180)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let idx = selectedIndex {
                HStack(spacing: 8) {
                    Text("Name:")
                        .font(.system(size: 11))
                        .frame(width: 70, alignment: .trailing)
                    TextField("Pattern name", text: $store.patterns[idx].name)
                        .font(.system(size: 11))
                        .onChange(of: store.patterns[idx].name) { store.save() }
                }

                HStack(spacing: 8) {
                    Text("Pattern:")
                        .font(.system(size: 11))
                        .frame(width: 70, alignment: .trailing)
                    TextField("Regular expression", text: $store.patterns[idx].pattern)
                        .font(.system(size: 11, design: .monospaced))
                        .onChange(of: store.patterns[idx].pattern) {
                            store.save()
                            runTest()
                        }
                }

                HStack(spacing: 8) {
                    Text("Replace:")
                        .font(.system(size: 11))
                        .frame(width: 70, alignment: .trailing)
                    TextField("Replacement ($1, $2...)", text: $store.patterns[idx].replacement)
                        .font(.system(size: 11, design: .monospaced))
                        .onChange(of: store.patterns[idx].replacement) {
                            store.save()
                            runTest()
                        }
                }

                Divider().padding(.vertical, 4)

                Text("Test").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)

                TextField("Input text to test...", text: $testInput, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(6)
                    .frame(height: 60, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                    .onChange(of: testInput) { runTest() }

                HStack {
                    Text("Result").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    Spacer()
                    if !testError.isEmpty {
                        Text(testError)
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    } else if !testInput.isEmpty, testOutput != testInput {
                        Text("Match")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green))
                    }
                }
                .frame(height: 16)

                ScrollView {
                    Text(testOutput)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                }
                .frame(height: 60)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            } else {
                Text("Select or create a regex pattern")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer()
        }
        .frame(width: 340)
    }

    private func runTest() {
        testError = ""
        guard let pattern = selectedPattern, !testInput.isEmpty, !pattern.pattern.isEmpty else {
            testOutput = testInput
            return
        }

        do {
            let regex = try NSRegularExpression(pattern: pattern.pattern)
            let range = NSRange(testInput.startIndex..., in: testInput)
            testOutput = regex.stringByReplacingMatches(in: testInput, range: range, withTemplate: pattern.replacement)
        } catch {
            testError = "Invalid regex"
            testOutput = testInput
        }
    }
}
