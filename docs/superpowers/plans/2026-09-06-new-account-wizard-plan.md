# New Account Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved two-step new-account wizard, persist account appearance in a one-to-one table, and show the saved virtual card in the existing details/history inspector.

**Architecture:** Add a typed `AccountAppearance` aggregate backed by `account_appearances`, and make `AccountService` save the account and appearance in one transaction while preserving the existing update flow. Drive the new-only SwiftUI wizard from a testable draft model, reuse one virtual-card renderer in the wizard and inspector, and keep Dashboard/list/edit layouts unchanged.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 14+, SQLCipher/SQLite, XCTest, Swift Package Manager.

**Spec:** `docs/superpowers/specs/2026-09-06-new-account-wizard-design.md`

## Global Constraints

- Existing edit-account UI and balance-reconciliation behavior remain unchanged.
- Only debit card, bank account, cash, and deposit remain selectable account types.
- Only USD and KZT remain selectable currencies.
- Investment, cryptocurrency, and unsupported currencies may appear only as disabled mockup controls.
- Card-specific settings are present only for debit-card accounts and are stored as `NULL` for every other account type.
- Dashboard and account-list rows do not gain a large virtual card.
- All account, opening-balance, history, and appearance writes are atomic.
- All new user-facing copy is available in Russian and English.

---

### Task 1: Define the appearance domain and schema migration

**Files:**
- Create: `MyFin/Sources/MyFin/Models/AccountAppearance.swift`
- Modify: `MyFin/Sources/MyFin/Models/Account.swift`
- Modify: `MyFin/Sources/MyFin/Services/DatabaseService.swift`
- Create: `MyFin/Tests/MyFinTests/AccountAppearanceTests.swift`
- Modify: `MyFin/Tests/MyFinTests/DatabaseServiceTests.swift`

**Interfaces:**
- Produces: `AccountAppearance`, `AccountThemePreset`, `AccountAccentTint`, `AccountBadgeIcon`, `PaymentNetwork`, `CardTier`, and `ChipStyle`.
- Produces: `Account.appearance: AccountAppearance`.
- Produces: database schema version 6 and table `account_appearances`.

- [ ] **Step 1: Write failing model tests for defaults, non-card sanitization, and tag normalization**

```swift
func test_defaultAppearance_matchesApprovedWizardDefaults() {
    let appearance = AccountAppearance.default
    XCTAssertEqual(appearance.themePreset, .obsidianMatte)
    XCTAssertEqual(appearance.accentTint, .blue)
    XCTAssertEqual(appearance.badgeIcon, .card)
    XCTAssertEqual(appearance.paymentNetwork, .mastercard)
    XCTAssertEqual(appearance.cardTier, .standard)
    XCTAssertEqual(appearance.chipStyle, .goldBrass)
    XCTAssertEqual(appearance.tags, [])
    XCTAssertTrue(appearance.showsCardholderName ?? false)
    XCTAssertTrue(appearance.masksCardSuffix ?? false)
    XCTAssertTrue(appearance.showsNFC ?? false)
}

func test_sanitizedForNonCard_removesEveryCardOnlyValue() {
    let result = AccountAppearance.default.sanitized(for: .cash)
    XCTAssertNil(result.paymentNetwork)
    XCTAssertNil(result.cardTier)
    XCTAssertNil(result.cardholderName)
    XCTAssertNil(result.showsCardholderName)
    XCTAssertNil(result.cardSuffix)
    XCTAssertNil(result.masksCardSuffix)
    XCTAssertNil(result.chipStyle)
    XCTAssertNil(result.showsNFC)
}

func test_normalizedTags_trimsHashDropsEmptyAndDeduplicatesCaseInsensitively() {
    XCTAssertEqual(
        AccountAppearance.normalizedTags([" #Daily-Spend ", "daily-spend", "##Salary", "  "]),
        ["Daily-Spend", "Salary"]
    )
}
```

- [ ] **Step 2: Run the focused model tests and confirm RED**

Run: `cd MyFin && swift test --filter AccountAppearanceTests`

Expected: compilation fails because `AccountAppearance` and its enums do not exist.

- [ ] **Step 3: Implement the typed appearance aggregate**

Create the finite raw-value enums and this aggregate in `AccountAppearance.swift`:

```swift
enum AccountThemePreset: String, Codable, CaseIterable { case obsidianMatte, sapphireWave, emeraldGlass, roseGoldMetallic, titaniumFrost, cyberHologram }
enum AccountAccentTint: String, Codable, CaseIterable { case blue, green, orange, purple, pink, gray }
enum AccountBadgeIcon: String, Codable, CaseIterable { case bank, card, wallet, lock, chart }
enum PaymentNetwork: String, Codable, CaseIterable { case mastercard, visa, kaspiPay, unionPay, virtual }
enum CardTier: String, Codable, CaseIterable { case standard, gold, platinum, worldEliteMetal }
enum ChipStyle: String, Codable, CaseIterable { case goldBrass, silver, dark }

struct AccountAppearance: Equatable {
    var themePreset: AccountThemePreset
    var accentTint: AccountAccentTint
    var badgeIcon: AccountBadgeIcon
    var tags: [String]
    var paymentNetwork: PaymentNetwork?
    var cardTier: CardTier?
    var cardholderName: String?
    var showsCardholderName: Bool?
    var cardSuffix: String?
    var masksCardSuffix: Bool?
    var chipStyle: ChipStyle?
    var showsNFC: Bool?

    static let `default` = AccountAppearance(
        themePreset: .obsidianMatte, accentTint: .blue, badgeIcon: .card, tags: [],
        paymentNetwork: .mastercard, cardTier: .standard, cardholderName: "",
        showsCardholderName: true, cardSuffix: "", masksCardSuffix: true,
        chipStyle: .goldBrass, showsNFC: true
    )

    func sanitized(for type: AccountType) -> AccountAppearance {
        var value = self
        value.tags = Self.normalizedTags(tags)
        guard type != .debitCard else { return value }
        value.paymentNetwork = nil; value.cardTier = nil; value.cardholderName = nil
        value.showsCardholderName = nil; value.cardSuffix = nil; value.masksCardSuffix = nil
        value.chipStyle = nil; value.showsNFC = nil
        return value
    }

    static func normalizedTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmed.drop(while: { $0 == "#" }))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value.lowercased()).inserted else { return nil }
            return value
        }
    }
}
```

Add `var appearance: AccountAppearance = .default` to `Account` so existing test fixtures remain source-compatible.

- [ ] **Step 4: Run the model tests and confirm GREEN**

Run: `cd MyFin && swift test --filter AccountAppearanceTests`

Expected: all three tests pass.

- [ ] **Step 5: Write failing schema-version and column tests**

Update existing version expectations from 5 to 6 and add:

```swift
func test_versionFiveDatabase_migratesAppearanceTable() throws {
    let connection = try makeConnection()
    try connection.execute("DROP TABLE account_appearances;")
    try connection.setUserVersion(5)
    connection.close()

    let migrated = try DatabaseConnection.open(at: dbURL, password: "correct-horse")
    XCTAssertEqual(try migrated.userVersion, 6)
    let columns = try migrated.query("PRAGMA table_info(account_appearances);")
        .compactMap { row -> String? in
            guard case let .text(name)? = row["name"] else { return nil }
            return name
        }
    XCTAssertEqual(Set(columns), Set([
        "account_id", "theme_preset", "accent_tint", "badge_icon", "tags_json",
        "payment_network", "card_tier", "cardholder_name", "shows_cardholder_name",
        "card_suffix", "masks_card_suffix", "chip_style", "shows_nfc"
    ]))
}
```

Extend `test_open_freshDatabase_createsExpectedTables` with `XCTAssertTrue(tables.contains("account_appearances"))`.

- [ ] **Step 6: Run the migration tests and confirm RED**

Run: `cd MyFin && swift test --filter DatabaseServiceTests`

Expected: latest version remains 5 and `account_appearances` is missing.

- [ ] **Step 7: Add migration 6**

Append to `DatabaseService.migrations`:

```swift
MigrationStep(version: 6, statements: [
    """
    CREATE TABLE IF NOT EXISTS account_appearances (
        account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
        theme_preset TEXT NOT NULL,
        accent_tint TEXT NOT NULL,
        badge_icon TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]',
        payment_network TEXT NULL,
        card_tier TEXT NULL,
        cardholder_name TEXT NULL,
        shows_cardholder_name INTEGER NULL,
        card_suffix TEXT NULL,
        masks_card_suffix INTEGER NULL,
        chip_style TEXT NULL,
        shows_nfc INTEGER NULL
    );
    """
])
```

- [ ] **Step 8: Run model and database tests**

Run: `cd MyFin && swift test --filter 'AccountAppearanceTests|DatabaseServiceTests'`

Expected: PASS.

- [ ] **Step 9: Commit the domain and migration**

```bash
git add MyFin/Sources/MyFin/Models/AccountAppearance.swift MyFin/Sources/MyFin/Models/Account.swift MyFin/Sources/MyFin/Services/DatabaseService.swift MyFin/Tests/MyFinTests/AccountAppearanceTests.swift MyFin/Tests/MyFinTests/DatabaseServiceTests.swift
git commit -m "feat: add persisted account appearance schema"
```

---

### Task 2: Persist and reload appearance atomically

**Files:**
- Modify: `MyFin/Sources/MyFin/Services/AccountService.swift`
- Modify: `MyFin/Tests/MyFinTests/AccountServiceTests.swift`

**Interfaces:**
- Consumes: `AccountAppearance.sanitized(for:)` from Task 1.
- Produces: `createAccount(..., appearance: AccountAppearance? = nil) -> Result<Account, AccountError>`.
- Produces: every fetched/listed `Account` has persisted or fallback `appearance`.

- [ ] **Step 1: Write failing round-trip tests**

```swift
func test_createAccount_persistsAndReloadsDebitCardAppearance() throws {
    let (service, _, _) = try makeServices()
    var appearance = AccountAppearance.default
    appearance.themePreset = .cyberHologram
    appearance.accentTint = .pink
    appearance.tags = ["Daily-Spend", "Salary"]
    appearance.paymentNetwork = .visa
    appearance.cardTier = .platinum
    appearance.cardholderName = "YEVGENIY K."
    appearance.cardSuffix = "4829"
    appearance.chipStyle = .silver

    let result = service.createAccount(
        country: .kz, type: .debitCard,
        institutionSelection: .existing(id: "kz.kaspi-bank"), currency: .kzt,
        openingBalance: 142_500, name: "Kaspi Gold", balanceDate: nil,
        appearance: appearance
    )
    guard case .success(let created) = result else { return XCTFail("expected success") }
    let loaded = try XCTUnwrap(service.listAccounts(includeArchived: true).first { $0.id == created.id })
    XCTAssertEqual(loaded.appearance, appearance)
}

func test_createAccount_nonCardPersistsNullCardFields() throws {
    let (service, _, connection) = try makeServices()
    guard case .success(let account) = service.createAccount(
        country: .kz, type: .cash, institutionSelection: .none, currency: .usd,
        openingBalance: 10, name: "Cash", balanceDate: nil,
        appearance: .default
    ) else { return XCTFail("expected success") }
    let row = try XCTUnwrap(connection.query(
        "SELECT * FROM account_appearances WHERE account_id = ?;", params: [.text(account.id)]
    ).first)
    XCTAssertEqual(row["payment_network"], .null)
    XCTAssertEqual(row["card_suffix"], .null)
    XCTAssertEqual(account.appearance.paymentNetwork, nil)
}
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `cd MyFin && swift test --filter AccountServiceTests`

Expected: compilation fails because `createAccount` has no appearance argument and fetched accounts do not decode it.

- [ ] **Step 3: Add encoding, insertion, and fallback decoding**

Add the optional parameter without breaking existing callers:

```swift
func createAccount(
    country: Country, type: AccountType,
    institutionSelection: InstitutionSelection, currency: Currency,
    openingBalance: Decimal, name: String, balanceDate: Date?,
    appearance: AccountAppearance? = nil
) -> Result<Account, AccountError>
```

Resolve `let storedAppearance = (appearance ?? .default).sanitized(for: type)`. Inside the existing transaction, after inserting the account and before commit, encode tags with `JSONEncoder`, then insert all 13 appearance columns using `.int` for booleans and `.null` for absent card values. Return the new account with `appearance: storedAppearance`.

Add private helpers with exact signatures:

```swift
private func insertAppearance(_ appearance: AccountAppearance, accountId: String) throws
private func fetchAppearance(accountId: String) -> AccountAppearance
private static func optionalText(_ row: [String: SQLValue], _ key: String) -> String?
private static func optionalBool(_ row: [String: SQLValue], _ key: String) -> Bool?
```

`fetchAppearance` returns `.default` when no row exists. For present rows it decodes every enum with `Enum(rawValue:) ?? defaultValue`, decodes `tags_json` with `JSONDecoder` or `[]`, and preserves `nil` card columns. Set the appearance on accounts returned by `fetchAccount` and `listAccounts`.

- [ ] **Step 4: Run the service tests and confirm GREEN**

Run: `cd MyFin && swift test --filter AccountServiceTests`

Expected: PASS, including all pre-existing create-account callers through the default argument.

- [ ] **Step 5: Write failing rollback, legacy fallback, corruption fallback, and edit-preservation tests**

```swift
func test_createAccount_rollsBackAccountWhenAppearanceInsertFails() throws {
    let (service, _, connection) = try makeServices()
    try connection.execute("CREATE TRIGGER reject_appearance BEFORE INSERT ON account_appearances BEGIN SELECT RAISE(ABORT, 'reject'); END;")
    let result = service.createAccount(
        country: .kz, type: .cash, institutionSelection: .none, currency: .usd,
        openingBalance: 50, name: "Rollback", balanceDate: nil, appearance: .default
    )
    XCTAssertEqual(result, .failure(.notFound))
    XCTAssertEqual(try connection.query("SELECT * FROM accounts;").count, 0)
    XCTAssertEqual(try connection.query("SELECT * FROM balance_history;").count, 0)
}

func test_accountWithoutAppearanceRow_loadsNeutralDefault() throws {
    let (service, _, connection) = try makeServices()
    guard case .success(let account) = service.createAccount(
        country: .kz, type: .cash, institutionSelection: .none, currency: .usd,
        openingBalance: 0, name: "Legacy", balanceDate: nil
    ) else { return XCTFail("expected success") }
    try connection.execute("DELETE FROM account_appearances WHERE account_id = ?;", params: [.text(account.id)])
    XCTAssertEqual(service.listAccounts(includeArchived: true).first?.appearance, .default)
}

func test_updateAccount_preservesPersistedAppearance() throws {
    let (service, _, _) = try makeServices()
    var appearance = AccountAppearance.default
    appearance.themePreset = .emeraldGlass
    guard case .success(let account) = service.createAccount(
        country: .kz, type: .cash, institutionSelection: .none, currency: .usd,
        openingBalance: 1, name: "Before", balanceDate: nil, appearance: appearance
    ) else { return XCTFail("expected success") }
    _ = service.updateAccount(id: account.id, name: "After", country: .kz, type: .cash,
                              currency: .usd, institutionSelection: .none, openingBalance: 1)
    XCTAssertEqual(service.listAccounts(includeArchived: true).first?.appearance.themePreset, .emeraldGlass)
}
```

Also corrupt `theme_preset` and `tags_json` with direct SQL and assert `.obsidianMatte` plus `[]` after reload.

- [ ] **Step 6: Run the focused tests and confirm RED, then implement missing fallback behavior**

Run: `cd MyFin && swift test --filter AccountServiceTests`

Expected before the fix: at least the fallback/corruption test fails. Implement field-by-field fallback in `fetchAppearance`, then rerun until PASS.

- [ ] **Step 7: Commit service persistence**

```bash
git add MyFin/Sources/MyFin/Services/AccountService.swift MyFin/Tests/MyFinTests/AccountServiceTests.swift
git commit -m "feat: persist account appearance atomically"
```

---

### Task 3: Build the testable wizard draft and localization contract

**Files:**
- Create: `MyFin/Sources/MyFin/Models/AccountCreationDraft.swift`
- Create: `MyFin/Tests/MyFinTests/AccountCreationDraftTests.swift`
- Modify: `MyFin/Sources/MyFin/Localization.swift`
- Modify: `MyFin/Tests/MyFinTests/LocalizationTests.swift`

**Interfaces:**
- Consumes: account and appearance types from Tasks 1–2.
- Produces: `AccountCreationStep`, `AccountCreationValidationError`, and `AccountCreationDraft`.
- Produces: `validateDetails()`, `validateAppearance()`, `parsedBalance`, `displayedCardFields`, and `normalizedAppearance()`.

- [ ] **Step 1: Write failing draft-behavior tests**

```swift
func test_defaults_matchApprovedFirstStep() {
    let draft = AccountCreationDraft()
    XCTAssertEqual(draft.country, .kz)
    XCTAssertEqual(draft.type, .debitCard)
    XCTAssertEqual(draft.currency, .kzt)
    XCTAssertEqual(draft.step, .details)
}

func test_detailsValidation_requiresInstitutionForNonCash() {
    var draft = AccountCreationDraft()
    draft.type = .bankAccount
    draft.institutionSelection = .none
    XCTAssertEqual(draft.validateDetails(), .institutionRequired)
}

func test_detailsValidation_acceptsCashWithoutInstitution() {
    var draft = AccountCreationDraft()
    draft.type = .cash
    draft.institutionSelection = .none
    draft.balanceText = "0"
    XCTAssertNil(draft.validateDetails())
}

func test_appearanceValidation_requiresFourDigitsOnlyForDebitCard() {
    var draft = AccountCreationDraft()
    draft.type = .debitCard
    draft.appearance.cardSuffix = "12A"
    XCTAssertEqual(draft.validateAppearance(), .invalidCardSuffix)
    draft.type = .deposit
    XCTAssertNil(draft.validateAppearance())
}

func test_normalizedAppearance_removesCardFieldsWhenTypeChanges() {
    var draft = AccountCreationDraft()
    draft.type = .cash
    XCTAssertNil(draft.normalizedAppearance().paymentNetwork)
}
```

- [ ] **Step 2: Run the draft tests and confirm RED**

Run: `cd MyFin && swift test --filter AccountCreationDraftTests`

Expected: compilation fails because the draft types do not exist.

- [ ] **Step 3: Implement the draft state and validation**

Use this public shape:

```swift
enum AccountCreationStep { case details, appearance }
enum AccountCreationValidationError: Equatable {
    case invalidBalance, negativeBalance, tooManyDecimalDigits
    case institutionRequired, invalidCustomInstitution, invalidCardSuffix
}

struct AccountCreationDraft {
    var step: AccountCreationStep = .details
    var country: Country = .kz
    var type: AccountType = .debitCard
    var institutionSelection: InstitutionSelection = .none
    var currency: Currency = .kzt
    var balanceText = "0"
    var name = ""
    var specifiesBalanceDate = false
    var balanceDate = Date()
    var appearance: AccountAppearance = .default
    var pendingTag = ""

    var parsedBalance: Decimal? { Decimal(string: balanceText) }
    var displaysCardFields: Bool { type == .debitCard }
    func validateDetails() -> AccountCreationValidationError?
    func validateAppearance() -> AccountCreationValidationError?
    func normalizedAppearance() -> AccountAppearance { appearance.sanitized(for: type) }
}
```

Share the same decimal rules as `AccountService`. A debit-card suffix passes only when `cardSuffix?.count == 4 && cardSuffix?.allSatisfy(\.isNumber) == true`. A `.newCustom` name is trimmed before emptiness validation.

- [ ] **Step 4: Run draft tests and confirm GREEN**

Run: `cd MyFin && swift test --filter AccountCreationDraftTests`

Expected: PASS.

- [ ] **Step 5: Add a failing localization smoke test for the wizard copy**

Add representative assertions while retaining the existing exhaustive parity test:

```swift
func test_newAccountWizard_hasExpectedRussianActions() {
    XCTAssertEqual(Localization.ru[.newAccountTitle], "Новый счёт")
    XCTAssertEqual(Localization.ru[.nextAppearanceButton], "Далее: оформление")
    XCTAssertEqual(Localization.ru[.addAccountButton], "Добавить счёт")
    XCTAssertEqual(Localization.ru[.invalidCardSuffixMessage], "Введите последние 4 цифры карты")
}
```

- [ ] **Step 6: Run localization tests and confirm RED**

Run: `cd MyFin && swift test --filter LocalizationTests`

Expected: compilation fails because the new keys do not exist.

- [ ] **Step 7: Add complete RU/EN wizard localization**

Add `L10nKey` cases and both dictionary entries for: modal title; step labels and status; country/type/institution/account-name/initial-balance headings; live preview and summary labels; back/next/add actions; appearance section headings; every theme/network/tier/chip/badge/tint name; cardholder/suffix/display/masking/NFC controls; tags/add/remove tag; unsupported option help; generic save failure; invalid balance; invalid suffix. Keep the exhaustive key-count test green.

- [ ] **Step 8: Run draft and localization tests**

Run: `cd MyFin && swift test --filter 'AccountCreationDraftTests|LocalizationTests'`

Expected: PASS.

- [ ] **Step 9: Commit draft and localization**

```bash
git add MyFin/Sources/MyFin/Models/AccountCreationDraft.swift MyFin/Sources/MyFin/Localization.swift MyFin/Tests/MyFinTests/AccountCreationDraftTests.swift MyFin/Tests/MyFinTests/LocalizationTests.swift
git commit -m "feat: add new account wizard state"
```

---

### Task 4: Implement the reusable virtual-card renderer

**Files:**
- Create: `MyFin/Sources/MyFin/Views/AccountVirtualCardView.swift`
- Create: `MyFin/Sources/MyFin/Views/AccountAppearanceStyles.swift`
- Create: `MyFin/Tests/MyFinTests/AccountAppearanceStyleTests.swift`

**Interfaces:**
- Consumes: `AccountAppearance`, `AccountType`, currency formatting preferences, and optional institution name.
- Produces: `AccountVirtualCardView(accountName:institutionName:type:currency:balance:appearance:)`.
- Produces: deterministic theme colors, tint colors, SF Symbols, and display labels through pure style mappings.

- [ ] **Step 1: Write failing tests for every style mapping**

```swift
func test_everyThemeHasAThreeStopPalette() {
    for theme in AccountThemePreset.allCases {
        XCTAssertEqual(AccountAppearanceStyles.palette(for: theme).count, 3)
    }
}

func test_everyBadgeHasAnSFSymbol() {
    for badge in AccountBadgeIcon.allCases {
        XCTAssertFalse(AccountAppearanceStyles.symbolName(for: badge).isEmpty)
    }
}

func test_maskedSuffix_matchesMockup() {
    XCTAssertEqual(AccountAppearanceStyles.cardNumber(suffix: "4829", masked: true), "••••  ••••  ••••  4829")
}
```

- [ ] **Step 2: Run style tests and confirm RED**

Run: `cd MyFin && swift test --filter AccountAppearanceStyleTests`

Expected: compilation fails because `AccountAppearanceStyles` does not exist.

- [ ] **Step 3: Implement pure style mappings**

Map all six themes to three dynamic-compatible SwiftUI colors, all six tints to accent colors, all five badges to SF Symbols, networks to compact text/logo treatments, chip styles to metallic palettes, and tiers to localized label keys. Implement `cardNumber(suffix:masked:)` without reading view state.

- [ ] **Step 4: Run style tests and confirm GREEN**

Run: `cd MyFin && swift test --filter AccountAppearanceStyleTests`

Expected: PASS.

- [ ] **Step 5: Implement the reusable card view**

Use this initializer:

```swift
struct AccountVirtualCardView: View {
    let accountName: String
    let institutionName: String?
    let type: AccountType
    let currency: Currency
    let balance: Decimal
    let appearance: AccountAppearance
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack {
            LinearGradient(
                colors: AccountAppearanceStyles.palette(for: appearance.themePreset),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 14) {
                cardHeader
                Spacer(minLength: 0)
                balanceBlock
                cardFooter
            }
            .padding(20)
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AccountAppearanceStyles.color(for: appearance.accentTint), lineWidth: 1)
        }
    }
}
```

Implement the private `cardHeader`, `balanceBlock`, and `cardFooter` builders shown in the composition: institution/type header; conditional contactless glyph; current balance with monospaced digits; conditional chip/network/tier/holder/number for debit cards; account name and badge treatment for non-card accounts. Keep amount text responsive with `.minimumScaleFactor(0.65)`.

- [ ] **Step 6: Build to catch SwiftUI/type errors**

Run: `cd MyFin && swift build`

Expected: build succeeds with no warnings introduced by these files.

- [ ] **Step 7: Commit the renderer**

```bash
git add MyFin/Sources/MyFin/Views/AccountVirtualCardView.swift MyFin/Sources/MyFin/Views/AccountAppearanceStyles.swift MyFin/Tests/MyFinTests/AccountAppearanceStyleTests.swift
git commit -m "feat: add reusable virtual account card"
```

---

### Task 5: Build and route the two-step creation wizard

**Files:**
- Create: `MyFin/Sources/MyFin/Views/NewAccountWizardView.swift`
- Create: `MyFin/Sources/MyFin/Views/NewAccountDetailsStepView.swift`
- Create: `MyFin/Sources/MyFin/Views/NewAccountAppearanceStepView.swift`
- Create: `MyFin/Sources/MyFin/Views/AccountAppearanceControls.swift`
- Modify: `MyFin/Sources/MyFin/Views/MainShellView.swift`

**Interfaces:**
- Consumes: `AccountCreationDraft`, `AccountVirtualCardView`, `BankPickerView`, and `AccountService.createAccount(...appearance:)`.
- Produces: `NewAccountWizardView(session:onSaved:)` used only by the create sheet.
- Preserves: `AccountFormView` for existing-account edit and reconcile entry points.

- [ ] **Step 1: Add a compile-time routing seam before constructing the views**

Change only the create sheet in `MainShellView`:

```swift
.sheet(isPresented: $showingCreateAccount, onDismiss: { accountsModel.reload() }) {
    NewAccountWizardView(session: session) {
        accountsModel.reload()
    }
}
```

Leave `.sheet(item: $editingAccount)` calling `AccountFormView` exactly as it does now. Build once to confirm the expected RED compile failure for missing `NewAccountWizardView`.

Run: `cd MyFin && swift build`

Expected: failure naming missing `NewAccountWizardView`.

- [ ] **Step 2: Implement the wizard container and save boundary**

Use this outer contract:

```swift
struct NewAccountWizardView: View {
    let session: AppSession
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: AppPreferences
    @State private var draft = AccountCreationDraft()
    @State private var error: AccountCreationValidationError?
}
```

The container renders a 920×680 two-column macOS sheet, title row, two-state stepper, content, and footer. Next calls `validateDetails`, Back changes only `draft.step`, and Add Account calls `validateAppearance` followed by `AccountService.createAccount` with `draft.normalizedAppearance()`. On success call `onSaved()` and dismiss; on failure retain state and show the mapped localized error.

- [ ] **Step 3: Implement Step 1 from the first supplied screenshot**

`NewAccountDetailsStepView` receives `@Binding var draft`, the institution service, and optional validation error. Implement the six-tile type grid with four active enum-backed buttons and two disabled tiles; reset institution selection on country changes and when switching to cash. Show quick institution chips from the first three current-country catalog entries and reuse the full existing picker for the remaining/custom choices. Combine balance and currency into one bordered row, retain optional balance date, and render `AccountVirtualCardView` plus four-row summary in the right column.

- [ ] **Step 4: Implement Step 2 from the second supplied screenshot**

`NewAccountAppearanceStepView` receives `@Binding var draft` and uses `AccountAppearanceControls` for six theme cards, six tint dots, five network cards, four tier segments, cardholder/suffix fields and toggles, three chip styles, NFC, five badge icons, and editable tag chips. Wrap card-only groups in `if draft.displaysCardFields`. Render the same reusable card and specification summary in the right column.

- [ ] **Step 5: Build the complete wizard**

Run: `cd MyFin && swift build`

Expected: PASS.

- [ ] **Step 6: Run all draft, service, localization, and style tests**

Run: `cd MyFin && swift test --filter 'AccountCreationDraftTests|AccountServiceTests|LocalizationTests|AccountAppearanceStyleTests'`

Expected: PASS.

- [ ] **Step 7: Commit the creation UI**

```bash
git add MyFin/Sources/MyFin/Views/NewAccountWizardView.swift MyFin/Sources/MyFin/Views/NewAccountDetailsStepView.swift MyFin/Sources/MyFin/Views/NewAccountAppearanceStepView.swift MyFin/Sources/MyFin/Views/AccountAppearanceControls.swift MyFin/Sources/MyFin/Views/MainShellView.swift
git commit -m "feat: add two-step account creation wizard"
```

---

### Task 6: Show persisted appearance in the existing details/history inspector

**Files:**
- Modify: `MyFin/Sources/MyFin/Views/BalanceHistoryPanelView.swift`
- Create: `MyFin/Sources/MyFin/Views/AccountSpecificationView.swift`
- Modify: `MyFin/Tests/MyFinTests/AccountAppearanceStyleTests.swift`

**Interfaces:**
- Consumes: `account.appearance` loaded by `AccountService` and `AccountVirtualCardView` from Task 4.
- Produces: a compact localized specifications block in the existing inspector.

- [ ] **Step 1: Write failing specification-row tests against a pure builder**

```swift
func test_nonCardSpecificationsOmitNetworkAndTier() {
    let rows = AccountSpecification.rows(
        type: .cash, institution: nil, appearance: .default.sanitized(for: .cash)
    )
    XCTAssertFalse(rows.contains { $0.kind == .paymentNetwork })
    XCTAssertFalse(rows.contains { $0.kind == .cardTier })
}

func test_debitCardSpecificationsIncludeSavedNetworkAndTier() {
    let rows = AccountSpecification.rows(
        type: .debitCard, institution: "Kaspi Bank", appearance: .default
    )
    XCTAssertTrue(rows.contains { $0.kind == .paymentNetwork })
    XCTAssertTrue(rows.contains { $0.kind == .cardTier })
}
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `cd MyFin && swift test --filter AccountAppearanceStyleTests`

Expected: compilation fails because `AccountSpecification` does not exist.

- [ ] **Step 3: Implement specification data and view**

Define `AccountSpecification.Row.Kind`, `Row`, and `rows(type:institution:appearance:)` in `AccountSpecificationView.swift`. Common rows include institution/cash, account type, theme, accent, badge, and tags. Debit-card rows additionally include network, tier, chip, NFC, holder visibility, and masked suffix. `AccountSpecificationView` localizes keys and lays the rows out as a compact card surface.

- [ ] **Step 4: Replace the inspector's hard-coded gradient account card**

In `BalanceHistoryPanelView`, replace `accountCard` with:

```swift
VStack(alignment: .leading, spacing: 12) {
    AccountVirtualCardView(
        accountName: account.name, institutionName: institution, type: account.type,
        currency: account.currency, balance: account.openingBalance,
        appearance: account.appearance
    )
    AccountSpecificationView(type: account.type, institution: institution, appearance: account.appearance)
}
```

Keep the existing history card, legacy-currency note, footer, edit action, reconcile action, reload behavior, and inspector width.

- [ ] **Step 5: Run focused tests and build**

Run: `cd MyFin && swift test --filter AccountAppearanceStyleTests`

Run: `cd MyFin && swift build`

Expected: both PASS.

- [ ] **Step 6: Commit inspector integration**

```bash
git add MyFin/Sources/MyFin/Views/BalanceHistoryPanelView.swift MyFin/Sources/MyFin/Views/AccountSpecificationView.swift MyFin/Tests/MyFinTests/AccountAppearanceStyleTests.swift
git commit -m "feat: show account appearance in details inspector"
```

---

### Task 7: Full regression and visual verification

**Files:**
- Modify only files implicated by concrete failures found in this task.

**Interfaces:**
- Verifies every interface produced by Tasks 1–6.

- [ ] **Step 1: Run the complete test suite**

Run: `cd MyFin && swift test`

Expected: all tests pass with zero failures.

- [ ] **Step 2: Run a clean debug build**

Run: `cd MyFin && swift package clean && swift build`

Expected: build completes successfully without new warnings.

- [ ] **Step 3: Launch and visually verify the new flow**

Run: `cd MyFin && swift run MyFin`

Check in light mode:

1. Create opens the two-step wizard while Edit and Reconcile still open the legacy form.
2. Step 1 matches `docs/design/new_account_modal/stitch_macos_native_sidebar_redesign/screen.png`, responds live, validates missing bank/invalid balance, and retains the optional balance date.
3. Step 2 matches `docs/design/new_account_modal/stitch_macos_native_sidebar_redesign (1)/screen.png` for a debit card.
4. Cash, bank account, and deposit hide all network/tier/holder/suffix/chip/NFC controls.
5. Back/Next preserve the entire draft; Cancel discards it.
6. Saving then reopening the app preserves every selection.
7. The accounts inspector shows the themed card and correct specifications above unchanged history content.
8. Dashboard and list layout remain unchanged.

- [ ] **Step 4: Check dynamic appearance and compact inspector behavior**

Switch the app to dark mode and verify readable text, borders, disabled states, focus rings, and all six themes. Resize the inspector from 330 to 440 points and confirm the 1.586:1 card scales without clipping.

- [ ] **Step 5: Re-run checks after any visual corrections**

Run: `cd MyFin && swift test && swift build`

Expected: PASS after the final visual-only adjustment.

- [ ] **Step 6: Review the final diff for scope and whitespace**

Run: `git diff --check`

Run: `git status --short`

Confirm only the planned model, migration, service, localization, wizard, renderer, inspector, and test files changed; preserve every unrelated pre-existing working-tree edit.

- [ ] **Step 7: Commit final verification corrections if any**

```bash
git add MyFin/Sources/MyFin MyFin/Tests/MyFinTests
git commit -m "fix: polish new account wizard presentation"
```

Skip this commit when Step 3–4 required no corrective changes.
