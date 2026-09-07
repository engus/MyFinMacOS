import SwiftUI
import AppKit

extension AppPreferences {
    func flowText(_ ru: String, _ en: String) -> String { language == .ru ? ru : en }
}

struct CashflowView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var month: String
    @State private var rows: [FlowOperation] = []
    @State private var accounts: [Account] = []
    @State private var categories: [FlowCategory] = []
    @State private var templates: [RecurringFlow] = []
    @State private var reconciled: Set<String> = []
    @State private var accountFilter = ""
    @State private var categoryFilter = ""
    @State private var kindFilter = ""
    @State private var totals = FlowTotals()
    @State private var error: String?
    @State private var showAdd = false
    @State private var showFX = false
    @State private var showReconcile = false
    @State private var correction: FlowOperation?
    @State private var audit: FlowOperation?
    @State private var reversing: FlowOperation?
    @State private var zone = TimeZone.current.identifier

    private var service: CashflowService? { session.connection.map { CashflowService(db: $0) } }
    private func t(_ ru: String, _ en: String) -> String { preferences.flowText(ru, en) }
    private var filtered: [FlowOperation] {
        rows.filter { (accountFilter.isEmpty || $0.accountID == accountFilter) &&
            (categoryFilter.isEmpty || $0.categoryID == categoryFilter) && (kindFilter.isEmpty || $0.kind.rawValue == kindFilter) }
    }
    private var requiredAccounts: [Account] {
        accounts.filter { !$0.archived && FlowDate.key($0.balanceDate) <= ((try? FlowDate.end(month)) ?? "") }
    }
    private func money(_ amount: Decimal) -> String { NumberDisplayFormatter.format(amount, preferences: session.numberFormatPreferences) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            if let error = session.cashflowError { Text(error).foregroundStyle(.orange) }
            accountStrip.frame(height: 90)
            metrics
            filters
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if filtered.isEmpty { Text(t("В этом месяце нет операций", "No operations this month")).foregroundStyle(.secondary).padding() }
                    ForEach(filtered) { row in operationRow(row) }
                    Divider().padding(.vertical, 12)
                    HStack {
                        Text(t("Регулярные операции", "Recurring templates")).font(.headline)
                        Spacer()
                        Text(t("Проводятся при открытом приложении; пропущенные — при следующем входе.", "Posted while the app is open; missed occurrences catch up on login."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(templates) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.note.isEmpty ? categoryName(item.categoryID) : item.note)
                                Text("\(item.start) · \(repeatTitle(item.unit, preferences)) × \(item.interval) · \(item.timezone)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(money(item.amount) + " " + item.currency.rawValue)
                            Button(item.active ? t("Приостановить", "Pause") : t("Возобновить", "Resume")) {
                                perform { try service?.setTemplateActive(item.id, active: !item.active) }
                            }
                        }.padding(10).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            HStack {
                Text(t("Сверено счетов: ", "Reconciled accounts: ") + "\(reconciled.count)/\(requiredAccounts.count)")
                if !requiredAccounts.isEmpty && reconciled.count == requiredAccounts.count { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                Spacer()
                #if DEBUG
                Button(t("Добавить демо", "Add demo data")) { perform { try service?.addDemoData() } }
                #endif
                Text(t("Часовой пояс", "Timezone")).font(.caption)
                TextField("Asia/Almaty", text: $zone).frame(width: 180).onSubmit { perform { try service?.setTimezone(zone) } }
                Button(t("Применить", "Apply")) { perform { try service?.setTimezone(zone) } }
            }.font(.caption)
        }
        .padding(20)
        .background(DesignTokens.Colors.canvas)
        .onAppear(perform: reload)
        .onChange(of: month) { _, value in
            if let url = URL(string: value), let key = FlowDate.month(from: url) { month = key }
            else { reload() }
        }
        .onChange(of: session.ledgerRevision) { _, _ in reload() }
        .onChange(of: session.baseCurrency) { _, _ in calculate() }
        .onChange(of: accountFilter) { _, _ in calculate() }
        .onChange(of: kindFilter) { _, _ in calculate() }
        .onChange(of: categoryFilter) { _, _ in calculate() }
        .sheet(isPresented: $showAdd, onDismiss: reload) { CashflowEntryView(session: session) }
        .sheet(item: $correction, onDismiss: reload) { CashflowEntryView(session: session, correcting: $0) }
        .sheet(isPresented: $showFX, onDismiss: reload) { CashflowFXView(session: session) }
        .sheet(isPresented: $showReconcile, onDismiss: reload) { CashflowReconcileView(session: session, month: month) }
        .sheet(item: $audit) { op in
            VStack(alignment: .leading, spacing: 12) {
                Text(t("История операции", "Operation audit")).font(.title2)
                ScrollView {
                    Text(auditText(op)).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(t("Закрыть", "Close")) { audit = nil }
            }.padding(24).frame(width: 650, height: 480)
        }
        .confirmationDialog(t("Сторнировать операцию?", "Reverse this operation?"), isPresented: Binding(get: { reversing != nil }, set: { if !$0 { reversing = nil } })) {
            Button(t("Сторнировать", "Reverse"), role: .destructive) {
                if let id = reversing?.id { perform { _ = try service?.reverse(id) } }; reversing = nil
            }
        } message: { Text(t("Будет создана обратная проводка. Исходная операция останется в истории.", "A reversing posting will be added. The original remains in the audit history.")) }
    }
    private var header: some View {
        HStack {
            Text("Cashflow").font(.title2.bold())
            Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
            TextField("YYYY-MM", text: $month).frame(width: 90)
            Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
            Button(t("Сегодня", "Today")) { month = String((service?.today ?? FlowDate.key(Date())).prefix(7)) }
            Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(FlowDate.url(month: month).absoluteString, forType: .string) } label: { Image(systemName: "link") }
                .help(t("Скопировать ссылку на месяц", "Copy month link"))
            Spacer()
            Button("FX") { showFX = true }
            Button(t("Сверить месяц", "Reconcile month")) { showReconcile = true }
                .disabled(month >= String((service?.today ?? FlowDate.key(Date())).prefix(7)))
            Button(t("+ Операция", "+ Operation")) { showAdd = true }.buttonStyle(.borderedProminent)
        }
    }
    private var accountStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach([AccountType.debitCard, .cash, .bankAccount], id: \.self) { type in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.string(type.labelKey)).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            ForEach(accounts.filter { !$0.archived && $0.type == type }) { account in
                                Button { accountFilter = accountFilter == account.id ? "" : account.id } label: {
                                    VStack(alignment: .leading) {
                                        Text(account.name).lineLimit(1)
                                        Text(money(account.openingBalance) + " " + account.currency.rawValue).monospacedDigit()
                                    }.padding(8)
                                }.tint(accountFilter == account.id ? .blue : .secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    private var metrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 25) {
                metric(futureMonth ? t("Ожидаемые доходы", "Expected income") : t("Доходы", "Income"), futureMonth ? totals.expectedIncome : totals.income, .green)
                metric(futureMonth ? t("Ожидаемые расходы", "Expected expenses") : t("Расходы", "Expenses"), futureMonth ? totals.expectedExpense : totals.expense, .orange)
                metric(futureMonth ? t("Прогноз сбережений", "Projected net") : t("Сбережения", "Net savings"), futureMonth ? totals.projectedNet : totals.net, .primary)
                VStack(alignment: .leading) {
                    Text(t("Норма сбережений", "Savings rate")).font(.caption)
                    Text(displaySavingsRate.map { money($0 * 100) + "%" } ?? "—").font(.title3.bold())
                }
                Spacer()
            }
            if filtered.contains(where: \.expected) {
                Text(projectionText).font(.callout)
            }
            if totals.missingFX > 0 { Text(t("Итоги неполные: нет курса для операций: ", "Incomplete totals — missing FX for operations: ") + String(totals.missingFX)).foregroundStyle(.orange) }
            if totals.staleFX > 0 { Text(t("Используется последний доступный курс для операций: ", "Last available FX quote used for operations: ") + String(totals.staleFX)).foregroundStyle(.secondary).font(.caption) }
        }.padding(14).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
    private var futureMonth: Bool { month > String((service?.today ?? FlowDate.key(Date())).prefix(7)) }
    private var displaySavingsRate: Decimal? {
        if futureMonth { return totals.expectedIncome > 0 && totals.missingFX == 0 ? totals.projectedNet / totals.expectedIncome : nil }
        return totals.savingsRate
    }
    private var projectionText: String {
        let income = t("Ожидается: доходы ", "Expected: income ") + money(totals.expectedIncome)
        let expense = t("расходы ", "expenses ") + money(totals.expectedExpense)
        let net = t("прогноз сбережений ", "projected net ") + money(totals.projectedNet) + " " + session.baseCurrency.rawValue
        return [income, expense, net].joined(separator: " · ")
    }
    private func metric(_ label: String, _ amount: Decimal, _ color: Color) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption)
            Text((totals.missingFX > 0 ? "≈ " : "") + money(amount) + " " + session.baseCurrency.rawValue).font(.title3.bold()).foregroundStyle(color)
        }
    }
    private var filters: some View {
        HStack {
            Picker(t("Тип", "Type"), selection: $kindFilter) {
                Text(t("Все", "All")).tag("")
                Text(t("Доходы", "Income")).tag("income"); Text(t("Расходы", "Expense")).tag("expense")
            }.frame(width: 190)
            Picker(t("Счёт", "Account"), selection: $accountFilter) {
                Text(t("Все", "All")).tag("")
                ForEach(accounts) { Text($0.name).tag($0.id) }
            }.frame(maxWidth: 260)
            Picker(t("Категория", "Category"), selection: $categoryFilter) {
                Text(t("Все", "All")).tag("")
                ForEach(categories) { Text($0.title(preferences.language)).tag($0.id) }
            }.frame(maxWidth: 260)
            Spacer()
        }
    }
    private func operationRow(_ row: FlowOperation) -> some View {
        let reversed = rows.contains { $0.reversalOf == row.id }
        return HStack(spacing: 12) {
            Text(row.date).monospacedDigit().frame(width: 90, alignment: .leading)
            Image(systemName: row.kind == .income ? "arrow.down.left" : "arrow.up.right").foregroundStyle(row.kind == .income ? .green : .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.note.isEmpty ? categoryName(row.categoryID) : row.note).lineLimit(1)
                Text(categoryName(row.categoryID) + " · " + (accounts.first { $0.id == row.accountID }?.name ?? "—")).font(.caption).foregroundStyle(.secondary)
                Text(status(row, reversed: reversed)).font(.caption).foregroundStyle(row.expected ? .blue : .secondary)
            }
            Spacer()
            Text((row.reversalOf != nil ? "−" : "") + money(row.amount) + " " + row.currency.rawValue).monospacedDigit()
            if !row.expected {
                Menu {
                    Button(t("История и проводки", "Audit and entries")) { audit = row }
                    if !reversed && row.reversalOf == nil && row.source != .reconciliation {
                        Button(t("Исправить", "Correct")) { correction = row }
                        Button(t("Сторнировать", "Reverse"), role: .destructive) { reversing = row }
                    }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 26)
            }
        }.padding(10).background(row.expected ? Color.blue.opacity(0.06) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 7))
            .opacity(reversed || row.reversalOf != nil ? 0.65 : 1)
    }
    private func status(_ row: FlowOperation, reversed: Bool) -> String {
        var values = [row.expected ? t("Ожидается", "Expected") : reversed ? t("Сторнирована", "Reversed") : row.reversalOf != nil ? t("Сторно", "Reversal") : t("Проведена", "Posted")]
        if row.source == .recurring { values.append(t("Регулярная", "Recurring")) }
        if row.replacementOf != nil { values.append(t("Исправление", "Replacement")) }
        if row.source == .reconciliation { values.append(t("Сверка", "Reconciliation")) }
        if row.gap { values.append(t("Покрывает пропуск месяцев", "Covers a multi-month gap")) }
        return values.joined(separator: " · ")
    }
    private func categoryName(_ id: String) -> String { categories.first { $0.id == id }?.title(preferences.language) ?? id }
    private func moveMonth(_ delta: Int) {
        guard let date = FlowDate.parse(month + "-01"), let next = Calendar.current.date(byAdding: .month, value: delta, to: date) else { return }
        month = FlowDate.month(next)
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); session.ledgerChanged(); reload() } catch { self.error = error.localizedDescription }
    }
    private func reload() {
        guard let service else { return }
        do {
            rows = try service.monthly(month); accounts = service.accounts(includeArchived: true)
            categories = try service.categories(); templates = try service.templates(); zone = service.timezone.identifier
            reconciled = Set(try requiredAccounts.filter { try service.isReconciled(account: $0, month: month) }.map(\.id))
            error = nil; calculate()
        } catch { self.error = error.localizedDescription }
    }
    private func calculate() {
        do { totals = try service?.totals(filtered, base: session.baseCurrency) ?? FlowTotals() }
        catch { self.error = error.localizedDescription }
    }
    private func auditText(_ op: FlowOperation) -> String {
        guard let service else { return "" }
        do {
            let all = try service.operations()
            let links = all.filter { $0.id == op.id || $0.reversalOf == op.id || $0.replacementOf == op.id || $0.id == op.reversalOf || $0.id == op.replacementOf }
            return try links.map { item in
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                var json = String(decoding: try encoder.encode(item), as: UTF8.self)
                if let quote = try service.valuation(item, base: session.baseCurrency) {
                    json += "\n\nFX → " + session.baseCurrency.rawValue + "\n" + String(decoding: try encoder.encode(quote), as: UTF8.self)
                }
                let entries = try service.db.query("SELECT ledger_account_id, currency, units FROM ledger_entries WHERE operation_id = ?;", params: [.text(item.id)])
                return json + "\n\n" + entries.map { row in
                    let amount: Decimal = { if case .int(let v)? = row["units"] { return Decimal(v) / FlowMoney.scale }; return 0 }()
                    return (row.string("ledger_account_id") ?? "") + "  " + "\(amount) " + (row.string("currency") ?? "")
                }.joined(separator: "\n")
            }.joined(separator: "\n\n──────────\n\n")
        } catch { return error.localizedDescription }
    }
}

@MainActor func repeatTitle(_ unit: RepeatUnit, _ preferences: AppPreferences) -> String {
    switch unit {
    case .week: return preferences.flowText("Неделя", "Week")
    case .month: return preferences.flowText("Месяц", "Month")
    case .quarter: return preferences.flowText("Квартал", "Quarter")
    case .year: return preferences.flowText("Год", "Year")
    case .days: return preferences.flowText("Дни (свой интервал)", "Days (custom interval)")
    }
}
