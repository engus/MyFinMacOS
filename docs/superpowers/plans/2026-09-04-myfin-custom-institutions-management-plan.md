# Custom Institutions Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the user a "Банки" tab in Settings to see every custom institution they've created (across all countries) and add, rename, change the country of, archive, and restore them.

**Architecture:** Add one read method (`InstitutionService.listCustomInstitutions(includeArchived:)`) — every write operation this feature needs already exists on `InstitutionService`. Add two new SwiftUI files mirroring the existing `AccountsListView`/`AccountFormView` pair exactly: `CustomInstitutionsView` (list) and `CustomInstitutionFormView` (one sheet for both add and edit). Restructure `SettingsView` with a segmented `Picker` at the top so its existing `Form` becomes the "Общее" tab and the new view becomes the "Банки" tab.

**Tech Stack:** Swift 5.9, SwiftUI, SQLCipher.swift, XCTest, Swift Package Manager (no Xcode project).

**Spec:** `docs/superpowers/specs/2026-09-04-myfin-custom-institutions-management-design.md`

## Global Constraints

- **No git** in this project (neither `MyFinLocal/` nor `MyFinLocal/MyFin/` is a git repository) — never run `git` commands; every "Commit" step below is skipped, left in the template only where the plan format requires it.
- **Swift toolchain is available and verified working in this environment** — run every `swift build` / `swift test` step yourself, directly via Bash, from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`. Only the manual UI walkthrough steps (explicitly marked "Hand to human partner") need the human, since driving the running macOS GUI app is not something you can do yourself.
- "Delete" means archive everywhere in this app — there is no hard delete anywhere, this feature doesn't add one either.
- The spec's file-structure note said the list view and form view could "share a file" like `AccountsListView.swift` shares a file with its private `AccountRowView` — on reflection while writing this plan, the closer and more consistent precedent is that **list and form live in separate files**, exactly like `AccountsListView.swift` (list + private row) and `AccountFormView.swift` (form) already do today. This plan follows that: `CustomInstitutionsView.swift` (list + private row) and `CustomInstitutionFormView.swift` (form) are two separate files.
- `@State` for any view that edits an optional existing model must be seeded via a custom `init(...)`, never via `.onAppear` — this is the established fix from this session's `AccountFormView` bugfix (assigning `@State` in `.onAppear` creates a spurious first "change" that breaks any `.onChange` watching that property). `CustomInstitutionFormView` follows this from the start.
- No automated tests exist anywhere in this codebase for a SwiftUI `View` type — this plan doesn't add any either; the three new/changed views (`CustomInstitutionFormView`, `CustomInstitutionsView`, `SettingsView`) are verified by `swift build` (compiles) plus a manual walkthrough.

## File Structure

- Modify: `Sources/MyFin/Localization.swift` — 6 new `L10nKey` cases + ru/en entries (Task 1).
- Modify: `Tests/MyFinTests/LocalizationTests.swift` — value assertions for the 6 new keys (Task 1).
- Modify: `Sources/MyFin/Services/InstitutionService.swift` — add `listCustomInstitutions(includeArchived:)` (Task 2).
- Modify: `Tests/MyFinTests/InstitutionServiceTests.swift` — tests for the new method (Task 2).
- Create: `Sources/MyFin/Views/CustomInstitutionFormView.swift` — add/edit sheet (Task 3).
- Create: `Sources/MyFin/Views/CustomInstitutionsView.swift` — list + row (Task 4).
- Modify: `Sources/MyFin/Views/SettingsView.swift` — segmented tabs, wire in `CustomInstitutionsView` (Task 5).

---

### Task 1: Localization — 6 new keys

**Files:**
- Modify: `Sources/MyFin/Localization.swift`
- Test: `Tests/MyFinTests/LocalizationTests.swift`

**Interfaces:**
- Produces (for Tasks 3–5): `L10nKey` cases `.settingsTabGeneral`, `.settingsTabInstitutions`, `.addCustomInstitutionButton`, `.noCustomInstitutionsYet`, `.institutionInUseMessage`, `.institutionArchivedConflictMessage`.

- [x] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/LocalizationTests.swift`, inside `LocalizationTests`:

```swift
func test_settingsTabGeneral_ru_isObshee() {
    XCTAssertEqual(Localization.ru[.settingsTabGeneral], "Общее")
}

func test_settingsTabInstitutions_ru_isBanki() {
    XCTAssertEqual(Localization.ru[.settingsTabInstitutions], "Банки")
}

func test_addCustomInstitutionButton_ru_isDobavitBank() {
    XCTAssertEqual(Localization.ru[.addCustomInstitutionButton], "Добавить банк")
}

func test_noCustomInstitutionsYet_ru_matchesExpectedCopy() {
    XCTAssertEqual(Localization.ru[.noCustomInstitutionsYet], "Пока нет добавленных банков")
}

func test_institutionInUseMessage_ru_matchesExpectedCopy() {
    XCTAssertEqual(Localization.ru[.institutionInUseMessage], "Нельзя сменить страну — банк уже используется в счетах")
}

func test_institutionArchivedConflictMessage_ru_matchesExpectedCopy() {
    XCTAssertEqual(Localization.ru[.institutionArchivedConflictMessage], "Банк с таким названием уже существует в архиве — восстановите его из списка")
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.LocalizationTests`
Expected: build failure — the 6 new `L10nKey` cases referenced by these tests don't exist yet.

- [x] **Step 3: Add the new keys**

In `Sources/MyFin/Localization.swift`, add to the `L10nKey` enum (anywhere in the case list, e.g. right after `.baseCurrencyPickerLabel`):

```swift
    case settingsTabGeneral
    case settingsTabInstitutions
    case addCustomInstitutionButton
    case noCustomInstitutionsYet
    case institutionInUseMessage
    case institutionArchivedConflictMessage
```

Add to the `ru` dictionary (anywhere, e.g. right after `.baseCurrencyPickerLabel: "Валюта отображения",`):

```swift
        .settingsTabGeneral: "Общее",
        .settingsTabInstitutions: "Банки",
        .addCustomInstitutionButton: "Добавить банк",
        .noCustomInstitutionsYet: "Пока нет добавленных банков",
        .institutionInUseMessage: "Нельзя сменить страну — банк уже используется в счетах",
        .institutionArchivedConflictMessage: "Банк с таким названием уже существует в архиве — восстановите его из списка",
```

Add to the `en` dictionary (same position, mirroring the `ru` block above):

```swift
        .settingsTabGeneral: "General",
        .settingsTabInstitutions: "Banks",
        .addCustomInstitutionButton: "Add bank",
        .noCustomInstitutionsYet: "No custom banks yet",
        .institutionInUseMessage: "Can't change country — this bank is already used by an account",
        .institutionArchivedConflictMessage: "A bank with this name already exists, archived — restore it from the list instead",
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.LocalizationTests`
Expected: all `LocalizationTests` pass (the 2 original generic tests + the 3 from the previous sidebar plan + these 6 new ones = 11 total), including the generic `test_ru_and_en_haveTheSameKeyCount` / `test_everyKey_hasNonEmptyRussianAndEnglishTranslation`.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 97 previously-passing tests still pass, plus the 6 new ones (103 total).

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 2: `InstitutionService.listCustomInstitutions(includeArchived:)`

**Files:**
- Modify: `Sources/MyFin/Services/InstitutionService.swift`
- Test: `Tests/MyFinTests/InstitutionServiceTests.swift`

**Interfaces:**
- Consumes: existing `InstitutionService(connection:)`, existing `resolveOrCreateCustomInstitution(name:country:) -> Result<Institution, InstitutionError>`, existing `archiveCustomInstitution(id:) -> Result<Institution, InstitutionError>`, existing `Institution` (has `id: String`, `name: String`, `country: Country`).
- Produces (for Tasks 3–4): `InstitutionService.listCustomInstitutions(includeArchived: Bool) -> [Institution]`.

- [x] **Step 1: Write the failing tests**

Add to `Tests/MyFinTests/InstitutionServiceTests.swift`, inside `InstitutionServiceTests`:

```swift
func test_listCustomInstitutions_excludesSystemInstitutions() throws {
    let (service, _) = try makeService()
    _ = service.resolveOrCreateCustomInstitution(name: "My Custom Bank", country: .kz)

    let customOnly = service.listCustomInstitutions(includeArchived: true)

    XCTAssertFalse(customOnly.contains { $0.id == "kz.halyk-bank" })
    XCTAssertTrue(customOnly.contains { $0.name == "My Custom Bank" })
}

func test_listCustomInstitutions_excludesArchivedByDefault() throws {
    let (service, _) = try makeService()
    guard case .success(let institution) = service.resolveOrCreateCustomInstitution(name: "Archived Bank", country: .kz) else {
        return XCTFail("expected success")
    }
    _ = service.archiveCustomInstitution(id: institution.id)

    XCTAssertFalse(service.listCustomInstitutions(includeArchived: false).contains { $0.id == institution.id })
    XCTAssertTrue(service.listCustomInstitutions(includeArchived: true).contains { $0.id == institution.id })
}

func test_listCustomInstitutions_spansMultipleCountries() throws {
    let (service, _) = try makeService()
    _ = service.resolveOrCreateCustomInstitution(name: "KZ Custom Bank", country: .kz)
    _ = service.resolveOrCreateCustomInstitution(name: "US Custom Bank", country: .us)

    let names = Set(service.listCustomInstitutions(includeArchived: true).map(\.name))

    XCTAssertTrue(names.isSuperset(of: ["KZ Custom Bank", "US Custom Bank"]))
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.InstitutionServiceTests`
Expected: build failure — `listCustomInstitutions` does not exist yet.

- [x] **Step 3: Add the method**

In `Sources/MyFin/Services/InstitutionService.swift`, add inside the `extension InstitutionService { ... }` block (anywhere, e.g. right before `private func fetchInstitution(id:)`):

```swift
    func listCustomInstitutions(includeArchived: Bool) -> [Institution] {
        let sql = includeArchived
            ? "SELECT * FROM institutions WHERE source = 'custom' ORDER BY country ASC, name ASC;"
            : "SELECT * FROM institutions WHERE source = 'custom' AND archived = 0 ORDER BY country ASC, name ASC;"
        let rows = (try? connection.query(sql)) ?? []
        return rows.compactMap(Self.rowToInstitution)
    }
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.InstitutionServiceTests`
Expected: all `InstitutionServiceTests` pass, including the 3 new ones.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: 103 + 3 = 106 tests pass, 0 failures.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 3: `CustomInstitutionFormView` — add/edit sheet

**Files:**
- Create: `Sources/MyFin/Views/CustomInstitutionFormView.swift`

**Interfaces:**
- Consumes: `AppSession.connection: DatabaseConnection?` (existing), `InstitutionService(connection:)` (existing), `InstitutionService.resolveOrCreateCustomInstitution(name:country:)`, `.renameCustomInstitution(id:name:)`, `.changeCustomInstitutionCountry(id:country:)` (all existing), `Institution` (existing), `InstitutionError` cases `.invalidName`, `.inUse`, `.conflictWithArchived`, `.systemInstitutionIsReadOnly`, `.notFound` (existing), `L10nKey` cases from Task 1 plus existing `.countryFieldLabel`, `.customBankNameField`, `.cancelButton`, `.saveButton`, `.invalidCustomBankNameMessage`.
- Produces (for Task 4): `CustomInstitutionFormView(session: AppSession, existingInstitution: Institution?)` — a `View`.

This view has no call site until Task 4, so there is nothing to click through yet; verification here is a successful build only.

- [x] **Step 1: Create the file**

Create `Sources/MyFin/Views/CustomInstitutionFormView.swift`:

```swift
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
                ForEach(Country.allCases, id: \.self) { Text($0.displayName).tag($0) }
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
```

- [x] **Step 2: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 3: Run the full test suite**

Run: `swift test`
Expected: all 106 tests still pass (this file adds no tests of its own, per Global Constraints — no View is unit-tested in this codebase).

- [x] **Step 4: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 4: `CustomInstitutionsView` — list + row

**Files:**
- Create: `Sources/MyFin/Views/CustomInstitutionsView.swift`

**Interfaces:**
- Consumes: `AccountsListModel`-style pattern is NOT used here (see Global Constraints — no shared model needed, this list has no sibling consumer); `AppSession.connection` (existing), `InstitutionService.listCustomInstitutions(includeArchived:)` (Task 2), `.archiveCustomInstitution(id:)` / `.restoreCustomInstitution(id:)` (existing), `Institution` (existing, `Identifiable` via `id: String`), `CustomInstitutionFormView(session:existingInstitution:)` (Task 3), `L10nKey` cases `.showArchivedToggle`, `.addCustomInstitutionButton` (Task 1), `.noCustomInstitutionsYet` (Task 1), `.editButton`, `.archiveButton`, `.restoreButton`, `.activeStatusLabel`, `.archivedStatusLabel` (all existing).
- Produces (for Task 5): `CustomInstitutionsView(session: AppSession)` — a `View`.

- [x] **Step 1: Create the file**

Create `Sources/MyFin/Views/CustomInstitutionsView.swift`:

```swift
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
            VStack(alignment: .leading) {
                Text(institution.name).font(.headline)
                Text(institution.country.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(institution.archived ? preferences.string(.archivedStatusLabel) : preferences.string(.activeStatusLabel))
                .foregroundStyle(institution.archived ? Color.secondary : Color.green)
            Button(preferences.string(.editButton), action: onEdit)
            Button(institution.archived ? preferences.string(.restoreButton) : preferences.string(.archiveButton), action: onToggleArchive)
        }
    }
}
```

- [x] **Step 2: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 3: Run the full test suite**

Run: `swift test`
Expected: all 106 tests still pass.

- [x] **Step 4: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 5: Wire `CustomInstitutionsView` into `SettingsView` as a real tab

**Files:**
- Modify: `Sources/MyFin/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `CustomInstitutionsView(session:)` (Task 4), `L10nKey` cases `.settingsTabGeneral`, `.settingsTabInstitutions` (Task 1).
- Produces: none — this is the final task in this plan.

- [x] **Step 1: Replace the full contents of `SettingsView.swift`**

Replace the full contents of `Sources/MyFin/Views/SettingsView.swift`:

```swift
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case institutions

    var id: String { rawValue }
}

struct SettingsView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @State private var selectedTab: SettingsTab = .general

    @State private var editedName: String = ""
    @State private var editedIconName: String = Profile.defaultIconName
    @State private var editedIconColor: String = Profile.defaultIconColor
    @State private var didUpdateProfile = false

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var localError: String?
    @State private var didChangePassword = false
    @State private var showingDeleteProfile = false
    @State private var baseCurrency: Currency = .usd

    private let iconColumns = [GridItem(.adaptive(minimum: 40))]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text(preferences.string(.settingsTabGeneral)).tag(SettingsTab.general)
                Text(preferences.string(.settingsTabInstitutions)).tag(SettingsTab.institutions)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 24)

            switch selectedTab {
            case .general:
                Form {
                    Section(preferences.string(.profileSectionTitle)) {
                        TextField(preferences.string(.profileNameField), text: $editedName)

                        Text(preferences.string(.iconLabel)).font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: iconColumns, spacing: 8) {
                            ForEach(ProfileIconPalette.iconNames, id: \.self) { icon in
                                Button {
                                    editedIconName = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundStyle(ProfileIconPalette.color(named: editedIconColor))
                                        .padding(6)
                                        .background(
                                            Circle().stroke(icon == editedIconName ? ProfileIconPalette.color(named: editedIconColor) : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(preferences.string(.colorLabel)).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            ForEach(ProfileIconPalette.colorNames, id: \.self) { colorName in
                                Button {
                                    editedIconColor = colorName
                                } label: {
                                    Circle()
                                        .fill(ProfileIconPalette.color(named: colorName))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle().stroke(Color.primary, lineWidth: colorName == editedIconColor ? 2 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if didUpdateProfile {
                            Text(preferences.string(.profileUpdatedMessage)).foregroundStyle(.green)
                        }

                        Button(preferences.string(.saveButton)) { saveProfile() }
                            .disabled(editedName.isEmpty)
                    }

                    Section(preferences.string(.changePasswordSectionTitle)) {
                        RevealableSecureField(title: preferences.string(.currentPasswordField), text: $currentPassword)
                        RevealableSecureField(title: preferences.string(.newPasswordField), text: $newPassword)
                        RevealableSecureField(title: preferences.string(.confirmNewPasswordField), text: $confirmNewPassword)
                        if let localError {
                            Text(localError).foregroundStyle(.red)
                        }
                        if didChangePassword {
                            Text(preferences.string(.passwordChangedMessage)).foregroundStyle(.green)
                        }
                        Button(preferences.string(.changePasswordButton)) { changePassword() }
                            .disabled(currentPassword.isEmpty || newPassword.isEmpty)
                    }

                    Section(preferences.string(.appearanceSectionTitle)) {
                        PreferencesControls()
                    }

                    Section(preferences.string(.baseCurrencySectionTitle)) {
                        Picker(preferences.string(.baseCurrencyPickerLabel), selection: $baseCurrency) {
                            ForEach(Currency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .onChange(of: baseCurrency) { newValue in
                            guard let connection = session.connection else { return }
                            let institutions = InstitutionService(connection: connection)
                            let accounts = AccountService(connection: connection, institutionService: institutions)
                            let dashboard = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider())
                            try? dashboard.setBaseCurrency(newValue)
                        }
                    }

                    Section {
                        Button(preferences.string(.logOutButton), role: .destructive) {
                            session.logOut()
                        }
                    }

                    Section {
                        Button(preferences.string(.deleteButton), role: .destructive) {
                            showingDeleteProfile = true
                        }
                    }
                }
                .padding(24)
            case .institutions:
                CustomInstitutionsView(session: session)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            editedName = session.unlockedProfile?.displayName ?? ""
            editedIconName = session.unlockedProfile?.iconName ?? Profile.defaultIconName
            editedIconColor = session.unlockedProfile?.iconColor ?? Profile.defaultIconColor
            if let connection = session.connection {
                let institutions = InstitutionService(connection: connection)
                let accounts = AccountService(connection: connection, institutionService: institutions)
                baseCurrency = DashboardService(connection: connection, accountService: accounts, exchangeRateProvider: HardcodedExchangeRateProvider()).baseCurrency()
            }
        }
        .sheet(isPresented: $showingDeleteProfile) {
            DeleteProfileView(session: session)
        }
    }

    private func saveProfile() {
        session.updateProfile(displayName: editedName, iconName: editedIconName, iconColor: editedIconColor)
        didUpdateProfile = (session.errorMessage == nil)
    }

    private func changePassword() {
        guard newPassword == confirmNewPassword else {
            localError = preferences.string(.passwordsDoNotMatch)
            didChangePassword = false
            return
        }
        session.changePassword(currentPassword: currentPassword, newPassword: newPassword)
        localError = session.errorMessage
        didChangePassword = (session.errorMessage == nil)
        currentPassword = ""
        newPassword = ""
        confirmNewPassword = ""
    }
}
```

(Every line inside the `.general` case is character-for-character the same `Form` content that existed before this task — only the surrounding `VStack`/`Picker`/`switch` and the new `.institutions` case are new.)

- [x] **Step 2: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 3: Run the full test suite**

Run: `swift test`
Expected: all 106 tests still pass.

- [ ] **Step 4: Manual UI walkthrough**

Hand to human partner. Run: `swift run` from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`
Ask them to: open Settings, confirm a segmented control now reads "Общее" / "Банки" at the top; confirm "Общее" looks and behaves exactly as before (profile, password, appearance, base currency, log out, delete profile); switch to "Банки"; click "Добавить банк", pick a country and name, save, confirm it appears in the list; click "Изменить" on it, change its name and/or country, save, confirm the list reflects it; click "Архивировать", confirm it disappears from the default view and reappears when "Показать архивные" is toggled on; click "Восстановить" to bring it back. Then create an account using that custom bank (via the "Другой банк" flow while creating an account), and confirm that changing that bank's country from the "Банки" tab while it's in use is now rejected with the "Нельзя сменить страну…" message instead of silently succeeding.
Expected: everything above behaves as described. Confirm with the user.

- [x] **Step 5: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Self-Review Notes

- **Spec coverage:** Section 1 (service method) → Task 2. Section 2 (Settings tabs) → Task 5. Section 3 (list view + form view) → Tasks 3–4. New localization keys → Task 1. "Out of scope" items (no hard delete, no bulk actions, no change to the account-creation bank picker, tab selection not persisted) are respected — nothing in Tasks 1–5 touches `BankPickerView`/`AccountFormView`, and `selectedTab` has no persistence mechanism.
- **No placeholders:** every step has complete, runnable code.
- **Type/name consistency checked:** `CustomInstitutionFormView(session:existingInstitution:)` (Task 3) is called with those exact argument labels in Task 4's two `.sheet` closures; `CustomInstitutionsView(session:)` (Task 4) is called with that exact label in Task 5; `listCustomInstitutions(includeArchived:)` (Task 2) is called identically in Task 4's `reload()`; all 6 new `L10nKey` cases (Task 1) are referenced by their exact names in Tasks 3–5.
- **File-layout deviation from the spec's wording, resolved here:** documented under Global Constraints — list and form get separate files (matching `AccountsListView.swift`/`AccountFormView.swift`), not one shared file as the spec's phrasing loosely suggested.
