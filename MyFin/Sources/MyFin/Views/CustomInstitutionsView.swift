import SwiftUI

struct CustomInstitutionsView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences

    @State private var showArchived = false
    @State private var institutions: [Institution] = []
    @State private var showingAdd = false
    @State private var editingInstitution: Institution?

    private var institutionService: InstitutionService? {
        session.connection.map { InstitutionService(connection: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle(preferences.string(.showArchivedToggle), isOn: $showArchived)
                    .toggleStyle(.switch)
                    .onChange(of: showArchived) { _ in reload() }
                Spacer()
                Button(preferences.string(.addCustomInstitutionButton)) { showingAdd = true }
            }
            if institutions.isEmpty {
                Text(preferences.string(.noCustomInstitutionsYet)).foregroundStyle(.secondary)
                Spacer()
            } else {
                List(institutions) { institution in
                    CustomInstitutionRowView(
                        institution: institution,
                        onEdit: { editingInstitution = institution },
                        onToggleArchive: { toggleArchive(institution) }
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { reload() }
        .sheet(isPresented: $showingAdd, onDismiss: reload) {
            CustomInstitutionFormView(session: session, existingInstitution: nil)
        }
        .sheet(item: $editingInstitution, onDismiss: reload) { institution in
            CustomInstitutionFormView(session: session, existingInstitution: institution)
        }
    }

    private func reload() {
        institutions = institutionService?.listCustomInstitutions(includeArchived: showArchived) ?? []
    }

    private func toggleArchive(_ institution: Institution) {
        guard let service = institutionService else { return }
        _ = institution.archived ? service.restoreCustomInstitution(id: institution.id) : service.archiveCustomInstitution(id: institution.id)
        reload()
    }
}

private struct CustomInstitutionRowView: View {
    let institution: Institution
    let onEdit: () -> Void
    let onToggleArchive: () -> Void

    @EnvironmentObject var preferences: AppPreferences

    var body: some View {
        HStack {
            Image(systemName: SystemInstitutionCatalog.institutionIconName)
                .foregroundStyle(ProfileIconPalette.color(named: SystemInstitutionCatalog.color(forID: institution.id) ?? "blue"))
            VStack(alignment: .leading) {
                Text(institution.name).font(.headline)
                Text("\(institution.country.flag) \(institution.country.displayName)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(institution.archived ? preferences.string(.archivedStatusLabel) : preferences.string(.activeStatusLabel))
                .foregroundStyle(institution.archived ? Color.secondary : Color.green)
            Button(preferences.string(.editButton), action: onEdit)
            Button(institution.archived ? preferences.string(.restoreButton) : preferences.string(.archiveButton), action: onToggleArchive)
        }
    }
}
