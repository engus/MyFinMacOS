import SwiftUI

struct NewAccountWizardView: View {
    let session: AppSession
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var step = CreationStep.type
    @State private var entity = CreationEntity.account
    @State private var country = Country.kz
    @State private var type = AccountType.debitCard
    @State private var currency = Currency.kzt
    @State private var institutionSelection = InstitutionSelection.none
    @State private var name = ""
    @State private var lastGeneratedName: String?
    @State private var balance = "0"
    @State private var specifiesDate = false
    @State private var date = Date()
    @State private var appearance = AccountAppearance()
    @State private var tag = ""
    @State private var error: L10nKey?
    @State private var showingCashflow = false

    init(session: AppSession, draft: AccountCreationDraft = AccountCreationDraft()) {
        self.session = session
        _step = State(initialValue: draft.step)
        _entity = State(initialValue: draft.entity)
        _country = State(initialValue: draft.country)
        _type = State(initialValue: draft.type)
        _currency = State(initialValue: draft.currency)
        _institutionSelection = State(initialValue: draft.institutionSelection)
        _name = State(initialValue: draft.name)
        _balance = State(initialValue: draft.balance)
        _appearance = State(initialValue: draft.appearance)
    }

    private var institutions: InstitutionService? { session.connection.map(InstitutionService.init(connection:)) }
    private var banks: [Institution] {
        ((try? institutions?.listInstitutions(country: country)) ?? []).compactMap {
            if case .institution(let value) = $0 { return value }; return nil
        }
    }
    private var bankName: String? {
        switch institutionSelection {
        case .existing(let id): return banks.first { $0.id == id }?.name
        case .newCustom(let name): return name
        case .none: return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "plus").font(.system(size: 19, weight: .medium)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(.blue, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.string(.addNewTitle)).font(.system(size: 18, weight: .semibold))
                        Text(preferences.string(.addNewSubtitle)).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel(preferences.string(.cancelButton))
                }
                HStack(spacing: 12) {
                    stepLabel(.type, .creationTypeStep)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    stepLabel(.details, .accountDetailsStep)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    stepLabel(.appearance, .accountAppearanceStep)
                }
            }.padding(24)
            Divider()
            Group {
                if step == .type {
                    entitySelection
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: step == .details ? 12 : 16) {
                                if step == .details { details } else { appearanceFields }
                            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(width: 530)
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                heading(.livePreview)
                                AccountVirtualCardView(accountName: name.isEmpty ? preferences.string(.newAccountTitle) : name,
                                    institutionName: type == .cash ? preferences.string(.cashFieldLabel) : bankName,
                                    type: type, currency: currency,
                                    balance: NumberDisplayFormatter.format(AccountCreationValidation.balance(balance) ?? 0, preferences: session.numberFormatPreferences), appearance: appearance, country: country, baseCurrencyEquivalent: equivalent)
                            }.padding(24)
                        }.background(DesignTokens.Colors.subtleBackground)
                    }
                }
            }
            Divider()
            if let error {
                Text(preferences.string(error)).foregroundStyle(.red).font(.callout)
                    .padding(.horizontal, 20).padding(.top, 8).accessibilityIdentifier("wizardError")
            }
            HStack {
                Button(preferences.string(.wizardBack), action: goBack).disabled(step == .type)
                Spacer()
                Button(preferences.string(.cancelButton)) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(preferences.string(primaryButtonKey), action: advance)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }.controlSize(.large).padding(20)
        }
        .frame(width: 940, height: 720)
        .background(DesignTokens.Colors.canvas)
        .onAppear(perform: updateGeneratedName)
        .onChange(of: suggestedName) { _, _ in updateGeneratedName() }
        .sheet(isPresented: $showingCashflow, onDismiss: { dismiss() }) { CashflowEntryView(session: session) }
    }

    private var suggestedName: String {
        [type == .cash ? nil : bankName, preferences.string(type.labelKey), currency.rawValue]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
    private var equivalent: String? {
        guard currency != session.baseCurrency, let amount = AccountCreationValidation.balance(balance) else { return nil }
        let converted = amount * HardcodedExchangeRateProvider().rate(from: currency, to: session.baseCurrency)
        return "≈ " + NumberDisplayFormatter.format(converted, preferences: session.numberFormatPreferences) + " " + session.baseCurrency.rawValue
    }

    private func updateGeneratedName() {
        if name.isEmpty || name == lastGeneratedName { name = suggestedName }
        lastGeneratedName = suggestedName
    }

    private func stepLabel(_ value: CreationStep, _ key: L10nKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: step.rawValue > value.rawValue ? "checkmark.circle.fill" : "\(value.rawValue + 1).circle.fill")
            Text(preferences.string(key))
        }
        .font(.system(size: 12, weight: step == value ? .semibold : .medium))
        .foregroundStyle(step == value ? Color.blue : Color.secondary)
        .padding(.horizontal, step == value ? 10 : 0).padding(.vertical, 6)
        .background(step == value ? Color.blue.opacity(0.08) : Color.clear, in: Capsule())
    }

    private var entitySelection: some View {
        VStack(spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                entityCard(
                    .account, symbol: "creditcard.fill", tint: .blue,
                    title: .accountEntityTitle, kicker: .accountEntityKicker,
                    description: .accountEntityDescription, examples: .accountEntityExamples
                )
                entityCard(
                    .incomeExpense, symbol: "arrow.up.arrow.down", tint: .green,
                    title: .incomeExpenseEntityTitle, kicker: .incomeExpenseEntityKicker,
                    description: .incomeExpenseEntityDescription, examples: .incomeExpenseEntityExamples
                )
                entityCard(
                    .asset, symbol: "building.2.fill", tint: .purple,
                    title: .assetEntityTitle, kicker: .assetEntityKicker,
                    description: .assetEntityDescription, examples: .assetEntityExamples
                )
            }
            HStack(spacing: 10) {
                Image(systemName: "lightbulb").foregroundStyle(.yellow)
                Text(preferences.string(.creationTypeTip)).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(14)
            .background(DesignTokens.Colors.subtleBackground, in: RoundedRectangle(cornerRadius: 10))
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(DesignTokens.Colors.subtleBackground.opacity(0.45))
    }

    private func entityCard(
        _ value: CreationEntity,
        symbol: String,
        tint: Color,
        title: L10nKey,
        kicker: L10nKey,
        description: L10nKey,
        examples: L10nKey
    ) -> some View {
        Button {
            guard value.isAvailable else { return }
            entity = value
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: symbol).font(.system(size: 18, weight: .medium)).foregroundStyle(tint)
                        .frame(width: 42, height: 42).background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Image(systemName: entity == value ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20)).foregroundStyle(entity == value ? Color.blue : Color.secondary.opacity(0.45))
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(preferences.string(title)).font(.system(size: 16, weight: .semibold))
                    Text(preferences.string(kicker)).font(.system(size: 10, weight: .bold)).tracking(0.7).foregroundStyle(tint)
                    Text(preferences.string(description)).font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Divider()
                Text(preferences.string(examples)).font(.system(size: 10)).foregroundStyle(.tertiary)
                if value.isAvailable {
                    Text(value == .account ? preferences.string(.continueAccountDetails) : preferences.flowText("Добавить операцию", "Add operation")).font(.system(size: 10, weight: .semibold)).foregroundStyle(.blue)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
                } else {
                    Text(preferences.string(.comingSoon)).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 315, alignment: .leading)
            .background(DesignTokens.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(entity == value ? Color.blue : DesignTokens.Colors.cardBorder, lineWidth: entity == value ? 2.5 : 1)
            }
            .opacity(value.isAvailable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!value.isAvailable)
        .accessibilityAddTraits(entity == value ? .isSelected : [])
    }

    private var primaryButtonKey: L10nKey {
        switch step {
        case .type: return entity == .account ? .continueAccountDetails : .addEntryButton
        case .details: return .nextAppearanceButton
        case .appearance: return .addAccountButton
        }
    }

    private func goBack() {
        error = nil
        switch step {
        case .type: break
        case .details: step = .type
        case .appearance: step = .details
        }
    }

    private func heading(_ key: L10nKey) -> some View {
        Text(preferences.string(key).uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
    }
    private var details: some View {
        Group {
            heading(.countryFieldLabel)
            Menu {
                ForEach(Country.allCases, id: \.self) { value in
                    Button(value.flag + " " + value.displayName) { country = value; institutionSelection = .none }
                }
            } label: {
                HStack { Text(country.flag + " " + country.displayName); Spacer(); Image(systemName: "chevron.up.chevron.down") }
                    .padding(10).background(DesignTokens.Colors.subtleBackground, in: RoundedRectangle(cornerRadius: 8))
            }.menuStyle(.borderlessButton).accessibilityLabel(preferences.string(.countryFieldLabel))
            heading(.typeFieldLabel)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach([AccountType.debitCard, .bankAccount, .cash, .deposit], id: \.self) { value in
                    Button { type = value } label: {
                        Label(preferences.string(value.labelKey), systemImage: value.symbolName).font(.system(size: 12))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }.buttonStyle(WizardChoiceStyle(selected: type == value))
                }
                Button(preferences.string(.investUnavailable)) {}.buttonStyle(WizardChoiceStyle(selected: false)).disabled(true)
                Button(preferences.string(.cryptoUnavailable)) {}.buttonStyle(WizardChoiceStyle(selected: false)).disabled(true)
            }
            if type != .cash, let institutions {
                heading(.bankFieldLabel)
                HStack {
                    ForEach(Array(banks.prefix(3))) { bank in
                        Button(bank.name) { institutionSelection = .existing(id: bank.id) }.lineLimit(1)
                    }
                }
                BankPickerView(country: country, institutionService: institutions, selection: $institutionSelection)
            }
            heading(.accountNameFieldLabel)
            TextField(preferences.string(.accountNameFieldLabel), text: $name).textFieldStyle(.plain).padding(10).background(DesignTokens.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 8)).overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(DesignTokens.Colors.cardBorder) }
            heading(.balanceTodayFieldLabel)
            HStack {
                TextField("0.00", text: $balance).font(.system(size: 18, weight: .semibold, design: .monospaced)).textFieldStyle(.roundedBorder)
                Picker(preferences.string(.currencyFieldLabel), selection: $currency) {
                    ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.labelsHidden().frame(width: 85)
            }
            Toggle(preferences.string(.specifyBalanceDateToggle), isOn: $specifiesDate)
            if specifiesDate { DatePicker(preferences.string(.balanceDateFieldLabel), selection: $date, displayedComponents: .date) }
        }.controlSize(.large)
    }

    private var appearanceFields: some View {
        Group {
            heading(.cardTheme)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(AccountThemePreset.allCases, id: \.self) { theme in
                    Button { appearance.themePreset = theme } label: {
                        VStack(alignment: .leading) {
                            HStack { Spacer(); Image(systemName: appearance.themePreset == theme ? "checkmark.circle.fill" : "circle").opacity(0.8) }
                            Spacer()
                            Text(theme.title).font(.system(size: 11, weight: .semibold))
                        }.padding(10).frame(height: 70).frame(maxWidth: .infinity)
                            .foregroundStyle(theme == .titaniumFrost ? .black : .white)
                            .background(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 10))
                            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(appearance.themePreset == theme ? Color.blue : Color.clear, lineWidth: 3) }
                    }.buttonStyle(.plain).accessibilityAddTraits(appearance.themePreset == theme ? .isSelected : [])
                }
            }
            HStack {
                Text(preferences.string(.accentTint)).font(.caption)
                Spacer()
                ForEach(AccountAccentTint.allCases, id: \.self) { tint in
                    Button { appearance.accentTint = tint } label: {
                        Circle().fill(tint.color).frame(width: 20, height: 20).padding(3)
                            .overlay { Circle().stroke(appearance.accentTint == tint ? Color.blue : .clear, lineWidth: 2) }
                    }.buttonStyle(.plain).accessibilityLabel(preferences.string(tint.labelKey)).accessibilityAddTraits(appearance.accentTint == tint ? .isSelected : [])
                }
            }
            if type == .debitCard { paymentNetworkFields }
            Divider()
            heading(.iconLabel)
            HStack {
                ForEach(AccountBadgeIcon.allCases, id: \.self) { badge in
                    Button { appearance.badgeIcon = badge } label: {
                        Image(systemName: badge.symbol).font(.title3).frame(width: 42, height: 30)
                    }.tint(appearance.badgeIcon == badge ? .blue : .gray).accessibilityLabel(preferences.string(badge.labelKey))
                }
            }
            heading(.accountTags)
            HStack {
                TextField(preferences.string(.addTag), text: $tag).textFieldStyle(.roundedBorder).onSubmit(addTag)
                Button(action: addTag) { Image(systemName: "plus") }.accessibilityLabel(preferences.string(.addTag))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))]) {
                ForEach(appearance.tags, id: \.self) { value in
                    Button { appearance.tags.removeAll { $0 == value } } label: { Text("#" + value + " ×").lineLimit(1) }
                        .buttonStyle(.bordered).tint(.blue)
                }
            }
        }
    }
    private var paymentNetworkFields: some View {
        Group {
            Divider()
            heading(.cardNetwork)
            HStack(spacing: 6) {
                ForEach(PaymentNetwork.allCases, id: \.self) { network in
                    Button { appearance.paymentNetwork = network } label: {
                        VStack(spacing: 8) {
                            if network == .mastercard {
                                HStack(spacing: -6) { Circle().fill(.red); Circle().fill(.orange) }.frame(width: 30, height: 20)
                            } else {
                                Text(network == .visa ? "VISA" : network == .kaspiPay ? "K" : network == .unionPay ? "UPI" : "∞").font(.system(size: 15, weight: .bold)).frame(height: 20)
                            }
                            Text(network.title).font(.system(size: 10)).lineLimit(1)
                        }.frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(WizardChoiceStyle(selected: appearance.paymentNetwork == network))
                }
            }
        }
    }
    private func addTag() {
        appearance.tags.append(tag)
        appearance.tags = appearance.sanitized(for: type).tags
        tag = ""
    }
    private func advance() {
        error = nil
        if step == .type {
            guard entity.isAvailable else { return }
            if entity == .incomeExpense { showingCashflow = true; return }
            step = .details
            return
        }
        guard let amount = AccountCreationValidation.balance(balance) else { error = .invalidBalanceMessage; return }
        guard amount >= 0 else { error = .negativeBalanceMessage; return }
        guard AccountService.decimalPlaces(of: amount) <= 8 else { error = .tooManyDecimalDigitsMessage; return }
        if type != .cash {
            if institutionSelection == .none { error = .institutionRequiredMessage; return }
            if case .newCustom(let value) = institutionSelection, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { error = .invalidCustomBankNameMessage; return }
        }
        if step == .details { step = .appearance; return }
        if !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { addTag() }
        guard let connection = session.connection, let institutions else { error = .accountSaveFailed; return }
        let service = AccountService(connection: connection, institutionService: institutions)
        switch service.createAccount(country: country, type: type, institutionSelection: type == .cash ? .none : institutionSelection,
            currency: currency, openingBalance: amount, name: name, balanceDate: specifiesDate ? date : nil, appearance: appearance) {
        case .success: session.ledgerChanged(); dismiss()
        case .failure: error = .accountSaveFailed
        }
    }
}

private struct WizardChoiceStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, minHeight: 30)
            .padding(.horizontal, 5).padding(.vertical, 3)
            .foregroundStyle(selected ? Color.blue : Color.primary.opacity(enabled ? 0.75 : 0.3))
            .background(selected ? Color.blue.opacity(0.06) : Color.primary.opacity(configuration.isPressed ? 0.08 : 0.025), in: RoundedRectangle(cornerRadius: 7))
            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? Color.blue : Color.primary.opacity(0.1), lineWidth: selected ? 1.5 : 1) }
    }
}

struct AccountSpecificationView: View {
    let type: AccountType
    let institution: String?
    let appearance: AccountAppearance
    @EnvironmentObject private var preferences: AppPreferences
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(preferences.string(.accountSpecifications)).font(.system(size: 13, weight: .semibold))
            Divider()
            row(.bankFieldLabel, institution ?? preferences.string(.cashFieldLabel))
            row(.typeFieldLabel, preferences.string(type.labelKey))
            row(.cardTheme, appearance.themePreset.title)
            if type == .debitCard {
                row(.cardNetwork, appearance.paymentNetwork?.title ?? "—")
            }
            if !appearance.tags.isEmpty { Text(appearance.tags.map { "#" + $0 }.joined(separator: "  ")).font(.caption).foregroundStyle(.blue) }
        }.padding(14).cardSurface()
    }
    private func row(_ key: L10nKey, _ value: String) -> some View {
        HStack(alignment: .top) { Text(preferences.string(key)).foregroundStyle(.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing) }.font(.system(size: 11))
    }
}
