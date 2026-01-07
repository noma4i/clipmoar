import SwiftUI

final class RulesSettingsModel: ObservableObject {
    let engine: ClipboardRuleEngine
    @Published var rules: [ClipboardRule]
    @Published var selectedRuleId: UUID?

    init(engine: ClipboardRuleEngine = ClipboardRuleEngine()) {
        self.engine = engine
        self.rules = engine.rules
        self.selectedRuleId = engine.rules.first?.id
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
    @StateObject private var model = RulesSettingsModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rulesList

            Divider()
                .padding(.vertical, 12)

            if model.selectedRule != nil {
                ruleEditor
            } else {
                Text("Select a rule or create a new one")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer()
        }
        .padding(24)
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

    @ViewBuilder
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

    private var transformsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let rule = model.selectedRule {
                ForEach(Array(rule.transforms.enumerated()), id: \.element.id) { index, transform in
                    transformRow(transform: transform, index: index)
                }
            }

            Menu {
                ForEach(ClipboardTransformType.allCases, id: \.self) { type in
                    Button {
                        model.addTransform(type: type)
                    } label: {
                        Label(type.displayName, systemImage: type.icon)
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
                ForEach(ClipboardTransformType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .labelsHidden()
            .frame(width: 150)
            .controlSize(.small)

            if transform.type == .regexReplace {
                TextField("Pattern", text: Binding(
                    get: { transform.pattern },
                    set: { val in model.updateRule { $0.transforms[index].pattern = val } }
                ))
                .font(.system(size: 11, design: .monospaced))
                .controlSize(.small)

                Text("->")
                    .font(.system(size: 11))

                TextField("Replace", text: Binding(
                    get: { transform.replacement },
                    set: { val in model.updateRule { $0.transforms[index].replacement = val } }
                ))
                .font(.system(size: 11, design: .monospaced))
                .controlSize(.small)
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
}
