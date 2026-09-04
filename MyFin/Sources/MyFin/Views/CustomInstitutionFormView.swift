import SwiftUI

struct CustomInstitutionFormView: View {
    let session: AppSession
    let existingInstitution: Institution?

    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var country: Country
    @State private var name: String
    @State private var errorMessage: String?

    init(session: AppSession, existingInstitution: Institution?) {
        self.session = session
        self.existingInstitution = existingInstitution
        _country = State(initialValue: existingInstitution?.country ?? .kz)
        _name = State(initialValue: existingInstitution?.name ?? "")
    }

    private var institutionService: InstitutionService? {
        session.connection.map { InstitutionService(connection: $0) }
    }

    var body: some View {
        Form {
            Picker(preferences.string(.countryFieldLabel), selection: $country) {
                ForEach(Country.allCases, id: \.self) { Text("\($0.flag) \($0.displayName)").tag($0) }
            }

            TextField(preferences.string(.customBankNameField), text: $name)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            HStack {
                Button(preferences.string(.cancelButton)) { dismiss() }
                Button(preferences.string(.saveButton)) { save() }
            }
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 220)
    }

    private func save() {
        guard let institutionService else { return }

        guard let existingInstitution else {
            handle(institutionService.resolveOrCreateCustomInstitution(name: name, country: country))
            return
        }

        var result: Result<Institution, InstitutionError> = .success(existingInstitution)
        if name != existingInstitution.name {
            result = institutionService.renameCustomInstitution(id: existingInstitution.id, name: name)
        }
        if case .success = result, country != existingInstitution.country {
            result = institutionService.changeCustomInstitutionCountry(id: existingInstitution.id, country: country)
        }
        handle(result)
    }

    private func handle(_ result: Result<Institution, InstitutionError>) {
        switch result {
        case .success:
            errorMessage = nil
            dismiss()
        case .failure(.invalidName):
            errorMessage = preferences.string(.invalidCustomBankNameMessage)
        case .failure(.inUse):
            errorMessage = preferences.string(.institutionInUseMessage)
        case .failure(.conflictWithArchived):
            errorMessage = preferences.string(.institutionArchivedConflictMessage)
        case .failure(.systemInstitutionIsReadOnly), .failure(.notFound):
            errorMessage = preferences.string(.invalidCustomBankNameMessage)
        }
    }
}
