# Bank icons

## Context

Per the user, this is deliberately scoped down from a bigger original idea (per-institution icon/color chosen by the user during account creation, mirroring `ProfileIconPalette`'s picker) — that stays deferred. This pass only adds a generic icon + a hardcoded, deterministic color per bank, with no editing UI anywhere yet.

## Goal

Show a small colored bank icon next to each institution wherever an institution is the main subject of a row: the "Банки" tab (`CustomInstitutionsView`) and the sidebar's per-bank grouped rows (`MainShellView`, added earlier this session). No icon for the sidebar's "Наличные" (cash) row — cash isn't a bank.

## Design

**No database changes.** Color is looked up purely from the existing static `SystemInstitutionCatalog` — no schema migration, no change to `InstitutionService` or the `institutions` table.

1. `SystemInstitutionCatalog.Entry` (`Sources/MyFin/Models/SystemInstitutionCatalog.swift`) gains a `color: String` field. Every one of the 78 existing entries gets an explicit, hand-assigned value from `ProfileIconPalette.colorNames` (`blue`, `green`, `orange`, `pink`, `purple`, `red`, `teal`, `yellow`) — cycled in catalog order, not computed at runtime, so it's identical on every launch (this is what "не рандомизировать" ruled out: no hashing, no `Institution.id.hashValue`-based derivation, just literal values baked into the file, the same way `name`/`aliases` already are).
2. New lookup: `SystemInstitutionCatalog.color(forID:) -> String?`, returning the matching entry's `color`, or `nil` if the id isn't in the catalog (i.e., it's a custom institution).
3. New constant: `SystemInstitutionCatalog.institutionIconName = "building.columns.fill"` — the one icon used for every bank, system or custom.
4. Custom institutions (created by the user, never in the static catalog) always render with a single fixed fallback color, `"blue"` — not computed, not varied — until a future pass adds real per-custom-bank customization.

**Display, both sites use the same pattern:**

```swift
Image(systemName: SystemInstitutionCatalog.institutionIconName)
    .foregroundStyle(ProfileIconPalette.color(named: SystemInstitutionCatalog.color(forID: <id>) ?? "blue"))
```

- `CustomInstitutionsView`'s `CustomInstitutionRowView`: icon added before the name/country `VStack`, using `institution.id`.
- `MainShellView`'s sidebar `DisclosureGroup`: icon added before the group's name `Text`, using `group.id` — guarded so it's skipped entirely when `group.id == AccountsListModel.cashGroupID` (no icon on the "Наличные" row).

## Testing

- New `SystemInstitutionCatalogTests` (new file) asserting: every entry's `color` is one of `ProfileIconPalette.colorNames`; `color(forID:)` returns the right value for a known id and `nil` for an unknown one.
- No tests for `CustomInstitutionsView`/`MainShellView` themselves — consistent with this codebase's zero View-level XCTest coverage. Verified by `swift build` + `swift test` + a manual look at the running app.

## Out of scope

- No icon/color picker anywhere (account creation, "Банки" tab, or elsewhere) — deferred, per the user.
- No icon on the "Счета" page's account rows, or on the sidebar's "Наличные" row.
- No real per-bank logos — one shared generic icon for every institution.
- No database column, no migration — this is pure static lookup data.
