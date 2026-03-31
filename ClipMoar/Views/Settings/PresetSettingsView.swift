import SwiftUI

final class PresetStore: ObservableObject {
    private let key = "transformPresets"
    private let defaults: UserDefaults
    @Published var presets: [TransformPreset] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: key)
    }

    func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TransformPreset].self, from: data)
        else {
            presets = Self.builtInPresets
            save()
            return
        }
        presets = decoded
    }

    func add() {
        presets.append(TransformPreset(name: "New Preset", description: "", transformTypes: []))
        save()
    }

    func remove(id: UUID) -> UUID? {
        guard let preset = presets.first(where: { $0.id == id }), !preset.isBuiltIn else { return nil }
        presets.removeAll { $0.id == id }
        save()
        return presets.last?.id
    }

    func resetToDefault(id: UUID) {
        guard let idx = presets.firstIndex(where: { $0.id == id }),
              presets[idx].isBuiltIn,
              let original = Self.builtInPresets.first(where: { $0.name == presets[idx].name })
        else { return }
        presets[idx].transformTypes = original.transformTypes
        presets[idx].description = original.description
        save()
    }

    static let builtInPresets: [TransformPreset] = [
        TransformPreset(
            name: "Clean Terminal Output",
            description: "Strip prompts, flatten, trim, collapse blanks, remove box drawing",
            transformTypes: [.stripShellPrompts, .flattenMultiline, .trimWhitespace, .collapseBlankLines, .removeBoxDrawing],
            isBuiltIn: true
        ),
        TransformPreset(
            name: "Claude Code",
            description: "Clean up text copied from Claude Code output",
            transformTypes: [.smartJoinLines, .collapseBlankLines, .trimWhitespace],
            isBuiltIn: true
        ),
        TransformPreset(
            name: "Clean URL",
            description: "Remove tracking parameters and trim whitespace",
            transformTypes: [.stripTrackingParams, .trimWhitespace],
            isBuiltIn: true
        ),
        TransformPreset(
            name: "Code Snippet",
            description: "Clean up code: trim, dedent, convert tabs to spaces",
            transformTypes: [.trimWhitespace, .dedent, .tabsToSpaces],
            isBuiltIn: true
        ),
        TransformPreset(
            name: "Plain Text Cleanup",
            description: "General text cleanup: trim, normalize quotes, collapse blanks, join paragraphs",
            transformTypes: [.trimWhitespace, .normalizeQuotes, .collapseBlankLines, .joinParagraphs],
            isBuiltIn: true
        ),
    ]
}

struct PresetSettingsView: View {
    @StateObject private var store: PresetStore
    @State private var selectedId: UUID?

    init(store: PresetStore = PresetStore()) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                presetList
                Divider()
                editor
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectedPreset: TransformPreset? {
        guard let id = selectedId else { return nil }
        return store.presets.first { $0.id == id }
    }

    private var selectedIndex: Int? {
        guard let id = selectedId else { return nil }
        return store.presets.firstIndex { $0.id == id }
    }

    private var presetList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(store.presets) { preset in
                Button {
                    selectedId = preset.id
                } label: {
                    HStack(spacing: 6) {
                        if preset.isBuiltIn {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Text(preset.name)
                            .font(.system(size: 12))
                            .foregroundColor(selectedId == preset.id ? .primary : .secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(preset.transformTypes.count)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedId == preset.id ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button(action: {
                    store.add()
                    selectedId = store.presets.last?.id
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
                .disabled(selectedPreset == nil || selectedPreset?.isBuiltIn == true)

                Spacer()
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(width: 200)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let idx = selectedIndex {
                HStack(spacing: 8) {
                    Text("Name:")
                        .font(.system(size: 11))
                        .frame(width: 80, alignment: .trailing)
                    if store.presets[idx].isBuiltIn {
                        Text(store.presets[idx].name)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        TextField("Preset name", text: $store.presets[idx].name)
                            .font(.system(size: 11))
                            .onChange(of: store.presets[idx].name) { store.save() }
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("Description:")
                        .font(.system(size: 11))
                        .frame(width: 80, alignment: .trailing)
                    TextField("What this preset does", text: $store.presets[idx].description, axis: .vertical)
                        .lineLimit(2 ... 4)
                        .font(.system(size: 11))
                        .onChange(of: store.presets[idx].description) { store.save() }
                }

                Divider().padding(.vertical, 4)

                Text("Transforms")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                transformList(presetIndex: idx)

                if store.presets[idx].isBuiltIn {
                    Button("Reset to Default") {
                        store.resetToDefault(id: store.presets[idx].id)
                    }
                    .controlSize(.small)
                    .padding(.top, 4)
                }
            } else {
                Text("Select or create a preset")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func transformList(presetIndex idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(store.presets[idx].transformTypes.enumerated()), id: \.offset) { offset, type in
                HStack(spacing: 6) {
                    Image(systemName: type.icon)
                        .frame(width: 14)
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))

                    Text(type.displayName)
                        .font(.system(size: 11))

                    Spacer()

                    Button {
                        store.presets[idx].transformTypes.remove(at: offset)
                        store.save()
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.04)))
            }

            Menu {
                ForEach(ClipboardTransformType.grouped, id: \.0) { group, types in
                    Section(group.rawValue) {
                        ForEach(types, id: \.self) { type in
                            Button {
                                store.presets[idx].transformTypes.append(type)
                                store.save()
                            } label: {
                                Label(type.displayName, systemImage: type.icon)
                            }
                        }
                    }
                }
            } label: {
                Label("Add Transform", systemImage: "plus")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
