# Bank Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a small colored bank icon next to each institution in the "Банки" tab and the sidebar's per-bank grouped rows, with one generic icon for every bank and an explicit, hardcoded (never computed/randomized) color per bank.

**Architecture:** Add a `color: String` field to every entry in the existing static `SystemInstitutionCatalog`, plus a `color(forID:)` lookup and a shared `institutionIconName` constant — no database changes. Wire both display sites onto that lookup, falling back to a fixed default color for custom institutions (which are never in the static catalog).

**Tech Stack:** Swift 5.9, SwiftUI, Swift Package Manager (no Xcode project).

**Spec:** `docs/superpowers/specs/2026-09-04-myfin-bank-icons-design.md`

## Global Constraints

- **No git** in this project (neither `MyFinLocal/` nor `MyFinLocal/MyFin/` is a git repository) — never run `git` commands; every "Commit" step below is skipped, left in the template only where the plan format requires it.
- **Swift toolchain is available and verified working in this environment** — run every `swift build` / `swift test` step yourself, directly via Bash, from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`. Only the manual look-at-the-running-app step (explicitly marked "Hand to human partner") needs the human.
- **No database changes** — colors are looked up from the static `SystemInstitutionCatalog` at display time; the `institutions` table and `InstitutionService` are untouched.
- **Colors are explicit literals, never computed** (no hashing, no per-launch randomization) — every value in this plan is a fixed string, exactly as the user required.
- Custom institutions (never in the static catalog) always render with the fixed fallback color `"blue"` — no per-custom-bank variation yet.
- No icon on the sidebar's "Наличные" (cash) row, and no new tests for `CustomInstitutionsView`/`MainShellView` themselves — consistent with this codebase's existing convention of zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## File Structure

- Modify: `Sources/MyFin/Models/SystemInstitutionCatalog.swift` — `color` field on every entry, `color(forID:)`, `institutionIconName` (Task 1).
- Test: `Tests/MyFinTests/SystemInstitutionCatalogTests.swift` (new file, Task 1).
- Modify: `Sources/MyFin/Views/CustomInstitutionsView.swift` — icon on `CustomInstitutionRowView` (Task 2).
- Modify: `Sources/MyFin/Views/MainShellView.swift` — icon on the sidebar's per-bank grouped row (Task 2).

---

### Task 1: `SystemInstitutionCatalog` colors + icon constant

**Files:**
- Modify: `Sources/MyFin/Models/SystemInstitutionCatalog.swift`
- Test: `Tests/MyFinTests/SystemInstitutionCatalogTests.swift`

**Interfaces:**
- Consumes: existing `ProfileIconPalette.colorNames: [String]` (`["blue", "green", "orange", "pink", "purple", "red", "teal", "yellow"]`).
- Produces (for Task 2): `SystemInstitutionCatalog.Entry.color: String` (new field), `SystemInstitutionCatalog.color(forID: String) -> String?`, `SystemInstitutionCatalog.institutionIconName: String` (`"building.columns.fill"`).

- [x] **Step 1: Write the failing tests**

Create `Tests/MyFinTests/SystemInstitutionCatalogTests.swift`:

```swift
import XCTest
@testable import MyFin

final class SystemInstitutionCatalogTests: XCTestCase {
    func test_everyEntry_hasAColorFromTheProfilePalette() {
        for entry in SystemInstitutionCatalog.all {
            XCTAssertTrue(
                ProfileIconPalette.colorNames.contains(entry.color),
                "\(entry.id) has color \(entry.color), not in ProfileIconPalette.colorNames"
            )
        }
    }

    func test_color_forKnownID_returnsThatEntrysColor() {
        XCTAssertEqual(SystemInstitutionCatalog.color(forID: "kz.halyk-bank"), "blue")
        XCTAssertEqual(SystemInstitutionCatalog.color(forID: "kz.kaspi-bank"), "green")
    }

    func test_color_forUnknownID_returnsNil() {
        XCTAssertNil(SystemInstitutionCatalog.color(forID: "not-a-real-institution-id"))
    }

    func test_institutionIconName_isBuildingColumns() {
        XCTAssertEqual(SystemInstitutionCatalog.institutionIconName, "building.columns.fill")
    }
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MyFinTests.SystemInstitutionCatalogTests`
Expected: build failure — `Entry` has no `color` member yet, and `SystemInstitutionCatalog` has no `color(forID:)`/`institutionIconName`.

- [x] **Step 3: Replace the full contents of `SystemInstitutionCatalog.swift`**

Replace the full contents of `Sources/MyFin/Models/SystemInstitutionCatalog.swift`:

```swift
import Foundation

enum SystemInstitutionCatalog {
    struct Entry {
        let id: String
        let country: Country
        let name: String
        let aliases: [String]
        let color: String
    }

    static let institutionIconName = "building.columns.fill"

    static func color(forID id: String) -> String? {
        all.first { $0.id == id }?.color
    }

    static let all: [Entry] = [
        // KZ — Kazakhstan
        Entry(id: "kz.halyk-bank", country: .kz, name: "Halyk Bank", aliases: ["Halyk", "Народный банк"], color: "blue"),
        Entry(id: "kz.kaspi-bank", country: .kz, name: "Kaspi Bank", aliases: ["Kaspi", "Kaspi.kz"], color: "green"),
        Entry(id: "kz.bank-centercredit", country: .kz, name: "Bank CenterCredit", aliases: ["BCC", "ЦентрКредит"], color: "orange"),
        Entry(id: "kz.fortebank", country: .kz, name: "ForteBank", aliases: ["Forte"], color: "pink"),
        Entry(id: "kz.freedom-bank-kazakhstan", country: .kz, name: "Freedom Bank Kazakhstan", aliases: ["Freedom", "Фридом"], color: "purple"),
        Entry(id: "kz.eurasian-bank", country: .kz, name: "Eurasian Bank", aliases: ["Евразийский банк"], color: "red"),
        Entry(id: "kz.otbasy-bank", country: .kz, name: "Otbasy Bank", aliases: ["Отбасы", "ЖССБ"], color: "teal"),
        Entry(id: "kz.alatau-city-bank", country: .kz, name: "Alatau City Bank", aliases: ["Alatau", "Jusan", "Жусан"], color: "yellow"),
        Entry(id: "kz.bereke-bank", country: .kz, name: "Bereke Bank", aliases: ["Bereke", "Береке"], color: "blue"),
        Entry(id: "kz.home-credit-bank-kazakhstan", country: .kz, name: "Home Credit Bank Kazakhstan", aliases: ["Home Credit", "Хоум Кредит"], color: "green"),
        Entry(id: "kz.nurbank", country: .kz, name: "Nurbank", aliases: ["Нурбанк"], color: "orange"),
        Entry(id: "kz.bank-rbk", country: .kz, name: "Bank RBK", aliases: ["RBK"], color: "pink"),
        Entry(id: "kz.altyn-bank", country: .kz, name: "Altyn Bank", aliases: ["Алтын"], color: "purple"),
        Entry(id: "kz.kzi-bank", country: .kz, name: "KZI Bank", aliases: ["Kazakhstan-Ziraat", "KZI"], color: "red"),
        Entry(id: "kz.zaman-bank", country: .kz, name: "Zaman-Bank", aliases: ["Zaman"], color: "teal"),

        // AE — United Arab Emirates
        Entry(id: "ae.emirates-nbd", country: .ae, name: "Emirates NBD", aliases: ["ENBD"], color: "yellow"),
        Entry(id: "ae.first-abu-dhabi-bank", country: .ae, name: "First Abu Dhabi Bank", aliases: ["FAB"], color: "blue"),
        Entry(id: "ae.abu-dhabi-commercial-bank", country: .ae, name: "Abu Dhabi Commercial Bank", aliases: ["ADCB"], color: "green"),
        Entry(id: "ae.dubai-islamic-bank", country: .ae, name: "Dubai Islamic Bank", aliases: ["DIB"], color: "orange"),
        Entry(id: "ae.mashreq", country: .ae, name: "Mashreq", aliases: ["Mashreq Bank"], color: "pink"),
        Entry(id: "ae.abu-dhabi-islamic-bank", country: .ae, name: "Abu Dhabi Islamic Bank", aliases: ["ADIB"], color: "purple"),
        Entry(id: "ae.emirates-islamic", country: .ae, name: "Emirates Islamic", aliases: ["EI"], color: "red"),
        Entry(id: "ae.rakbank", country: .ae, name: "RAKBANK", aliases: ["National Bank of Ras Al-Khaimah"], color: "teal"),
        Entry(id: "ae.commercial-bank-of-dubai", country: .ae, name: "Commercial Bank of Dubai", aliases: ["CBD"], color: "yellow"),
        Entry(id: "ae.national-bank-of-fujairah", country: .ae, name: "National Bank of Fujairah", aliases: ["NBF"], color: "blue"),
        Entry(id: "ae.wio-bank", country: .ae, name: "Wio Bank", aliases: ["Wio"], color: "green"),
        Entry(id: "ae.al-hilal-bank", country: .ae, name: "Al Hilal Bank", aliases: ["Al Hilal"], color: "orange"),
        Entry(id: "ae.sharjah-islamic-bank", country: .ae, name: "Sharjah Islamic Bank", aliases: ["SIB"], color: "pink"),
        Entry(id: "ae.ajman-bank", country: .ae, name: "Ajman Bank", aliases: ["Ajman"], color: "purple"),
        Entry(id: "ae.hsbc-uae", country: .ae, name: "HSBC UAE", aliases: ["HSBC"], color: "red"),
        Entry(id: "ae.standard-chartered-uae", country: .ae, name: "Standard Chartered UAE", aliases: ["Standard Chartered"], color: "teal"),
        Entry(id: "ae.citibank-uae", country: .ae, name: "Citibank UAE", aliases: ["Citi UAE", "Citi"], color: "yellow"),

        // RU — Russia
        Entry(id: "ru.sberbank", country: .ru, name: "Sberbank", aliases: ["Сбер", "Сбербанк"], color: "blue"),
        Entry(id: "ru.vtb", country: .ru, name: "VTB", aliases: ["ВТБ"], color: "green"),
        Entry(id: "ru.alfa-bank", country: .ru, name: "Alfa-Bank", aliases: ["Альфа-Банк", "Альфа"], color: "orange"),
        Entry(id: "ru.t-bank", country: .ru, name: "T-Bank", aliases: ["Т-Банк", "Tinkoff", "Тинькофф"], color: "pink"),
        Entry(id: "ru.gazprombank", country: .ru, name: "Gazprombank", aliases: ["Газпромбанк", "ГПБ"], color: "purple"),
        Entry(id: "ru.sovcombank", country: .ru, name: "Sovcombank", aliases: ["Совкомбанк"], color: "red"),
        Entry(id: "ru.russian-agricultural-bank", country: .ru, name: "Russian Agricultural Bank", aliases: ["Россельхозбанк", "РСХБ"], color: "teal"),
        Entry(id: "ru.psb", country: .ru, name: "PSB", aliases: ["ПСБ", "Промсвязьбанк"], color: "yellow"),
        Entry(id: "ru.moscow-credit-bank", country: .ru, name: "Moscow Credit Bank", aliases: ["МКБ", "Московский кредитный банк"], color: "blue"),
        Entry(id: "ru.dom-rf", country: .ru, name: "DOM.RF", aliases: ["ДОМ.РФ"], color: "green"),
        Entry(id: "ru.raiffeisenbank", country: .ru, name: "Raiffeisenbank", aliases: ["Райффайзен", "Райффайзенбанк"], color: "orange"),
        Entry(id: "ru.unicredit-bank", country: .ru, name: "UniCredit Bank", aliases: ["ЮниКредит"], color: "pink"),
        Entry(id: "ru.bank-saint-petersburg", country: .ru, name: "Bank Saint Petersburg", aliases: ["Банк Санкт-Петербург", "БСПБ"], color: "purple"),
        Entry(id: "ru.ak-bars-bank", country: .ru, name: "Ak Bars Bank", aliases: ["Ак Барс"], color: "red"),
        Entry(id: "ru.russian-standard", country: .ru, name: "Russian Standard", aliases: ["Русский Стандарт"], color: "teal"),
        Entry(id: "ru.mts-bank", country: .ru, name: "MTS Bank", aliases: ["МТС Банк"], color: "yellow"),
        Entry(id: "ru.ozon-bank", country: .ru, name: "Ozon Bank", aliases: ["Ozon", "Озон Банк"], color: "blue"),
        Entry(id: "ru.yandex-bank", country: .ru, name: "Yandex Bank", aliases: ["Яндекс Банк", "Yandex"], color: "green"),
        Entry(id: "ru.post-bank", country: .ru, name: "Post Bank", aliases: ["Почта Банк"], color: "orange"),

        // US — United States
        Entry(id: "us.chase", country: .us, name: "Chase", aliases: ["JPMorgan Chase"], color: "pink"),
        Entry(id: "us.bank-of-america", country: .us, name: "Bank of America", aliases: ["BofA", "BOA"], color: "purple"),
        Entry(id: "us.citibank", country: .us, name: "Citibank", aliases: ["Citi"], color: "red"),
        Entry(id: "us.wells-fargo", country: .us, name: "Wells Fargo", aliases: ["Wells"], color: "teal"),
        Entry(id: "us.u-s-bank", country: .us, name: "U.S. Bank", aliases: ["US Bank", "USB"], color: "yellow"),
        Entry(id: "us.capital-one", country: .us, name: "Capital One", aliases: ["CapitalOne"], color: "blue"),
        Entry(id: "us.pnc", country: .us, name: "PNC", aliases: ["PNC Bank"], color: "green"),
        Entry(id: "us.truist", country: .us, name: "Truist", aliases: ["Truist Bank"], color: "orange"),
        Entry(id: "us.td-bank", country: .us, name: "TD Bank", aliases: ["TD"], color: "pink"),
        Entry(id: "us.bmo", country: .us, name: "BMO", aliases: ["BMO Bank"], color: "purple"),
        Entry(id: "us.fifth-third-bank", country: .us, name: "Fifth Third Bank", aliases: ["5/3", "Fifth Third"], color: "red"),
        Entry(id: "us.huntington", country: .us, name: "Huntington", aliases: ["Huntington Bank"], color: "teal"),
        Entry(id: "us.keybank", country: .us, name: "KeyBank", aliases: ["Key Bank"], color: "yellow"),
        Entry(id: "us.regions-bank", country: .us, name: "Regions Bank", aliases: ["Regions"], color: "blue"),
        Entry(id: "us.citizens", country: .us, name: "Citizens", aliases: ["Citizens Bank"], color: "green"),
        Entry(id: "us.santander-bank", country: .us, name: "Santander Bank", aliases: ["Santander"], color: "orange"),
        Entry(id: "us.ally-bank", country: .us, name: "Ally Bank", aliases: ["Ally"], color: "pink"),
        Entry(id: "us.synchrony-bank", country: .us, name: "Synchrony Bank", aliases: ["Synchrony"], color: "purple"),
        Entry(id: "us.charles-schwab-bank", country: .us, name: "Charles Schwab Bank", aliases: ["Schwab"], color: "red"),
        Entry(id: "us.sofi", country: .us, name: "SoFi", aliases: ["SoFi Bank"], color: "teal"),
        Entry(id: "us.usaa", country: .us, name: "USAA", aliases: ["USAA Federal Savings Bank"], color: "yellow"),
        Entry(id: "us.navy-federal-credit-union", country: .us, name: "Navy Federal Credit Union", aliases: ["Navy Federal"], color: "blue"),
        Entry(id: "us.penfed-credit-union", country: .us, name: "PenFed Credit Union", aliases: ["PenFed"], color: "green"),
        Entry(id: "us.alliant-credit-union", country: .us, name: "Alliant Credit Union", aliases: ["Alliant"], color: "orange"),
        Entry(id: "us.chime", country: .us, name: "Chime", aliases: ["Chime Financial"], color: "pink"),
        Entry(id: "us.varo-bank", country: .us, name: "Varo Bank", aliases: ["Varo"], color: "purple"),
        Entry(id: "us.axos-bank", country: .us, name: "Axos Bank", aliases: ["Axos"], color: "red")
    ]
}
```

(Colors were assigned by cycling `ProfileIconPalette.colorNames` — `["blue", "green", "orange", "pink", "purple", "red", "teal", "yellow"]` — in catalog order: entry index `i` gets `colorNames[i % 8]`. `id`/`country`/`name`/`aliases` are unchanged from the existing file, only `color:` is new on every line.)

- [x] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MyFinTests.SystemInstitutionCatalogTests`
Expected: all 4 new tests pass.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 141 previously-passing tests still pass, plus the 4 new ones (145 total).

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 2: Show the icon in the two display sites

**Files:**
- Modify: `Sources/MyFin/Views/CustomInstitutionsView.swift`
- Modify: `Sources/MyFin/Views/MainShellView.swift`

**Interfaces:**
- Consumes: `SystemInstitutionCatalog.institutionIconName`, `SystemInstitutionCatalog.color(forID:)` (Task 1), existing `ProfileIconPalette.color(named:) -> Color`.
- Produces: none — this is the final task in this plan.

- [x] **Step 1: `CustomInstitutionsView`'s row**

In `Sources/MyFin/Views/CustomInstitutionsView.swift`, change:

```swift
private struct CustomInstitutionRowView: View {
    let institution: Institution
    let onEdit: () -> Void
    let onToggleArchive: () -> Void

    @EnvironmentObject var preferences: AppPreferences

    var body: some View {
        HStack {
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
```

to:

```swift
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
```

- [x] **Step 2: Sidebar's per-bank grouped row**

In `Sources/MyFin/Views/MainShellView.swift`, change:

```swift
                            DisclosureGroup(isExpanded: $isAccountsExpanded) {
                                ForEach(accountsModel.groupedByInstitution(baseCurrency: session.baseCurrency)) { group in
                                    HStack {
                                        Text(group.id == AccountsListModel.cashGroupID ? preferences.string(.cashFieldLabel) : group.label)
                                        Spacer()
                                        Text("\(NumberDisplayFormatter.format(group.total, preferences: session.numberFormatPreferences)) \(session.baseCurrency.rawValue)")
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selection = .accounts }
                                }
                            } label: {
```

to:

```swift
                            DisclosureGroup(isExpanded: $isAccountsExpanded) {
                                ForEach(accountsModel.groupedByInstitution(baseCurrency: session.baseCurrency)) { group in
                                    HStack {
                                        if group.id != AccountsListModel.cashGroupID {
                                            Image(systemName: SystemInstitutionCatalog.institutionIconName)
                                                .foregroundStyle(ProfileIconPalette.color(named: SystemInstitutionCatalog.color(forID: group.id) ?? "blue"))
                                        }
                                        Text(group.id == AccountsListModel.cashGroupID ? preferences.string(.cashFieldLabel) : group.label)
                                        Spacer()
                                        Text("\(NumberDisplayFormatter.format(group.total, preferences: session.numberFormatPreferences)) \(session.baseCurrency.rawValue)")
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selection = .accounts }
                                }
                            } label: {
```

- [x] **Step 3: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 4: Run the full test suite**

Run: `swift test`
Expected: all 145 tests still pass.

- [ ] **Step 5: Manual look at the running app**

Hand to human partner. Run: `swift run` from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`
Ask them to confirm: the "Банки" tab shows a colored bank icon next to each institution's name (custom institutions show it in blue); the sidebar's "Счета" list shows the same icon next to each bank's grouped row, in the same color as that bank's row on the "Банки" tab (create an account at a system bank if none exists yet, to see a non-blue example); the "Наличные" row in the sidebar has no icon.
Expected: everything above behaves as described.

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Self-Review Notes

- **Spec coverage:** the spec's 4 numbered design points (catalog `color` field + lookup, icon constant, custom-institution fallback, the two display sites) map to Task 1 (points 1–3) and Task 2 (point 4, the two sites).
- **No placeholders:** every one of the 78 catalog entries has an explicit, individually-computed `color:` value (verified by hand-cycling `colorNames[i % 8]` across all 78 indices while writing this plan) — none left as "similar to the others."
- **Type/name consistency checked:** `SystemInstitutionCatalog.institutionIconName` / `.color(forID:)` (Task 1) are used with those exact names at both Task 2 call sites; the cash-row guard uses `AccountsListModel.cashGroupID`, the same constant introduced in the sidebar-bank-grouping work earlier this session.
