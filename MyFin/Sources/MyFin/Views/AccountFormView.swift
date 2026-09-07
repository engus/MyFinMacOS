import SwiftUI

struct AccountFormView: View {
    let session: AppSession
    let existingAccount: Account?
    let focusBalance: Bool

    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var country: Country
    @State private var type: AccountType
    @State private var institutionSelection: InstitutionSelection
    @State private var currency: Currency
    @State private var balanceText: String
    @State private var name: String
    @State private var specifyDate: Bool
    @State private var balanceDate: Date
    @State private var errorMessage: String?
    @FocusState private var balanceIsFocused: Bool

    init(session: AppSession, existingAccount: Account?, focusBalance: Bool = false) {
        self.session = session
        self.existingAccount = existingAccount
        self.focusBalance = focusBalance
        _country = State(initialValue: existingAccount?.country ?? .kz)
        _type = State(initialValue: existingAccount?.type ?? .bankAccount)
        if let institutionId = existingAccount?.institutionId {
            _institutionSelection = State(initialValue: .existing(id: institutionId))
        } else {
            _institutionSelection = State(initialValue: .none)
        }
        _currency = State(initialValue: existingAccount?.currency ?? .usd)
        _balanceText = State(initialValue: existingAccount.map { "\($0.openingBalance)" } ?? "0")
        _name = State(initialValue: existingAccount?.name ?? "")
        _specifyDate = State(initialValue: existingAccount != nil)
        _balanceDate = State(initialValue: existingAccount?.balanceDate ?? Date())
    }

    private var institutionService: InstitutionService? {
        session.connection.map { InstitutionService(connection: $0) }
    }

    private var accountService: AccountService? {
        guard let connection = session.connection, let institutionService else { return nil }
        return AccountService(connection: connection, institutionService: institutionService)
    }

    var body: some View {
        Form {
            Picker(preferences.string(.countryFieldLabel), selection: $country) {
                ForEach(Country.allCases, id: \.self) { Text("\($0.flag) \($0.displayName)").tag($0) }
            }
            .onChange(of: country) { _ in institutionSelection = .none }

            Picker(preferences.string(.typeFieldLabel), selection: $type) {
                ForEach(AccountType.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            if type == .cash {
                Text(preferences.string(.cashFieldLabel)).foregroundStyle(.secondary)
            } else if let institutionService {
                BankPickerView(country: country, institutionService: institutionService, selection: $institutionSelection)
            }

            Picker(preferences.string(.currencyFieldLabel), selection: $currency) {
                ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }

            TextField(preferences.string(.balanceTodayFieldLabel), text: $balanceText)
                .focused($balanceIsFocused)

            TextField(preferences.string(.accountNameFieldLabel), text: $name)

            Toggle(preferences.string(.specifyBalanceDateToggle), isOn: $specifyDate)
            if specifyDate {
                DatePicker(preferences.string(.balanceDateFieldLabel), selection: $balanceDate, displayedComponents: .date)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            HStack {
                Button(preferences.string(.cancelButton)) { dismiss() }
                Button(preferences.string(.saveAccountButton)) { save() }
            }
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 420)
        .onAppear { balanceIsFocused = focusBalance }
    }

    private func save() {
        guard let accountService else { return }
        guard let balance = Decimal(string: balanceText) else {
            errorMessage = preferences.string(.negativeBalanceMessage)
            return
        }

        if case .newCustom(let customName) = institutionSelection, customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = preferences.string(.invalidCustomBankNameMessage)
            return
        }

        let result: Result<Account, AccountError>
        if let existingAccount {
            result = accountService.updateAccount(
                id: existingAccount.id, name: name, country: country, type: type, currency: currency,
                institutionSelection: type == .cash ? .none : institutionSelection, openingBalance: balance
            )
        } else {
            result = accountService.createAccount(
                country: country, type: type,
                institutionSelection: type == .cash ? .none : institutionSelection,
                currency: currency, openingBalance: balance, name: name,
                balanceDate: specifyDate ? balanceDate : nil
            )
        }

        switch result {
        case .success:
            errorMessage = nil
            session.ledgerChanged()
            dismiss()
        case .failure(.negativeBalance):
            errorMessage = preferences.string(.negativeBalanceMessage)
        case .failure(.tooManyDecimalDigits):
            errorMessage = preferences.string(.tooManyDecimalDigitsMessage)
        case .failure(.institutionRequired):
            errorMessage = preferences.string(.institutionRequiredMessage)
        case .failure(.currencyHasPostings):
            errorMessage = preferences.flowText("Для счёта с операциями нельзя менять валюту. Создайте отдельный счёт.", "An account with postings cannot change currency. Create another account.")
        case .failure:
            errorMessage = preferences.string(.invalidCustomBankNameMessage)
        }
    }
}
