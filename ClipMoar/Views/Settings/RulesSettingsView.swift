import SwiftUI

final class RulesSettingsModel: ObservableObject {
    let engine: ClipboardRuleEngine
    @Published var rules: [ClipboardRule]
    @Published var selectedRuleId: UUID?

    init(engine: ClipboardRuleEngine = ClipboardRuleEngine()) {
        self.engine = engine
        rules = engine.rules
        selectedRuleId = engine.rules.first?.id
    }

    var selectedRule: ClipboardRule? {
        guard let id = selectedRuleId else { return nil }
        return rules.first { $0.id == id }
    }

    var selectedIndex: Int? {
        guard let id = selectedRuleId else { return nil }
        return rules.firstIndex { $0.id == id }
    }

    func save() {
        engine.rules = rules
    }

    func addRule() {
        let rule = ClipboardRule(name: "New Rule")
        rules.append(rule)
        selectedRuleId = rule.id
        save()
    }

    func removeRule() {
        guard let idx = selectedIndex else { return }
        rules.remove(at: idx)
        selectedRuleId = rules.last?.id
        save()
    }

    func updateRule(_ block: (inout ClipboardRule) -> Void) {
        guard let idx = selectedIndex else { return }
        block(&rules[idx])
        save()
    }

    func addTransform(type: ClipboardTransformType) {
        updateRule { $0.transforms.append(ClipboardTransform(type: type)) }
    }

    func removeTransform(at index: Int) {
        updateRule { $0.transforms.remove(at: index) }
    }
}

struct RulesSettingsView: View {
    @StateObject private var model: RulesSettingsModel
    @StateObject private var regexStore: RegexStore
    @StateObject private var presetStore: PresetStore
    @State private var testInput = ""
    @State private var testOutput = ""

    init(
        model: RulesSettingsModel = RulesSettingsModel(),
        regexStore: RegexStore = RegexStore(),
        presetStore: PresetStore = PresetStore()
    ) {
        _model = StateObject(wrappedValue: model)
        _regexStore = StateObject(wrappedValue: regexStore)
        _presetStore = StateObject(wrappedValue: presetStore)
    }

    private var transformHotkeyString: String? {
        let kc = UserDefaults.standard.integer(forKey: "transformHotkeyKeyCode")
        let mods = UInt32(UserDefaults.standard.integer(forKey: "transformHotkeyModifiers"))
        guard kc != 0 else { return nil }
        return KeyboardShortcutFormatter.string(for: kc, modifiers: NSEvent.ModifierFlags(rawValue: UInt(mods)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let shortcut = transformHotkeyString {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Transform paste enabled (\(shortcut)). Clipboard keeps original text.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.08)))
                .padding(.bottom, 8)
            }

            rulesList

            Divider()
                .padding(.vertical, 12)

            if model.selectedRule != nil {
                ruleEditor

                Divider()
                    .padding(.vertical, 10)

                ruleLookup
            } else {
                Text("Select a rule or create a new one")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var rulesList: some View {
        VStack(spacing: 0) {
            List(selection: $model.selectedRuleId) {
                ForEach(model.rules) { rule in
                    HStack(spacing: 6) {
                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { val in
                                if let idx = model.rules.firstIndex(where: { $0.id == rule.id }) {
                                    model.rules[idx].isEnabled = val
                                    model.save()
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        if let icon = rule.appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        }

                        Text(rule.name)
                            .font(.system(size: 12))
                            .lineLimit(1)

                        Spacer()

                        Text(rule.appName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .tag(rule.id)
                }
            }
            .frame(minHeight: 60, maxHeight: 140)
            .listStyle(.bordered)

            HStack(spacing: 8) {
                Button(action: { model.addRule() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)

                Button(action: { model.removeRule() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .disabled(model.selectedRule == nil)

                Spacer()
            }
            .padding(.top, 6)
        }
    }

    private var ruleEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Description:")
                    .frame(width: 100, alignment: .trailing)
                    .font(.system(size: 12))
                TextField("Rule name", text: Binding(
                    get: { model.selectedRule?.name ?? "" },
                    set: { val in model.updateRule { $0.name = val } }
                ))
                .font(.system(size: 12))
            }

            HStack(spacing: 8) {
                Text("Application:")
                    .frame(width: 100, alignment: .trailing)
                    .font(.system(size: 12))
                appPicker
                Spacer()
            }

            HStack(spacing: 8) {
                Text("Preset:")
                    .frame(width: 100, alignment: .trailing)
                    .font(.system(size: 12))
                presetPicker
                Spacer()
            }

            HStack(spacing: 8) {
                Text("Transforms:")
                    .frame(width: 100, alignment: .trailing)
                    .font(.system(size: 12))
                    .alignmentGuide(.top) { $0[.top] }

                VStack(alignment: .leading, spacing: 4) {
                    transformsList
                }
            }
        }
    }

    private var appPicker: some View {
        Picker("", selection: Binding(
            get: { model.selectedRule?.appBundleId ?? "" },
            set: { val in model.updateRule { $0.appBundleId = val.isEmpty ? nil : val } }
        )) {
            Text("All Applications").tag("")
            Divider()
            ForEach(runningApps, id: \.bundleId) { app in
                Label {
                    Text(app.name)
                } icon: {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                    }
                }
                .tag(app.bundleId)
            }
        }
        .labelsHidden()
        .frame(maxWidth: 200)
    }

    private var runningApps: [(bundleId: String, name: String, icon: NSImage?)] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bundleId = app.bundleIdentifier,
                  !seen.contains(bundleId),
                  app.activationPolicy == .regular else { return nil }
            seen.insert(bundleId)
            let icon = app.icon
            icon?.size = NSSize(width: 16, height: 16)
            return (bundleId, app.localizedName ?? bundleId, icon)
        }
    }

    private var presetPicker: some View {
        Picker("", selection: Binding(
            get: { model.selectedRule?.presetId ?? "" },
            set: { val in model.updateRule { $0.presetId = val } }
        )) {
            Text("None").tag("")
            Divider()
            ForEach(presetStore.presets.filter { !$0.transformTypes.isEmpty }) { preset in
                Text(preset.name).tag(preset.id.uuidString)
            }
        }
        .labelsHidden()
        .frame(maxWidth: 200)
    }

    private var transformsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let rule = model.selectedRule {
                ForEach(Array(rule.transforms.enumerated()), id: \.element.id) { index, transform in
                    transformRow(transform: transform, index: index)
                }
            }

            Menu {
                ForEach(ClipboardTransformType.grouped, id: \.0) { group, types in
                    Section(group.rawValue) {
                        ForEach(types, id: \.self) { type in
                            Button {
                                model.addTransform(type: type)
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

    private func transformRow(transform: ClipboardTransform, index: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: transform.type.icon)
                .frame(width: 14)
                .foregroundColor(.secondary)
                .font(.system(size: 11))

            Picker("", selection: Binding(
                get: { transform.type },
                set: { newType in model.updateRule { $0.transforms[index].type = newType } }
            )) {
                ForEach(ClipboardTransformType.grouped, id: \.0) { group, types in
                    Section(group.rawValue) {
                        ForEach(types, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
            }
            .labelsHidden()
            .frame(width: 150)
            .controlSize(.small)

            if transform.type == .regexReplace {
                regexPicker(for: transform, index: index)
            }

            Spacer()

            Button {
                model.removeTransform(at: index)
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

    private var lookupStatusText: String {
        guard !testInput.isEmpty else { return "" }
        return testOutput != testInput ? "Modified" : "No change"
    }

    private var ruleLookup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick Lookup")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input").font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                    TextField("Paste text here...", text: $testInput, axis: .vertical)
                        .lineLimit(3 ... 20)
                        .font(.system(size: 11, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                        .onChange(of: testInput) { runLookup() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Output").font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                        Spacer()
                        if !lookupStatusText.isEmpty {
                            Text(lookupStatusText)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(lookupStatusText == "Modified" ? .white : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(lookupStatusText == "Modified" ? Capsule().fill(Color.green) : nil)
                        }
                    }
                    ScrollView {
                        Text(testOutput)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Button("Paste") {
                    if let str = NSPasteboard.general.string(forType: .string) {
                        testInput = str
                    }
                }
                .controlSize(.small)

                Button("Clear") {
                    testInput = ""
                    testOutput = ""
                }
                .controlSize(.small)

                Spacer()
            }
        }
        .onChange(of: model.rules) { runLookup() }
        .onChange(of: model.selectedRuleId) { runLookup() }
    }

    private func runLookup() {
        guard !testInput.isEmpty, let rule = model.selectedRule else {
            testOutput = ""
            return
        }
        var testRule = rule
        testRule.appBundleId = nil
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [testRule]), presetStore: presetStore)
        testOutput = engine.apply(to: testInput).text
    }

    private func regexPicker(for _: ClipboardTransform, index: Int) -> some View {
        Picker("", selection: Binding(
            get: {
                guard let rule = model.selectedRule, index < rule.transforms.count else { return "" }
                return rule.transforms[index].regexId
            },
            set: { idStr in
                if let uuid = UUID(uuidString: idStr),
                   let regex = regexStore.patterns.first(where: { $0.id == uuid })
                {
                    model.updateRule {
                        $0.transforms[index].regexId = idStr
                        $0.transforms[index].pattern = regex.pattern
                        $0.transforms[index].replacement = regex.replacement
                    }
                }
            }
        )) {
            Text("Select regex...").tag("")
            ForEach(regexStore.patterns) { regex in
                Text(regex.name).tag(regex.id.uuidString)
            }
        }
        .labelsHidden()
        .frame(width: 150)
        .controlSize(.small)
    }
}
