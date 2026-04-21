import Defaults
import SwiftUI

/// Settings pane for managing user-defined action prompts.
/// Actions appear as buttons in the trigger icon bar alongside Translate.
struct ActionsSettingsView: View {
    @Default(.userDefinedActions) private var actions
    @State private var selectedID: String?

    private var selectedIndex: Int? {
        guard let id = selectedID else { return nil }
        return actions.firstIndex { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Define custom prompts that appear as buttons in the trigger icon bar. Clicking a button sends the selected text to your enabled LLM providers with the action's prompt. Drag rows to reorder.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top)

            List(selection: $selectedID) {
                if actions.isEmpty {
                    Text("No actions yet. Click + to add one.")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(actions, id: \.id) { action in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                            Image(systemName: "sparkles")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.name.isEmpty ? String(localized: "Untitled") : action.name)
                                    .fontWeight(.medium)
                                Text(promptPreview(action.prompt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .tag(action.id)
                    }
                    .onMove { source, destination in
                        actions.move(fromOffsets: source, toOffset: destination)
                    }
                }
            }
            .frame(minHeight: 140, maxHeight: 180)
            .scrollContentBackground(.hidden)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            HStack(spacing: 0) {
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 32, height: 24)

                Divider().frame(height: 16)

                Button(action: removeSelected) {
                    Image(systemName: "minus")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 32, height: 24)
                .disabled(selectedID == nil)

                Spacer()
            }
            .buttonStyle(.borderless)

            if let index = selectedIndex {
                Divider()
                ActionEditor(action: bindingForIndex(index))
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding()
        .onChange(of: actions, initial: true) { _, newValue in
            if let id = selectedID, !newValue.contains(where: { $0.id == id }) {
                selectedID = nil
            }
        }
    }

    private func promptPreview(_ prompt: String) -> String {
        let collapsed = prompt.replacingOccurrences(of: "\n", with: " ")
        return collapsed.isEmpty ? String(localized: "(empty prompt)") : collapsed
    }

    private func addAction() {
        let new = UserDefinedAction(
            name: String(localized: "New Action"),
            prompt: ""
        )
        actions.append(new)
        selectedID = new.id
    }

    private func removeSelected() {
        guard let id = selectedID else { return }
        actions.removeAll { $0.id == id }
        selectedID = nil
    }

    /// Build a binding that reads/writes the action at a fixed index inside the Defaults array.
    /// Looks up by id on each mutation so stale indices after reorder don't clobber the wrong row.
    private func bindingForIndex(_ index: Int) -> Binding<UserDefinedAction> {
        let id = actions[index].id
        return Binding(
            get: {
                actions.first(where: { $0.id == id }) ?? actions[index]
            },
            set: { newValue in
                guard let idx = actions.firstIndex(where: { $0.id == id }) else { return }
                actions[idx] = newValue
            }
        )
    }
}

// MARK: - Action Editor

private struct ActionEditor: View {
    @Binding var action: UserDefinedAction
    @FocusState private var nameFocused: Bool

    private var nameBinding: Binding<String> {
        Binding(
            get: { action.name },
            set: { action = UserDefinedAction(id: action.id, name: $0, prompt: action.prompt) }
        )
    }

    private var promptBinding: Binding<String> {
        Binding(
            get: { action.prompt },
            set: { action = UserDefinedAction(id: action.id, name: action.name, prompt: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Untitled", text: nameBinding)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .focused($nameFocused)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(nameFocused ? Color.accentColor.opacity(0.12) : Color.clear)
                )

            TextEditor(text: promptBinding)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            VStack(alignment: .leading, spacing: 2) {
                Text("Placeholders:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• {{content}} — replaced with the selected text. When present, the prompt becomes a single user message.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• {targetLang} — your preferred target language (e.g. \"English\", \"zh-Hans\").")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
