import SwiftUI

struct CashflowEntryView: View {
    let session: AppSession
    var correcting: FlowOperation? = nil
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [Account] = []
    @State private var categories: [FlowCategory] = []
    @State private var accountID = ""
    @State private var kind = FlowKind.expense
    @State private var categoryID = "other-expense"
    @State private var amount = ""
    @State private var currency = Currency.usd
    @State private var date = Date()
    @State private var note = ""
    @State private var recurring = false
    @State private var unit = RepeatUnit.month
    @State private var interval = 1
    @State private var hasEnd = false
    @State private var end = Date()
    @State private var newCategory = ""
    @State private var error: String?
    private var service: CashflowService? { session.connection.map { CashflowService(db: $0) } }
    private func t(_ ru: String, _ en: String) -> String { preferences.flowText(ru, en) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(correcting == nil ? t("Доход / Расход", "Income / Expense") : t("Исправить операцию", "Correct operation")).font(.title2.bold())
            if correcting != nil { Text(t("Исходная операция будет сторнирована и заменена новой.", "The original will be reversed and replaced.")).font(.callout).foregroundStyle(.secondary) }
            Form {
                Picker(t("Тип", "Type"), selection: Binding(get: { kind }, set: { value in
                    kind = value; categoryID = value == .income ? "other-income" : "other-expense"
                })) {
                    Text(t("Доход", "Income")).tag(FlowKind.income)
                    Text(t("Расход", "Expense")).tag(FlowKind.expense)
                }.pickerStyle(.segmented)
                Picker(t("Счёт", "Account"), selection: Binding(get: { accountID }, set: { value in
                    accountID = value
                    if let account = accounts.first(where: { $0.id == value }) { currency = account.currency }
                })) {
                    Text(t("Выберите счёт", "Select account")).tag("")
                    ForEach(accounts) { Text($0.name + " · " + $0.currency.rawValue).tag($0.id) }
                }
                HStack {
                    TextField(t("Сумма", "Amount"), text: $amount)
                    Picker(t("Валюта", "Currency"), selection: $currency) { ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(width: 160)
                }
                DatePicker(t("Дата", "Date"), selection: $date, displayedComponents: .date)
                Picker(t("Категория", "Category"), selection: $categoryID) {
                    ForEach(categories.filter { $0.kind == kind }) { Text($0.title(preferences.language)).tag($0.id) }
                }
                HStack {
                    TextField(t("Новая категория", "New category"), text: $newCategory)
                    Button(t("Добавить", "Add")) {
                        do { try service?.addCategory(name: newCategory, kind: kind); categories = try service?.categories() ?? []; categoryID = categories.last?.id ?? categoryID; newCategory = "" }
                        catch { self.error = error.localizedDescription }
                    }.disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                TextField(t("Описание", "Description"), text: $note, axis: .vertical).lineLimit(2...4)
                if correcting == nil {
                    Toggle(t("Регулярная операция", "Recurring operation"), isOn: $recurring)
                    if recurring {
                        Picker(t("Период", "Period"), selection: $unit) { ForEach(RepeatUnit.allCases, id: \.self) { Text(repeatTitle($0, preferences)).tag($0) } }
                        Stepper(t("Каждые: ", "Every: ") + String(interval), value: $interval, in: 1...366)
                        Toggle(t("Дата окончания", "End date"), isOn: $hasEnd)
                        if hasEnd { DatePicker(t("До", "Until"), selection: $end, displayedComponents: .date) }
                        Text(t("Часовой пояс: ", "Timezone: ") + (service?.timezone.identifier ?? TimeZone.current.identifier)).font(.caption)
                        Text(t("Наступившие даты будут проведены, будущие появятся в прогнозе.", "Due dates will be posted; future dates appear in the projection.")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if accounts.isEmpty { Text(t("Сначала создайте карту, наличный или банковский счёт.", "Create a card, cash or bank account first.")).foregroundStyle(.orange) }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Button(t("Отмена", "Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(recurring ? t("Создать расписание", "Create schedule") : t("Провести", "Post"), action: save)
                    .buttonStyle(.borderedProminent).disabled(accountID.isEmpty).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 580).background(DesignTokens.Colors.canvas)
        .onAppear {
            accounts = service?.operationalAccounts() ?? []
            categories = (try? service?.categories()) ?? []
            if let op = correcting {
                accountID = op.accountID; kind = op.kind; categoryID = op.categoryID; amount = "\(op.amount)"
                currency = op.currency; date = FlowDate.parse(op.date, timezone: service?.timezone ?? .current) ?? Date(); note = op.note
            } else if let first = accounts.first { accountID = first.id; currency = first.currency }
        }
    }
    private func save() {
        guard let service else { return }
        do {
            guard let value = AccountCreationValidation.balance(amount) else { throw FlowError.invalidAmount }
            let key = FlowDate.key(date, timezone: service.timezone)
            let draft = FlowDraft(accountID: accountID, kind: kind, categoryID: categoryID, amount: value, currency: currency, date: key, note: note)
            if let correcting { _ = try service.correct(correcting.id, with: draft) }
            else if recurring {
                try service.saveTemplate(RecurringFlow(accountID: accountID, kind: kind, categoryID: categoryID, amount: value,
                    currency: currency, note: note, start: key, end: hasEnd ? FlowDate.key(end, timezone: service.timezone) : nil,
                    unit: unit, interval: interval, timezone: service.timezone.identifier))
            } else { _ = try service.post(draft) }
            session.ledgerChanged(); session.materializeCashflow(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct CashflowFXView: View {
    let session: AppSession
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var rate = ""
    @State private var source = "Manual"
    @State private var date = Date()
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(preferences.flowText("Исторический курс", "Historical FX quote")).font(.title2)
            Text(preferences.flowText("Введите курс на указанную дату. Ранее сохранённые валютные снимки операций сохраняются.", "Enter a dated quote. Existing operation FX snapshots are preserved."))
            Form {
                TextField("1 USD = … KZT", text: $rate)
                DatePicker(preferences.flowText("Дата курса", "Quote date"), selection: $date, displayedComponents: .date)
                TextField(preferences.flowText("Источник", "Source"), text: $source)
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Button(preferences.flowText("Отмена", "Cancel")) { dismiss() }
                Spacer()
                Button(preferences.flowText("Сохранить", "Save")) {
                    do {
                        guard let db = session.connection, let value = AccountCreationValidation.balance(rate) else { throw FlowError.invalidAmount }
                        let service = CashflowService(db: db)
                        try service.saveQuote(from: .usd, to: .kzt, rate: value, date: FlowDate.key(date, timezone: service.timezone), source: source)
                        session.ledgerChanged(); session.materializeCashflow(); dismiss()
                    } catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent)
            }
        }.padding(24).frame(width: 480)
    }
}

struct CashflowReconcileView: View {
    let session: AppSession
    let month: String
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [Account] = []
    @State private var balances: [String: Decimal] = [:]
    @State private var reports: [String: String] = [:]
    @State private var completed: Set<String> = []
    @State private var error: String?
    private var service: CashflowService? { session.connection.map { CashflowService(db: $0) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(preferences.flowText("Сверка месяца ", "Month reconciliation ") + month).font(.title2)
            Text(preferences.flowText("Укажите фактический остаток на конец месяца. Разница попадёт в прочие доходы или расходы.", "Enter the actual month-end balance. The difference posts to Other Income or Other Expense."))
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(accounts) { account in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(account.name).font(.headline); Spacer(); Text(account.currency.rawValue) }
                            Text(preferences.flowText("По журналу: ", "Ledger balance: ") + "\(balances[account.id] ?? 0)").font(.caption)
                            HStack {
                                TextField(preferences.flowText("Фактический остаток", "Reported balance"), text: Binding(get: { reports[account.id] ?? "" }, set: { reports[account.id] = $0 }))
                                Button(completed.contains(account.id) ? preferences.flowText("Пересверить", "Reconcile again") : preferences.flowText("Сверить", "Reconcile")) {
                                    do {
                                        guard let amount = AccountCreationValidation.balance(reports[account.id] ?? "") else { throw FlowError.invalidAmount }
                                        _ = try service?.reconcile(accountID: account.id, month: month, reported: amount)
                                        session.ledgerChanged(); reload()
                                    } catch { self.error = error.localizedDescription }
                                }
                                if completed.contains(account.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            }
                        }.padding(12).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            if accounts.isEmpty { Text(preferences.flowText("Нет счетов для сверки", "No accounts to reconcile")) }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Text("\(completed.count)/\(accounts.count)")
                Spacer()
                Button(preferences.flowText("Готово", "Done")) { dismiss() }
            }
        }.padding(24).frame(width: 620, height: 480).onAppear(perform: reload)
    }
    private func reload() {
        guard let service else { return }
        do {
            let end = try FlowDate.end(month)
            accounts = service.accounts().filter { FlowDate.key($0.balanceDate, timezone: service.timezone) <= end }
            completed = []
            for account in accounts {
                balances[account.id] = try service.balance(accountID: account.id, currency: account.currency, through: end)
                if try service.isReconciled(account: account, month: month) { completed.insert(account.id) }
            }
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
