# MyFin — Appearance, Language, and Profile Management

## Purpose

Three additions to the existing MyFin MVP shell (see `2026-09-01-myfin-mvp-shell-design.md`):

1. An app-wide appearance setting: Day / Night / System.
2. An app-wide interface language setting: Russian / English, switching instantly with no restart.
3. Profile management: rename a profile, give it an icon (SF Symbol + color), and add a confirmation dialog to the profile deletion that already exists.

These are three fairly independent pieces of work, kept in one spec because the app is small and they share one host screen (Settings) and one new shared layer (`AppPreferences`).

## Scope

In scope:
- `AppPreferences`: an app-wide, `UserDefaults`-backed `ObservableObject` holding `theme` and `language`, available before any profile is unlocked.
- A hand-rolled localization layer (not `Localizable.strings`/`Bundle`) covering every string currently hardcoded in Russian across the five existing views, plus all new strings this spec adds.
- A compact theme/language switcher on the profile picker screen, and a full one in Settings.
- `Profile` gains `iconName` (SF Symbol) and `iconColor`; profiles created before this change get sane defaults transparently.
- Rename + icon/color editing from Settings (post-login only).
- A confirmation dialog before deleting a profile from the picker.

Out of scope:
- Per-profile theme/language (explicitly rejected — one setting for the whole app).
- Renaming or changing the icon from the picker screen (pre-login) — only from Settings.
- Custom user-uploaded images for the profile icon — SF Symbol + color only.
- Standard `Localizable.strings`/`NSLocalizedString` — rejected because it can't reliably switch language at runtime without a relaunch.
- A third language, RTL support, or any localization tooling beyond the two dictionaries this spec adds.

## Architecture: `AppPreferences`

A new `Sources/MyFin/AppPreferences.swift`:

```swift
enum AppTheme: String, CaseIterable, Codable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Codable {
    case ru, en
}

@MainActor
final class AppPreferences: ObservableObject {
    @Published var theme: AppTheme { didSet { persist() } }
    @Published var language: AppLanguage { didSet { persist() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.theme = AppTheme(rawValue: defaults.string(forKey: "appTheme") ?? "") ?? .system
        self.language = AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "") ?? .ru
    }

    private func persist() {
        defaults.set(theme.rawValue, forKey: "appTheme")
        defaults.set(language.rawValue, forKey: "appLanguage")
    }

    func string(_ key: L10nKey) -> String {
        Localization.string(key, language: language)
    }
}
```

`MyFinApp` creates one `@StateObject private var preferences = AppPreferences()`, injects it via `.environmentObject(preferences)` on the root view, and applies `.preferredColorScheme(preferences.theme.colorScheme)` there too. Every view that needs strings or the theme/language pickers reads `@EnvironmentObject var preferences: AppPreferences`.

This is a genuinely new, independent piece (no existing view reads it yet), so it needs its own unit tests: defaulting when nothing is stored, persisting across re-init with a fake `UserDefaults` suite, and `string(_:)` returning the right dictionary's value.

## Localization

`Sources/MyFin/Localization.swift` defines every user-facing string as a case of `enum L10nKey`, and two `[L10nKey: String]` dictionaries (`ru`, `en`). `Localization.string(_:language:)` looks up the key in the right dictionary, falling back to the raw key name (never crashing) if a translation is somehow missing — this fallback should never trigger in practice since both dictionaries are built from the same `CaseIterable` key set, but it keeps a missed entry from being a runtime crash.

Every hardcoded Russian string in `ProfilePickerView`, `CreateProfileView`, `LoginView`, `MainShellView` (including `SidebarItem`'s labels), `PlaceholderPageView` usages, and `SettingsView` is replaced with `preferences.string(.someKey)`. `SidebarItem` stops carrying its label as its `rawValue`; the view looks up the label via `preferences.string(...)` per case instead, so the identifier used for `Identifiable`/`Hashable`/persistence stays a stable English-ish raw value (`"dashboard"`, `"accounts"`, ...) independent of display language.

A unit test (`LocalizationTests`) iterates `L10nKey.allCases` and asserts both dictionaries contain every key — this is what actually guarantees the "never crashes on a missing key" property, by catching a missing translation at test time instead of relying on the runtime fallback.

## Theme & language switcher

A small reusable view, `Sources/MyFin/Views/PreferencesControls.swift`, renders two `Picker`s (theme: system/light/dark: language: ru/en) bound to `@EnvironmentObject var preferences: AppPreferences`. It's used in two places:
- `ProfilePickerView`: a compact `HStack` of two `Menu`-based pickers placed directly under the "MyFin" title, so the setting is reachable before logging into any profile.
- `SettingsView`: a full "Оформление и язык" / "Appearance & Language" section, same controls, larger layout.

Both instances share the same `AppPreferences` instance (injected once at the app root), so a change in one place is instantly reflected in the other and everywhere else, with no extra wiring.

## Profile model changes

`Profile` gains two fields:

```swift
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    let createdAt: Date
    var iconName: String = "person.crop.circle.fill"
    var iconColor: String = "blue"
}
```

Because these have default values and `Codable`'s synthesized `init(from:)` fills in missing keys from a default only if the property has a default *and* you don't hand-roll `CodingKeys`/`init(from:)` — Swift's automatic `Decodable` synthesis does **not** apply property defaults for keys absent from the JSON. So `Profile` gets an explicit `init(from decoder:)` that decodes `iconName`/`iconColor` with `decodeIfPresent(...) ?? default`, so `profile.json` files written before this change (which lack these keys) decode cleanly with the defaults instead of failing to decode at all. `iconColor` is a small closed set of names (`"blue"`, `"green"`, `"orange"`, `"pink"`, `"purple"`, `"red"`, `"teal"`, `"yellow"`) mapped to SwiftUI `Color` via a small lookup; an unrecognized stored value also falls back to `"blue"` rather than failing.

`ProfileStore` gains:
```swift
func updateProfile(_ profile: Profile) throws
```
which re-encodes and overwrites that profile's `profile.json` (same encode path `createProfileDirectory` already uses). `AppSession` gains:
```swift
func updateProfile(displayName: String, iconName: String, iconColor: String) 
```
which builds an updated `Profile` from `unlockedProfile`, calls `profileStore.updateProfile(_:)`, updates `unlockedProfile` and `profiles` in memory, and sets `errorMessage` on failure — mirroring the existing `changePassword` method's shape.

## Rename & icon editing (Settings)

A new "Профиль" / "Profile" section at the top of `SettingsView`:
- A `TextField` pre-filled with the current display name.
- A grid of ~12 SF Symbols (`person.crop.circle.fill`, `star.circle.fill`, `heart.circle.fill`, `leaf.circle.fill`, `bolt.circle.fill`, `moon.circle.fill`, `sun.max.circle.fill`, `pawprint.circle.fill`, `gift.circle.fill`, `car.circle.fill`, `airplane.circle.fill`, `graduationcap.circle.fill`) as tappable icons, current selection highlighted.
- A row of 8 color swatches (the `iconColor` set above), current selection highlighted.
- A "Сохранить" / "Save" button calling `session.updateProfile(displayName:iconName:iconColor:)`, disabled when the name is empty.

The icon (symbol tinted with the chosen color, in a circle) also renders next to each profile's name in `ProfilePickerView`'s list, so a rename/re-icon is visible immediately on next logout.

## Delete confirmation

`ProfilePickerView`'s delete button wraps the existing `session.deleteProfile(profile)` call in a `.confirmationDialog`: title "Удалить профиль «\(name)»?" / "Delete profile \"\(name)\"?", a destructive "Удалить"/"Delete" button that performs the deletion, and a "Отмена"/"Cancel" button. No change to `AppSession.deleteProfile` itself — this is purely a picker-view guard rail.

## Testing

- `AppPreferencesTests`: defaults when `UserDefaults` is empty; persists and reloads theme/language; `string(_:)` returns the right value per language.
- `LocalizationTests`: every `L10nKey` case has a non-empty entry in both the `ru` and `en` dictionaries.
- `ProfileStoreTests` gains: `updateProfile` overwrites `displayName`/`iconName`/`iconColor` on disk and `listProfiles()` reflects it; decoding a hand-written legacy `profile.json` (no `iconName`/`iconColor` keys) succeeds with the documented defaults.
- `AppSessionTests` gains: `updateProfile` updates `unlockedProfile` and the `profiles` list.
- No new UI/snapshot tests, consistent with the original spec's testing philosophy — the picker's confirmation dialog and the icon/color grid are verified by the same kind of manual checklist used for the original shell.
