# Country flags

## Context

`Country` (`Sources/MyFin/Models/Country.swift`) has 4 cases (`kz`, `ae`, `ru`, `us`) and a `displayName: String` computed property. There are exactly 5 places in the codebase that read a country's name for display or generation:

1. `AccountFormView.swift:49` — country `Picker` when creating/editing an account.
2. `CustomInstitutionFormView.swift:28` — country `Picker` when adding/editing a custom bank.
3. `AccountsListView.swift:56` and `:62` — the country label shown in an account row (`institutionOrCountryLabel(for:)`, used for cash accounts and as a fallback when an institution can't be resolved).
4. `CustomInstitutionsView.swift:71` — the country caption shown in a custom-bank row.
5. `AccountService.swift:59` — `finalName = "Cash · \(country.displayName)"`, the **auto-generated, persisted** name given to a cash account with no user-supplied name.

## Goal

Show a flag emoji next to the country name everywhere a country is *displayed* (sites 1–4). Site 5 is data, not display — a value written once into the `accounts` table and read back later as plain text — and stays untouched, so a flag emoji never gets baked into stored account names.

## Design

Add a computed property to `Country`, alongside `displayName`, in `Sources/MyFin/Models/Country.swift`:

```swift
var flag: String {
    switch self {
    case .kz: return "🇰🇿"
    case .ae: return "🇦🇪"
    case .ru: return "🇷🇺"
    case .us: return "🇺🇸"
    }
}
```

At each of the 4 display sites, combine it with the existing `displayName` inline — `displayName` itself is unchanged, so `AccountService.swift:59` keeps working exactly as it does today without needing to know flags exist:

- `AccountFormView.swift:49` / `CustomInstitutionFormView.swift:28`: `Text("\($0.flag) \($0.displayName)").tag($0)` (was `Text($0.displayName).tag($0)`).
- `AccountsListView.swift:56` / `:62`: `return "\(account.country.flag) \(account.country.displayName)"` (was `return account.country.displayName`).
- `CustomInstitutionsView.swift:71`: `Text("\(institution.country.flag) \(institution.country.displayName)")...` (was `Text(institution.country.displayName)...`).

## Testing

Add one test to `Tests/MyFinTests/InstitutionModelTests.swift` (which already has a small `Country`-level test, `test_country_allCasesCoverExpectedFour`):

```swift
func test_country_flags_matchExpectedEmoji() {
    XCTAssertEqual(Country.kz.flag, "🇰🇿")
    XCTAssertEqual(Country.ae.flag, "🇦🇪")
    XCTAssertEqual(Country.ru.flag, "🇷🇺")
    XCTAssertEqual(Country.us.flag, "🇺🇸")
}
```

No tests for the 4 view-layer call sites — consistent with this codebase's existing convention of zero View-level XCTest coverage. Verified by `swift build` + `swift test` plus a manual look at the running app.

## Out of scope

- `AccountService.swift`'s auto-generated cash-account name stays plain text, no flag, per the user's explicit choice.
- No changes to `Country.displayName` itself, `Country.allCases`, or anything in the institution seed catalog.
