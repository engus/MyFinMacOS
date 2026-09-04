# MyFin — MVP Shell Design

## Purpose

A local-only macOS app ("MyFin") that, for this first milestone, does nothing functionally except:

- support multiple local user profiles, each with its own password-protected, encrypted database;
- present the app shell — a sidebar with 5 empty pages (Дашборд, Аккаунты, Cashflow, Активы, Настройки) and a working area on the right.

No networking, no sync, no cloud accounts. Everything lives on the user's Mac.

## Scope

In scope:
- Xcode project (SwiftUI, macOS target) at `MyFin/` alongside the existing `MyFinLocal` folder contents (unrelated `agent/`, `docs/`, `scripts/` scaffolding is left untouched).
- Profile creation/selection/deletion screen.
- Per-profile encrypted SQLite database (SQLCipher) created on profile creation.
- Optional "remember password" via macOS Keychain, per profile.
- Main shell: `NavigationSplitView` sidebar with 5 empty destination pages.
- Basic settings page stub with "change password" and "log out of profile" actions (may be non-functional placeholders wired for later).
- Unit tests for the profile/database repository layer.

Out of scope (explicitly deferred):
- Any real financial functionality behind the 5 pages.
- Password recovery/reset flow (if a profile password is lost, the profile's data is unrecoverable — acceptable for MVP).
- Multi-device sync, cloud backup, import/export.
- App sandboxing/notarization/distribution concerns.
- UI polish beyond a clean, native-looking empty shell.

## Stack

- **SwiftUI**, macOS app target (latest 2 macOS versions).
- **SQLCipher.swift** (official package by Zetetic, the makers of SQLCipher: `https://github.com/sqlcipher/SQLCipher.swift`) for at-rest encryption, accessed through a small hand-written repository layer over its C API — no ORM.
  - *Why not GRDB*: as of this writing there is no reliable, officially supported way to combine GRDB.swift with SQLCipher via SPM — GRDB's own maintainer confirms the only path is forking GRDB and hand-patching its `Package.swift` per in-repo comments, which is too fragile for an unattended/automated build. SQLCipher.swift alone is the officially maintained SPM package and is used directly. Given this app currently persists no real data (profiles only), the loss of an ORM has no practical cost yet; a future task can layer a query builder or GRDB back in once SPM support matures.
  - The `SQLITE_HAS_CODEC=1` preprocessor macro must be visible to the **C header** (`sqlite3.h` in the xcframework gates `sqlite3_key`/`sqlite3_rekey`/etc. behind `#ifdef SQLITE_HAS_CODEC`), so it has to be passed to the Clang importer via `-Xcc -DSQLITE_HAS_CODEC=1` (as `swiftSettings: [.unsafeFlags(["-Xcc", "-DSQLITE_HAS_CODEC=1"])]` in `Package.swift`) rather than as a plain Swift `.define(...)`, which only affects Swift's own `#if` conditionals and never reaches the imported C header.
- Dependencies via **Swift Package Manager** only (no CocoaPods/Carthage).
- No git — files live on disk only, per current working preference.
- Because this runs as a bare `swift run` executable rather than a double-clicked `.app` bundle, macOS doesn't automatically make it the frontmost/key app — without an explicit activation step, the window is visible but keyboard input keeps going to whatever app was focused before. `MyFinApp` uses an `NSApplicationDelegateAdaptor` that calls `NSApp.setActivationPolicy(.regular)` and `NSApp.activate(ignoringOtherApps: true)` in `applicationDidFinishLaunching` to fix this.

## Profile model & storage

- Profiles live under `~/Library/Application Support/MyFin/profiles/<uuid>/`.
- Each profile folder contains:
  - `db.sqlite` — the SQLCipher-encrypted database.
  - `profile.json` — metadata only: profile id, display name, created date. **Never contains the password or derived key.**
- The profile password is never stored by the app itself. It is used directly as the SQLCipher encryption key, set via `PRAGMA key = '...'` immediately after opening the connection (SQLCipher performs PBKDF2-HMAC-SHA512 key derivation internally from the passphrase).
- Optional convenience: if the user checks "remember password" at creation or login, the plaintext password is stored in the macOS Keychain as a per-profile item (account = profile uuid, service = app bundle id), with accessibility `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. If not checked, nothing is written to Keychain and the password must be typed in every launch.
- Reading a remembered password to auto-unlock a profile is gated behind Touch ID / the Mac's login password (via `LocalAuthentication`'s `deviceOwnerAuthentication` policy) — clicking "Войти" on a profile with a remembered password prompts for biometric/device authentication first, and only reads the Keychain secret and logs in on success. This authentication step is abstracted behind a `BiometricAuthenticating` protocol so it can be swapped for a deterministic stub in tests.
  - **Known limitation (accepted for MVP):** because the app runs as an unsigned/ad-hoc `swift build` binary rather than a properly code-signed `.app`, macOS sometimes asks for a confirming device password right after a successful Touch ID prompt. This is inherent to running an unsigned local dev build and would go away with proper code signing, which is out of scope per this spec's distribution/notarization exclusion.
- On every open, the database layer creates an internal `_myfin_meta` table if missing. This is not app schema — it exists purely to force SQLite to write its (encrypted) header to disk immediately, since a brand-new SQLite file writes no pages until the first write transaction; without this, opening a never-written-to database with the wrong password would trivially "succeed" because there is nothing on disk yet to fail decrypting.
- Deleting a profile deletes its entire folder (after a confirmation dialog) and removes any matching Keychain item.
- Password recovery: **not supported**. A lost password means the profile's data is permanently inaccessible; the user can only delete and recreate the profile. This is called out explicitly in the delete/create UI copy so it's not a surprise later.

## Screens & flow

1. **Profile picker (launch screen)**
   - Lists existing profiles (from scanning `profiles/*/profile.json`).
   - Actions: select a profile to log in, "Create profile", "Delete profile" (with confirmation).
   - Selecting a profile that has a remembered Keychain password unlocks it immediately; otherwise shows a password field.
   - If no profiles exist yet, this screen opens directly into "Create profile".

2. **Create profile**
   - Fields: display name, password, confirm password, "remember password in Keychain" checkbox.
   - Password fields use a reusable `RevealableSecureField` (a `SecureField`/`TextField` pair behind an eye-icon toggle) instead of a plain `SecureField`, so the user can reveal what they typed. The same component is reused everywhere else a password is entered (login, change-password in Settings).
   - On submit: generates a uuid, creates the profile folder, creates and opens an empty SQLCipher database keyed with the password, writes `profile.json`, optionally writes to Keychain, then proceeds to the main shell.

3. **Login (existing profile, no remembered password)**
   - Password field only. On submit, attempts to open the profile's database with that key.
   - Wrong password → inline error message ("Неверный пароль"), no retry-count/lockout logic for MVP.

4. **Main shell**
   - `NavigationSplitView`: sidebar lists the 5 sections — Дашборд, Аккаунты, Cashflow, Активы, Настройки.
   - Each maps to an empty placeholder view (e.g. centered text: "Дашборд — здесь скоро появится содержимое").
   - Настройки page additionally has two stub controls: "Сменить пароль" (re-keys the SQLCipher database) and "Выйти из профиля" (returns to the profile picker, closing the current database connection).

## Error handling

- Wrong password on open → user-facing inline error, database connection not established, user stays on the login screen.
- Corrupted/unreadable profile folder (e.g. missing db file) → profile picker shows the profile as unavailable with an explanation, offers delete.
- Keychain read/write failures are non-fatal — the app falls back to requiring manual password entry and logs the error to the console.

## Testing

- Unit tests (XCTest) for the profile repository layer:
  - create profile → folder + files exist, database opens with correct password, fails with wrong password.
  - delete profile → folder and Keychain item removed.
  - Keychain save/retrieve round-trip for a profile.
- No UI/snapshot tests at this stage — the shell is simple enough to verify manually.

## Open questions / assumptions carried into implementation

- None outstanding; all major decisions (stack, profile model, encryption, keychain behavior, recovery, project location) were confirmed during brainstorming.
