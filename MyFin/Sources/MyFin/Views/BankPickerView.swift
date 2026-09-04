import SwiftUI

struct BankPickerView: View {
    let country: Country
    let institutionService: InstitutionService
    @Binding var selection: InstitutionSelection
    @EnvironmentObject var preferences: AppPreferences

    @State private var searchText = ""
    @State private var items: [InstitutionPickerItem] = []
    @State private var highlightedIndex = 0
    @State private var isEnteringCustomName = false
    @State private var customName = ""
    @State private var isExpanded = false
    @State private var selectedLabel = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        Group {
            if isEnteringCustomName {
                HStack {
                    TextField(preferences.string(.customBankNameField), text: $customName)
                        .onChange(of: customName) { newValue in
                            let trimmed = String(newValue.prefix(100))
                            customName = trimmed
                            selection = .newCustom(name: trimmed)
                            selectedLabel = trimmed
                        }
                    Button(preferences.string(.backToListButton)) {
                        isEnteringCustomName = false
                        customName = ""
                        reload()
                    }
                }
            } else {
                Button {
                    reload()
                    isExpanded = true
                } label: {
                    HStack {
                        Text(selectedLabel.isEmpty ? preferences.string(.bankFieldLabel) : selectedLabel)
                            .foregroundStyle(selectedLabel.isEmpty ? Color.secondary : Color.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
                    VStack(spacing: 0) {
                        TextField(preferences.string(.bankFieldLabel), text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .padding(8)
                            .focused($isSearchFieldFocused)
                            .onChange(of: searchText) { _ in reload() }
                            .onKeyPress(.downArrow) {
                                highlightedIndex = min(highlightedIndex + 1, max(items.count - 1, 0))
                                return .handled
                            }
                            .onKeyPress(.upArrow) {
                                highlightedIndex = max(highlightedIndex - 1, 0)
                                return .handled
                            }
                            .onKeyPress(.return) {
                                selectHighlighted()
                                return .handled
                            }
                            .onKeyPress(.escape) {
                                isExpanded = false
                                return .handled
                            }
                        Divider()
                        List(Array(items.enumerated()), id: \.element.id) { index, item in
                            Text(label(for: item))
                                .foregroundStyle(isOtherBank(item) ? Color.secondary : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .background(index == highlightedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                                .onTapGesture {
                                    highlightedIndex = index
                                    selectHighlighted()
                                }
                        }
                        .listStyle(.plain)
                    }
                    .frame(width: 320, height: 260)
                    .onAppear {
                        reload()
                        isSearchFieldFocused = true
                    }
                }
            }
        }
        .onAppear {
            reload()
            updateSelectedLabel()
        }
        .onChange(of: selection) { _ in updateSelectedLabel() }
        .onChange(of: country) { _ in reload() }
    }

    private func reload() {
        items = (try? institutionService.search(query: searchText, in: country)) ?? []
        highlightedIndex = 0
        updateSelectedLabel()
    }

    private func updateSelectedLabel() {
        switch selection {
        case .none:
            selectedLabel = ""
        case .newCustom(let name):
            selectedLabel = name
        case .existing(let id):
            if let match = matchingInstitution(id: id) {
                selectedLabel = match.name
            } else {
                selectedLabel = ""
            }
        }
    }

    private func matchingInstitution(id: String) -> Institution? {
        if let found = items.compactMap({ item -> Institution? in
            if case .institution(let institution) = item, institution.id == id { return institution }
            return nil
        }).first {
            return found
        }
        let all = (try? institutionService.listInstitutions(country: country)) ?? []
        return all.compactMap { item -> Institution? in
            if case .institution(let institution) = item, institution.id == id { return institution }
            return nil
        }.first
    }

    private func selectHighlighted() {
        guard items.indices.contains(highlightedIndex) else { return }
        switch items[highlightedIndex] {
        case .otherBank:
            isEnteringCustomName = true
            isExpanded = false
        case .institution(let institution):
            selection = .existing(id: institution.id)
            selectedLabel = institution.name
            searchText = ""
            isExpanded = false
        }
    }

    private func isOtherBank(_ item: InstitutionPickerItem) -> Bool {
        if case .otherBank = item { return true }
        return false
    }

    private func label(for item: InstitutionPickerItem) -> String {
        switch item {
        case .otherBank: return preferences.string(.otherBankLabel)
        case .institution(let institution): return institution.name
        }
    }
}
