# Country Flags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a flag emoji next to a country's name everywhere a country is displayed in the UI, without changing anything that gets persisted to the database.

**Architecture:** Add a `flag: String` computed property to `Country`, parallel to its existing `displayName`. Update the 4 display call sites (2 country `Picker`s, 1 account-row label, 1 institution-row label) to combine `flag` + `displayName` inline. Leave `displayName` itself, and the one place that writes it into a persisted account name (`AccountService.swift:59`), completely untouched.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, Swift Package Manager (no Xcode project).

**Spec:** `docs/superpowers/specs/2026-09-04-myfin-country-flags-design.md`

## Global Constraints

- **No git** in this project (neither `MyFinLocal/` nor `MyFinLocal/MyFin/` is a git repository) — never run `git` commands; every "Commit" step below is skipped, left in the template only where the plan format requires it.
- **Swift toolchain is available and verified working in this environment** — run every `swift build` / `swift test` step yourself, directly via Bash, from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`. Only the manual look-at-the-running-app step (explicitly marked "Hand to human partner") needs the human.
- `Country.displayName` itself is never modified, and `AccountService.swift:59`'s `finalName = "Cash · \(country.displayName)"` is never touched — flags are display-only, never persisted, per the spec.
- No automated tests for the 4 view-layer call sites — consistent with this codebase's existing convention of zero View-level XCTest coverage. Verified by `swift build` + a manual look at the running app.

## File Structure

- Modify: `Sources/MyFin/Models/Country.swift` — add `var flag: String` (Task 1).
- Modify: `Tests/MyFinTests/InstitutionModelTests.swift` — test for the new property (Task 1).
- Modify: `Sources/MyFin/Views/AccountFormView.swift` — country `Picker` shows the flag (Task 2).
- Modify: `Sources/MyFin/Views/CustomInstitutionFormView.swift` — country `Picker` shows the flag (Task 2).
- Modify: `Sources/MyFin/Views/AccountsListView.swift` — account-row country label shows the flag (Task 2).
- Modify: `Sources/MyFin/Views/CustomInstitutionsView.swift` — institution-row country label shows the flag (Task 2).

---

### Task 1: `Country.flag`

**Files:**
- Modify: `Sources/MyFin/Models/Country.swift`
- Test: `Tests/MyFinTests/InstitutionModelTests.swift`

**Interfaces:**
- Produces (for Task 2): `Country.flag: String` — one emoji per case (`.kz` → `"🇰🇿"`, `.ae` → `"🇦🇪"`, `.ru` → `"🇷🇺"`, `.us` → `"🇺🇸"`).

- [x] **Step 1: Write the failing test**

Add to `Tests/MyFinTests/InstitutionModelTests.swift`, right after `test_country_allCasesCoverExpectedFour`:

```swift
    func test_country_flags_matchExpectedEmoji() {
        XCTAssertEqual(Country.kz.flag, "🇰🇿")
        XCTAssertEqual(Country.ae.flag, "🇦🇪")
        XCTAssertEqual(Country.ru.flag, "🇷🇺")
        XCTAssertEqual(Country.us.flag, "🇺🇸")
    }
```

- [x] **Step 2: Run the test to verify it fails**

Run: `swift test --filter MyFinTests.InstitutionModelTests`
Expected: build failure — `Country` has no member `flag` yet.

- [x] **Step 3: Add the property**

In `Sources/MyFin/Models/Country.swift`, add right after the existing `displayName` computed property:

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

- [x] **Step 4: Run the test to verify it passes**

Run: `swift test --filter MyFinTests.InstitutionModelTests`
Expected: all `InstitutionModelTests` pass, including the new one.

- [x] **Step 5: Run the full test suite**

Run: `swift test`
Expected: all 107 previously-passing tests still pass, plus the 1 new one (108 total).

- [x] **Step 6: Commit**

Skipped — this project does not use git (see Global Constraints).

---

### Task 2: Show the flag at all 4 display call sites

**Files:**
- Modify: `Sources/MyFin/Views/AccountFormView.swift`
- Modify: `Sources/MyFin/Views/CustomInstitutionFormView.swift`
- Modify: `Sources/MyFin/Views/AccountsListView.swift`
- Modify: `Sources/MyFin/Views/CustomInstitutionsView.swift`

**Interfaces:**
- Consumes: `Country.flag` (Task 1), existing `Country.displayName`.
- Produces: none — this is the final task in this plan.

- [x] **Step 1: Account form's country picker**

In `Sources/MyFin/Views/AccountFormView.swift`, change:

```swift
            Picker(preferences.string(.countryFieldLabel), selection: $country) {
                ForEach(Country.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
```

to:

```swift
            Picker(preferences.string(.countryFieldLabel), selection: $country) {
                ForEach(Country.allCases, id: \.self) { Text("\($0.flag) \($0.displayName)").tag($0) }
            }
```

- [x] **Step 2: Custom institution form's country picker**

In `Sources/MyFin/Views/CustomInstitutionFormView.swift`, change:

```swift
            Picker(preferences.string(.countryFieldLabel), selection: $country) {
                ForEach(Country.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
```

to:

```swift
            Picker(preferences.string(.countryFieldLabel), selection: $country) {
                ForEach(Country.allCases, id: \.self) { Text("\($0.flag) \($0.displayName)").tag($0) }
            }
```

- [x] **Step 3: Account row's country label**

In `Sources/MyFin/Views/AccountsListView.swift`, in `institutionOrCountryLabel(for:)`, change both:

```swift
        guard account.type != .cash, let institutionId = account.institutionId, let connection = session.connection else {
            return account.country.displayName
        }
```

to:

```swift
        guard account.type != .cash, let institutionId = account.institutionId, let connection = session.connection else {
            return "\(account.country.flag) \(account.country.displayName)"
        }
```

and:

```swift
        return account.country.displayName
    }
}
```

to:

```swift
        return "\(account.country.flag) \(account.country.displayName)"
    }
}
```

- [x] **Step 4: Custom institution row's country label**

In `Sources/MyFin/Views/CustomInstitutionsView.swift`, change:

```swift
                Text(institution.country.displayName).font(.caption).foregroundStyle(.secondary)
```

to:

```swift
                Text("\(institution.country.flag) \(institution.country.displayName)").font(.caption).foregroundStyle(.secondary)
```

- [x] **Step 5: Build**

Run: `swift build`
Expected: build succeeds with no errors.

- [x] **Step 6: Run the full test suite**

Run: `swift test`
Expected: all 108 tests still pass.

- [ ] **Step 7: Manual look at the running app**

Hand to human partner. Run: `swift run` from `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin`
Ask them to confirm: the country `Picker` on the account-creation form shows a flag next to each country name; the same on the "Банки" tab's add/edit form; a cash account's row on "Счета" shows a flag next to its country; a custom bank's row on the "Банки" tab shows a flag next to its country; and that an *existing* cash account's stored name (visible nowhere but worth a quick check via its row's name column, unaffected by this change) still reads plain "Cash · Kazakhstan" with no flag baked in.
Expected: flags appear everywhere described above; no flag appears inside any account's own name.

- [x] **Step 8: Commit**

Skipped — this project does not use git (see Global Constraints).

---

## Self-Review Notes

- **Spec coverage:** the spec's single design section (add `flag`, use it at 4 sites, leave `AccountService.swift` alone) maps directly to Task 1 (property + test) and Task 2 (the 4 sites). The spec's "out of scope" list (no change to `displayName`, `allCases`, or the seed catalog) is respected — none of those are touched.
- **No placeholders:** every step has complete, exact before/after code.
- **Type/name consistency checked:** `Country.flag` (Task 1) is referenced with that exact name at all 4 sites in Task 2; the emoji values match the spec's table exactly.
