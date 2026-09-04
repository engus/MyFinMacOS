# MyFin MVP Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the empty MyFin macOS app shell — multiple password-protected, encrypted local profiles, and a 5-page sidebar shell with empty placeholder pages.

**Architecture:** A pure Swift Package Manager executable app (no `.xcodeproj`, no Xcode GUI needed to build) using SwiftUI for the interface, a hand-written repository layer over SQLCipher's C API for per-profile encrypted storage, and macOS Keychain for optional password memory. `AppSession` is the single `ObservableObject` that owns navigation state and wires the storage/keychain layers to the views.

**Tech Stack:** Swift 5.9+, SwiftUI, SQLCipher.swift (`https://github.com/sqlcipher/SQLCipher.swift`) via SPM, Foundation `FileManager`/`Security` frameworks, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-01-myfin-mvp-shell-design.md`

## Global Constraints

- **No git.** Do not run any `git` command at any point in this plan. Files are simply saved to disk. Skip every "commit" step a generic plan template would otherwise include.
- **No macOS build toolchain is available to the executing agent.** `device_bash` (used to read/write files on the user's Mac) runs inside a Linux VM — it has no `swift`, `xcodebuild`, or `xcrun`. The cloud container also has no macOS toolchain. **Every step that requires running `swift build`, `swift test`, or `swift run` must be handed to the user**: state the exact command, ask them to run it in their own Terminal (or Xcode) on their Mac, and ask them to paste back the output before continuing. Never claim a build or test "passed" without the user's pasted output confirming it.
- **File edits happen via `device_bash`** against the mounted path `$HOME/mnt/MyFinLocal/MyFin/...`, which is the real path `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin/...` on the user's Mac. Writing there lands directly on their disk — no staging/committing back needed.
- **Project root:** `/Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin` (new folder; do not touch the sibling `agent/`, `docs/`, `scripts/` folders already in `MyFinLocal`).
- **Package name / target name:** the executable target and module are both named `MyFin`. Test target: `MyFinTests`.
- **SQLCipher.swift dependency:** `.package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", from: "4.10.0")`, product name `SQLCipher`, imported as `import SQLCipher`. Both the `MyFin` and `MyFinTests` targets need the `SQLITE_HAS_CODEC` compilation flag defined (via `swiftSettings: [.define("SQLITE_HAS_CODEC")]` in `Package.swift`) for encryption to actually engage — without it the code compiles but silently opens plaintext databases.
- **Keychain service identifier:** the constant string `"com.myfin.local"` is used as `kSecAttrService` for all real app Keychain entries. Tests use a distinct service string so they never collide with real app data.
- **All user-facing strings are in Russian**, matching the spec's exact wording (page names, error messages, button labels) — use the strings given in each task verbatim rather than inventing alternatives.
- **No password recovery, no retry-count/lockout, no UI or snapshot tests** — matches the spec's explicit out-of-scope list. Verification of UI behavior is a manual checklist run by the user, not automated.

---

## File Structure

```
MyFin/
  Package.swift
  Sources/MyFin/
    MyFinApp.swift            # @main entry, switches between picker and shell
    AppSession.swift          # ObservableObject: navigation + storage/keychain glue
    Models/
      Profile.swift
    Services/
      ProfileStore.swift      # filesystem: list/create/delete profile folders + metadata
      DatabaseService.swift   # SQLCipher C API wrapper: open/rekey/close
      KeychainService.swift   # save/read/delete remembered password
    Views/
      ProfilePickerView.swift
      CreateProfileView.swift
      LoginView.swift
      MainShellView.swift
      PlaceholderPageView.swift
      SettingsView.swift
  Tests/MyFinTests/
    ProfileStoreTests.swift
    DatabaseServiceTests.swift
    KeychainServiceTests.swift
    AppSessionTests.swift
```

---

### Task 1: Project scaffold and a running empty window

**Files:**
- Create: `MyFin/Package.swift`
- Create: `MyFin/Sources/MyFin/MyFinApp.swift`

**Interfaces:**
- Produces: an executable SwiftPM package named `MyFin` that later tasks add sources/tests to.

- [ ] **Step 1: Create the directory structure**

Run via `device_bash`:
```bash
mkdir -p "$HOME/mnt/MyFinLocal/MyFin/Sources/MyFin/Models" \
         "$HOME/mnt/MyFinLocal/MyFin/Sources/MyFin/Services" \
         "$HOME/mnt/MyFinLocal/MyFin/Sources/MyFin/Views" \
         "$HOME/mnt/MyFinLocal/MyFin/Tests/MyFinTests"
```

- [ ] **Step 2: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyFin",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", from: "4.10.0")
    ],
    targets: [
        .executableTarget(
            name: "MyFin",
            dependencies: [
                .product(name: "SQLCipher", package: "SQLCipher.swift")
            ],
            swiftSettings: [
                .define("SQLITE_HAS_CODEC")
            ]
        ),
        .testTarget(
            name: "MyFinTests",
            dependencies: ["MyFin"],
            swiftSettings: [
                .define("SQLITE_HAS_CODEC")
            ]
        )
    ]
)
```

- [ ] **Step 3: Write a minimal `MyFinApp.swift`**

```swift
import SwiftUI

@main
struct MyFinApp: App {
    var body: some Scene {
        WindowGroup("MyFin") {
            Text("MyFin")
                .frame(width: 400, height: 300)
        }
    }
}
```

- [ ] **Step 4: Ask the user to build**

Ask the user to run, in their own Terminal:
```bash
cd /Users/yevgeniygolota/Documents/Projects/MyFinLocal/MyFin
swift build
```
Expected: `Build complete!` with no errors. Paste the output back.

Troubleshooting if it fails on resolving `SQLCipher.swift` or on the product name `SQLCipher`: ask the user to run `swift package resolve` then `cat Package.resolved`, and check the exact product/library name declared in `https://github.com/sqlcipher/SQLCipher.swift`'s own `Package.swift` (open the URL) — adjust the `.product(name:package:)` value in our `Package.swift` to match if it differs, then rebuild.

- [ ] **Step 5: Ask the user to run it**

Ask the user to run:
```bash
swift run
```
Expected: a window titled "MyFin" appears showing the text "MyFin". Confirm with the user before moving to Task 2, then have them quit the app (Cmd+Q) or Ctrl+C the terminal.

---

### Task 2: Profile model and filesystem store

**Files:**
- Create: `MyFin/Sources/MyFin/Models/Profile.swift`
- Create: `MyFin/Sources/MyFin/Services/ProfileStore.swift`
- Test: `MyFin/Tests/MyFinTests/ProfileStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct Profile: Codable, Identifiable, Equatable { let id: UUID; var displayName: String; let createdAt: Date }`
  - `struct ProfileStore { init(baseDirectory: URL = ProfileStore.defaultBaseDirectory()); static func defaultBaseDirectory() -> URL; func profileDirectory(for id: UUID) -> URL; func databaseURL(for id: UUID) -> URL; func listProfiles() throws -> [Profile]; func createProfileDirectory(displayName: String) throws -> Profile; func deleteProfile(id: UUID) throws }`
  - `enum ProfileStoreError: Error, Equatable { case profileNotFound; case ioFailure(String) }`

- [ ] **Step 1: Write the model**

`Sources/MyFin/Models/Profile.swift`:
```swift
import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    let createdAt: Date
}
```

- [ ] **Step 2: Write the failing tests**

`Tests/MyFinTests/ProfileStoreTests.swift`:
```swift
import XCTest
@testable import MyFin

final class ProfileStoreTests: XCTestCase {
    var tempDirectory: URL!
    var store: ProfileStore!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyFinTests-\(UUID().uuidString)", isDirectory: true)
        store = ProfileStore(baseDirectory: tempDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func test_listProfiles_onEmptyDirectory_returnsEmptyArray() throws {
        XCTAssertEqual(try store.listProfiles(), [])
    }

    func test_createProfileDirectory_createsFolderAndMetadataFile() throws {
        let profile = try store.createProfileDirectory(displayName: "Женя")
        let dir = store.profileDirectory(for: profile.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("profile.json").path))
        XCTAssertEqual(profile.displayName, "Женя")
    }

    func test_listProfiles_afterCreate_returnsCreatedProfile() throws {
        let created = try store.createProfileDirectory(displayName: "Женя")
        XCTAssertEqual(try store.listProfiles(), [created])
    }

    func test_deleteProfile_removesFolder() throws {
        let profile = try store.createProfileDirectory(displayName: "Женя")
        try store.deleteProfile(id: profile.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.profileDirectory(for: profile.id).path))
    }

    func test_deleteProfile_whenMissing_throwsProfileNotFound() {
        XCTAssertThrowsError(try store.deleteProfile(id: UUID())) { error in
            XCTAssertEqual(error as? ProfileStoreError, .profileNotFound)
        }
    }
}
```

- [ ] **Step 3: Ask the user to run the tests and confirm they fail**

```bash
swift test --filter ProfileStoreTests
```
Expected: compilation errors (`ProfileStore`/`ProfileStoreError` not found) — paste the output back to confirm.

- [ ] **Step 4: Write the implementation**

`Sources/MyFin/Services/ProfileStore.swift`:
```swift
import Foundation

enum ProfileStoreError: Error, Equatable {
    case profileNotFound
    case ioFailure(String)
}

struct ProfileStore {
    let baseDirectory: URL

    init(baseDirectory: URL = ProfileStore.defaultBaseDirectory()) {
        self.baseDirectory = baseDirectory
    }

    static func defaultBaseDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("MyFin/profiles", isDirectory: true)
    }

    func profileDirectory(for id: UUID) -> URL {
        baseDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func databaseURL(for id: UUID) -> URL {
        profileDirectory(for: id).appendingPathComponent("db.sqlite")
    }

    private func metadataURL(for id: UUID) -> URL {
        profileDirectory(for: id).appendingPathComponent("profile.json")
    }

    func listProfiles() throws -> [Profile] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: baseDirectory.path) else { return [] }
        let entries = try fm.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var profiles: [Profile] = []
        for entry in entries {
            let metadataURL = entry.appendingPathComponent("profile.json")
            guard let data = try? Data(contentsOf: metadataURL),
                  let profile = try? decoder.decode(Profile.self, from: data) else { continue }
            profiles.append(profile)
        }
        return profiles.sorted { $0.createdAt < $1.createdAt }
    }

    func createProfileDirectory(displayName: String) throws -> Profile {
        let fm = FileManager.default
        let profile = Profile(id: UUID(), displayName: displayName, createdAt: Date())
        let dir = profileDirectory(for: profile.id)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(profile).write(to: metadataURL(for: profile.id))
        } catch {
            throw ProfileStoreError.ioFailure(error.localizedDescription)
        }
        return profile
    }

    func deleteProfile(id: UUID) throws {
        let fm = FileManager.default
        let dir = profileDirectory(for: id)
        guard fm.fileExists(atPath: dir.path) else {
            throw ProfileStoreError.profileNotFound
        }
        do {
            try fm.removeItem(at: dir)
        } catch {
            throw ProfileStoreError.ioFailure(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 5: Ask the user to re-run the tests and confirm they pass**

```bash
swift test --filter ProfileStoreTests
```
Expected: all 5 tests pass. Paste the output back.

---

### Task 3: SQLCipher database wrapper

**Files:**
- Create: `MyFin/Sources/MyFin/Services/DatabaseService.swift`
- Test: `MyFin/Tests/MyFinTests/DatabaseServiceTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks (works on a raw `URL` for the db file).
- Produces:
  - `enum DatabaseError: Error, Equatable { case openFailed(String); case keyingFailed(String); case wrongPassword; case rekeyFailed(String) }`
  - `final class DatabaseConnection { static func open(at url: URL, password: String) throws -> DatabaseConnection; func rekey(newPassword: String) throws; func close() }`
  - `DatabaseConnection.open` both creates the file (if missing) and opens it — later tasks use this single entry point for both "create profile" and "log in".

- [ ] **Step 1: Write the failing tests**

`Tests/MyFinTests/DatabaseServiceTests.swift`:
```swift
import XCTest
@testable import MyFin

final class DatabaseServiceTests: XCTestCase {
    var tempDirectory: URL!
    var dbURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyFinDBTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        dbURL = tempDirectory.appendingPathComponent("db.sqlite")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func test_open_createsDatabaseFile() throws {
        let connection = try DatabaseConnection.open(at: dbURL, password: "correct-horse")
        connection.close()
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
    }

    func test_open_withCorrectPassword_reopensSuccessfully() throws {
        try DatabaseConnection.open(at: dbURL, password: "correct-horse").close()
        try DatabaseConnection.open(at: dbURL, password: "correct-horse").close()
    }

    func test_open_withWrongPassword_throwsWrongPassword() throws {
        try DatabaseConnection.open(at: dbURL, password: "correct-horse").close()

        XCTAssertThrowsError(try DatabaseConnection.open(at: dbURL, password: "wrong-password")) { error in
            XCTAssertEqual(error as? DatabaseError, .wrongPassword)
        }
    }

    func test_rekey_allowsReopeningWithNewPasswordOnly() throws {
        let connection = try DatabaseConnection.open(at: dbURL, password: "old-password")
        try connection.rekey(newPassword: "new-password")
        connection.close()

        try DatabaseConnection.open(at: dbURL, password: "new-password").close()

        XCTAssertThrowsError(try DatabaseConnection.open(at: dbURL, password: "old-password"))
    }
}
```

- [ ] **Step 2: Ask the user to run the tests and confirm they fail**

```bash
swift test --filter DatabaseServiceTests
```
Expected: compilation errors (`DatabaseConnection` not found). Paste the output back.

- [ ] **Step 3: Write the implementation**

`Sources/MyFin/Services/DatabaseService.swift`:
```swift
import Foundation
import SQLCipher

enum DatabaseError: Error, Equatable {
    case openFailed(String)
    case keyingFailed(String)
    case wrongPassword
    case rekeyFailed(String)
}

final class DatabaseConnection {
    private var handle: OpaquePointer?

    private init(handle: OpaquePointer) {
        self.handle = handle
    }

    static func open(at url: URL, password: String) throws -> DatabaseConnection {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let openResult = sqlite3_open_v2(url.path, &db, flags, nil)
        guard openResult == SQLITE_OK, let handle = db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close_v2(db)
            throw DatabaseError.openFailed(message)
        }

        let keyResult = password.withCString { cPassword in
            sqlite3_key(handle, cPassword, Int32(strlen(cPassword)))
        }
        guard keyResult == SQLITE_OK else {
            sqlite3_close_v2(handle)
            throw DatabaseError.keyingFailed("sqlite3_key failed with code \(keyResult)")
        }

        // sqlite3_key() only derives a key; it never touches the file. A wrong
        // password is only revealed once we actually try to read the header.
        let checkResult = sqlite3_exec(handle, "SELECT count(*) FROM sqlite_master;", nil, nil, nil)
        guard checkResult == SQLITE_OK else {
            sqlite3_close_v2(handle)
            throw DatabaseError.wrongPassword
        }

        return DatabaseConnection(handle: handle)
    }

    func rekey(newPassword: String) throws {
        guard let handle else { return }
        let result = newPassword.withCString { cPassword in
            sqlite3_rekey(handle, cPassword, Int32(strlen(cPassword)))
        }
        guard result == SQLITE_OK else {
            throw DatabaseError.rekeyFailed("sqlite3_rekey failed with code \(result)")
        }
    }

    func close() {
        guard let handle else { return }
        sqlite3_close_v2(handle)
        self.handle = nil
    }

    deinit {
        close()
    }
}
```

Troubleshooting if `SQLITE_OPEN_READWRITE`/`SQLITE_OK`/etc. are unresolved: these come from SQLCipher's bundled `sqlite3.h` re-exported through `import SQLCipher`; if the compiler can't find them, ask the user to check the module's generated interface (`swift package show-dependencies` then inspect the checked-out package) for the exact re-exported symbol names and adjust.

- [ ] **Step 4: Ask the user to re-run the tests and confirm they pass**

```bash
swift test --filter DatabaseServiceTests
```
Expected: all 4 tests pass. Paste the output back.

---

### Task 4: Keychain service

**Files:**
- Create: `MyFin/Sources/MyFin/Services/KeychainService.swift`
- Test: `MyFin/Tests/MyFinTests/KeychainServiceTests.swift`

**Interfaces:**
- Produces:
  - `enum KeychainError: Error { case unhandledStatus(OSStatus) }`
  - `struct KeychainService { let service: String; func savePassword(_ password: String, for profileId: UUID) throws; func readPassword(for profileId: UUID) -> String?; func deletePassword(for profileId: UUID) }`

- [ ] **Step 1: Write the failing tests**

`Tests/MyFinTests/KeychainServiceTests.swift`:
```swift
import XCTest
@testable import MyFin

final class KeychainServiceTests: XCTestCase {
    let service = "com.myfin.local.tests"
    var profileId: UUID!
    var keychain: KeychainService!

    override func setUpWithError() throws {
        profileId = UUID()
        keychain = KeychainService(service: service)
    }

    override func tearDownWithError() throws {
        keychain.deletePassword(for: profileId)
    }

    func test_savePassword_thenReadPassword_roundTrips() throws {
        try keychain.savePassword("s3cret", for: profileId)
        XCTAssertEqual(keychain.readPassword(for: profileId), "s3cret")
    }

    func test_readPassword_whenNotSaved_returnsNil() {
        XCTAssertNil(keychain.readPassword(for: profileId))
    }

    func test_savePassword_overwritesExistingValue() throws {
        try keychain.savePassword("first", for: profileId)
        try keychain.savePassword("second", for: profileId)
        XCTAssertEqual(keychain.readPassword(for: profileId), "second")
    }

    func test_deletePassword_removesEntry() throws {
        try keychain.savePassword("s3cret", for: profileId)
        keychain.deletePassword(for: profileId)
        XCTAssertNil(keychain.readPassword(for: profileId))
    }
}
```

- [ ] **Step 2: Ask the user to run the tests and confirm they fail**

```bash
swift test --filter KeychainServiceTests
```
Expected: compilation errors (`KeychainService` not found). Paste the output back.

- [ ] **Step 3: Write the implementation**

`Sources/MyFin/Services/KeychainService.swift`:
```swift
import Foundation
import Security

enum KeychainError: Error {
    case unhandledStatus(OSStatus)
}

struct KeychainService {
    let service: String

    func savePassword(_ password: String, for profileId: UUID) throws {
        let account = profileId.uuidString
        let data = Data(password.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    func readPassword(for profileId: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deletePassword(for profileId: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileId.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 4: Ask the user to re-run the tests and confirm they pass**

```bash
swift test --filter KeychainServiceTests
```
Expected: all 4 tests pass. Note: the first run may show a one-time macOS "keychain access" permission dialog — ask the user to allow it. Paste the output back.

---

### Task 5: AppSession and the profile/auth flow UI

**Files:**
- Create: `MyFin/Sources/MyFin/AppSession.swift`
- Create: `MyFin/Sources/MyFin/Views/ProfilePickerView.swift`
- Create: `MyFin/Sources/MyFin/Views/CreateProfileView.swift`
- Create: `MyFin/Sources/MyFin/Views/LoginView.swift`
- Modify: `MyFin/Sources/MyFin/MyFinApp.swift`
- Test: `MyFin/Tests/MyFinTests/AppSessionTests.swift`

**Interfaces:**
- Consumes: `Profile`, `ProfileStore`, `ProfileStoreError` (Task 2); `DatabaseConnection`, `DatabaseError` (Task 3); `KeychainService` (Task 4).
- Produces:
  - `final class AppSession: ObservableObject` with `enum Screen: Equatable { case profilePicker; case mainShell }`, published `screen: Screen`, `profiles: [Profile]`, `errorMessage: String?`, and methods `refreshProfiles()`, `createProfile(displayName:password:remember:)`, `logIn(profile:password:)`, `logInWithRememberedPassword(profile:) -> Bool`, `deleteProfile(_:)`, `logOut()`, `changePassword(newPassword:)`, plus a read-only `unlockedProfile: Profile?`.
  - Later tasks (Task 6) read `session.unlockedProfile` and call `session.logOut()` / `session.changePassword(newPassword:)`.

- [ ] **Step 1: Write the failing `AppSession` tests**

`Tests/MyFinTests/AppSessionTests.swift`:
```swift
import XCTest
@testable import MyFin

@MainActor
final class AppSessionTests: XCTestCase {
    var tempDirectory: URL!
    var session: AppSession!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyFinSessionTests-\(UUID().uuidString)", isDirectory: true)
        let store = ProfileStore(baseDirectory: tempDirectory)
        let keychain = KeychainService(service: "com.myfin.local.tests.session")
        session = AppSession(profileStore: store, keychain: keychain)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func test_createProfile_switchesToMainShellAndUnlocksProfile() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        XCTAssertEqual(session.screen, .mainShell)
        XCTAssertEqual(session.unlockedProfile?.displayName, "Женя")
        XCTAssertNil(session.errorMessage)
    }

    func test_logOut_returnsToProfilePickerAndKeepsProfileListed() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        session.logOut()
        XCTAssertEqual(session.screen, .profilePicker)
        XCTAssertNil(session.unlockedProfile)
        XCTAssertEqual(session.profiles.count, 1)
    }

    func test_logIn_withWrongPassword_setsErrorMessageAndStaysOnPicker() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        let profile = session.profiles[0]
        session.logOut()

        session.logIn(profile: profile, password: "wrong")
        XCTAssertEqual(session.screen, .profilePicker)
        XCTAssertEqual(session.errorMessage, "Неверный пароль")
    }

    func test_logIn_withCorrectPassword_unlocksProfile() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        let profile = session.profiles[0]
        session.logOut()

        session.logIn(profile: profile, password: "pw1")
        XCTAssertEqual(session.screen, .mainShell)
        XCTAssertEqual(session.unlockedProfile?.id, profile.id)
    }

    func test_logInWithRememberedPassword_whenRemembered_unlocksWithoutPrompt() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: true)
        let profile = session.profiles[0]
        session.logOut()

        XCTAssertTrue(session.logInWithRememberedPassword(profile: profile))
        XCTAssertEqual(session.screen, .mainShell)
    }

    func test_deleteProfile_removesItFromList() {
        session.createProfile(displayName: "Женя", password: "pw1", remember: false)
        let profile = session.profiles[0]
        session.logOut()

        session.deleteProfile(profile)
        XCTAssertTrue(session.profiles.isEmpty)
    }
}
```

- [ ] **Step 2: Ask the user to run the tests and confirm they fail**

```bash
swift test --filter AppSessionTests
```
Expected: compilation errors (`AppSession` not found). Paste the output back.

- [ ] **Step 3: Write `AppSession`**

`Sources/MyFin/AppSession.swift`:
```swift
import Foundation

@MainActor
final class AppSession: ObservableObject {
    enum Screen: Equatable {
        case profilePicker
        case mainShell
    }

    @Published var screen: Screen = .profilePicker
    @Published var profiles: [Profile] = []
    @Published var errorMessage: String?

    private(set) var unlockedProfile: Profile?
    private var connection: DatabaseConnection?

    let profileStore: ProfileStore
    let keychain: KeychainService

    init(profileStore: ProfileStore = ProfileStore(), keychain: KeychainService = KeychainService(service: "com.myfin.local")) {
        self.profileStore = profileStore
        self.keychain = keychain
        refreshProfiles()
    }

    func refreshProfiles() {
        profiles = (try? profileStore.listProfiles()) ?? []
    }

    func createProfile(displayName: String, password: String, remember: Bool) {
        do {
            let profile = try profileStore.createProfileDirectory(displayName: displayName)
            let connection = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: password)
            if remember {
                try? keychain.savePassword(password, for: profile.id)
            }
            self.connection = connection
            self.unlockedProfile = profile
            self.errorMessage = nil
            self.screen = .mainShell
            refreshProfiles()
        } catch {
            errorMessage = "Не удалось создать профиль: \(error.localizedDescription)"
        }
    }

    func logIn(profile: Profile, password: String) {
        do {
            let connection = try DatabaseConnection.open(at: profileStore.databaseURL(for: profile.id), password: password)
            self.connection = connection
            self.unlockedProfile = profile
            self.errorMessage = nil
            self.screen = .mainShell
        } catch DatabaseError.wrongPassword {
            errorMessage = "Неверный пароль"
        } catch {
            errorMessage = "Не удалось открыть профиль: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func logInWithRememberedPassword(profile: Profile) -> Bool {
        guard let password = keychain.readPassword(for: profile.id) else { return false }
        logIn(profile: profile, password: password)
        return unlockedProfile?.id == profile.id
    }

    func deleteProfile(_ profile: Profile) {
        keychain.deletePassword(for: profile.id)
        try? profileStore.deleteProfile(id: profile.id)
        refreshProfiles()
    }

    func logOut() {
        connection?.close()
        connection = nil
        unlockedProfile = nil
        screen = .profilePicker
        refreshProfiles()
    }

    func changePassword(newPassword: String) {
        guard let connection, let profile = unlockedProfile else { return }
        do {
            try connection.rekey(newPassword: newPassword)
            if keychain.readPassword(for: profile.id) != nil {
                try? keychain.savePassword(newPassword, for: profile.id)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось сменить пароль: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 4: Ask the user to re-run the tests and confirm they pass**

```bash
swift test --filter AppSessionTests
```
Expected: all 6 tests pass. Paste the output back.

- [ ] **Step 5: Write the picker, create, and login views**

`Sources/MyFin/Views/ProfilePickerView.swift`:
```swift
import SwiftUI

struct ProfilePickerView: View {
    @ObservedObject var session: AppSession
    @State private var showingCreateProfile = false
    @State private var loginTarget: Profile?

    var body: some View {
        VStack(spacing: 16) {
            Text("MyFin").font(.largeTitle.bold())

            if session.profiles.isEmpty {
                Text("Профилей пока нет")
                    .foregroundStyle(.secondary)
            } else {
                List(session.profiles) { profile in
                    HStack {
                        Text(profile.displayName)
                        Spacer()
                        Button("Войти") { attemptLogin(profile) }
                        Button(role: .destructive) {
                            session.deleteProfile(profile)
                        } label: {
                            Text("Удалить")
                        }
                    }
                }
                .frame(minHeight: 120)
            }

            if let message = session.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            Button("Создать профиль") { showingCreateProfile = true }
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 320)
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView(session: session)
        }
        .sheet(item: $loginTarget) { profile in
            LoginView(session: session, profile: profile)
        }
        .onAppear { session.refreshProfiles() }
    }

    private func attemptLogin(_ profile: Profile) {
        if session.logInWithRememberedPassword(profile: profile) {
            return
        }
        loginTarget = profile
    }
}
```

`Sources/MyFin/Views/CreateProfileView.swift`:
```swift
import SwiftUI

struct CreateProfileView: View {
    @ObservedObject var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var rememberPassword = false
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Новый профиль").font(.title2.bold())

            TextField("Имя профиля", text: $displayName)
            SecureField("Пароль", text: $password)
            SecureField("Повторите пароль", text: $confirmPassword)
            Toggle("Запомнить пароль в Keychain", isOn: $rememberPassword)

            Text("Пароль нельзя восстановить: если вы его забудете, доступ к данным профиля будет утерян.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let localError {
                Text(localError).foregroundStyle(.red)
            }

            HStack {
                Button("Отмена") { dismiss() }
                Spacer()
                Button("Создать") { submit() }
                    .disabled(displayName.isEmpty || password.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }

    private func submit() {
        guard password == confirmPassword else {
            localError = "Пароли не совпадают"
            return
        }
        session.createProfile(displayName: displayName, password: password, remember: rememberPassword)
        if session.errorMessage == nil {
            dismiss()
        }
    }
}
```

`Sources/MyFin/Views/LoginView.swift`:
```swift
import SwiftUI

struct LoginView: View {
    @ObservedObject var session: AppSession
    let profile: Profile
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Вход: \(profile.displayName)").font(.title2.bold())
            SecureField("Пароль", text: $password)
                .onSubmit { submit() }

            if let message = session.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            HStack {
                Button("Отмена") { dismiss() }
                Spacer()
                Button("Войти") { submit() }
                    .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
    }

    private func submit() {
        session.logIn(profile: profile, password: password)
        if session.unlockedProfile?.id == profile.id {
            dismiss()
        }
    }
}
```

- [ ] **Step 6: Wire `MyFinApp` to `AppSession`**

Replace the contents of `Sources/MyFin/MyFinApp.swift`:
```swift
import SwiftUI

@main
struct MyFinApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.screen == .profilePicker {
                    ProfilePickerView(session: session)
                } else {
                    Text("Основной экран появится в Task 6")
                }
            }
            .frame(minWidth: 700, minHeight: 480)
        }
    }
}
```
(The `else` branch is a temporary placeholder — Task 6 replaces it with `MainShellView`.)

- [ ] **Step 7: Ask the user to build and manually verify**

```bash
swift build
swift run
```

Manual checklist to confirm with the user:
1. First launch shows the profile picker with "Профилей пока нет" and no crash.
2. "Создать профиль" → fill name/password/confirm, leave "запомнить пароль" off → submit → window switches to the Task-6 placeholder text (confirms `AppSession.screen` flipped to `.mainShell`).
3. Quit (Cmd+Q) and relaunch (`swift run` again) → the picker now lists the created profile.
4. Click "Войти" on that profile, type the correct password → placeholder screen appears again.
5. Log out isn't wired to any button yet (that's Task 6), so just quit and relaunch, then click "Войти" and type a **wrong** password → inline "Неверный пароль" appears and the window stays on the picker.
6. Repeat profile creation with "запомнить пароль" checked → quit, relaunch, click "Войти" → it unlocks immediately without asking for a password.

Have the user confirm each point before moving to Task 6.

---

### Task 6: Main shell — sidebar with 5 pages and settings actions

**Files:**
- Create: `MyFin/Sources/MyFin/Views/PlaceholderPageView.swift`
- Create: `MyFin/Sources/MyFin/Views/SettingsView.swift`
- Create: `MyFin/Sources/MyFin/Views/MainShellView.swift`
- Modify: `MyFin/Sources/MyFin/MyFinApp.swift`

**Interfaces:**
- Consumes: `AppSession` (Task 5) — `session.unlockedProfile`, `session.logOut()`, `session.changePassword(newPassword:)`, `session.errorMessage`.
- Produces: `MainShellView`, the app's main authenticated screen, used by `MyFinApp`.

- [ ] **Step 1: Write the placeholder page view**

`Sources/MyFin/Views/PlaceholderPageView.swift`:
```swift
import SwiftUI

struct PlaceholderPageView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.largeTitle.bold())
            Text(message).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Write the settings view**

`Sources/MyFin/Views/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: AppSession
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var localError: String?
    @State private var didChangePassword = false

    var body: some View {
        Form {
            Section("Смена пароля") {
                SecureField("Новый пароль", text: $newPassword)
                SecureField("Повторите новый пароль", text: $confirmNewPassword)
                if let localError {
                    Text(localError).foregroundStyle(.red)
                }
                if didChangePassword {
                    Text("Пароль изменён").foregroundStyle(.green)
                }
                Button("Сменить пароль") { changePassword() }
                    .disabled(newPassword.isEmpty)
            }

            Section {
                Button("Выйти из профиля", role: .destructive) {
                    session.logOut()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func changePassword() {
        guard newPassword == confirmNewPassword else {
            localError = "Пароли не совпадают"
            didChangePassword = false
            return
        }
        session.changePassword(newPassword: newPassword)
        localError = session.errorMessage
        didChangePassword = (session.errorMessage == nil)
        newPassword = ""
        confirmNewPassword = ""
    }
}
```

- [ ] **Step 3: Write the main shell with sidebar navigation**

`Sources/MyFin/Views/MainShellView.swift`:
```swift
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Дашборд"
    case accounts = "Аккаунты"
    case cashflow = "Cashflow"
    case assets = "Активы"
    case settings = "Настройки"

    var id: String { rawValue }
}

struct MainShellView: View {
    @ObservedObject var session: AppSession
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Text(item.rawValue)
            }
            .navigationTitle(session.unlockedProfile?.displayName ?? "MyFin")
        } detail: {
            switch selection {
            case .dashboard:
                PlaceholderPageView(title: "Дашборд", message: "Дашборд — здесь скоро появится содержимое")
            case .accounts:
                PlaceholderPageView(title: "Аккаунты", message: "Аккаунты — здесь скоро появится содержимое")
            case .cashflow:
                PlaceholderPageView(title: "Cashflow", message: "Cashflow — здесь скоро появится содержимое")
            case .assets:
                PlaceholderPageView(title: "Активы", message: "Активы — здесь скоро появится содержимое")
            case .settings:
                SettingsView(session: session)
            case .none:
                PlaceholderPageView(title: "MyFin", message: "Выберите раздел слева")
            }
        }
    }
}
```

- [ ] **Step 4: Wire it into `MyFinApp`**

Replace the contents of `Sources/MyFin/MyFinApp.swift`:
```swift
import SwiftUI

@main
struct MyFinApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.screen == .profilePicker {
                    ProfilePickerView(session: session)
                } else {
                    MainShellView(session: session)
                }
            }
            .frame(minWidth: 700, minHeight: 480)
        }
    }
}
```

- [ ] **Step 5: Ask the user to build and manually verify the full flow**

```bash
swift build
swift run
```

Manual checklist to confirm with the user:
1. Create (or log into) a profile → the main shell appears with a sidebar listing Дашборд, Аккаунты, Cashflow, Активы, Настройки, and the sidebar's title matches the profile's display name.
2. Clicking each of Дашборд/Аккаунты/Cashflow/Активы shows that page's centered placeholder title + "здесь скоро появится содержимое" message on the right.
3. Clicking Настройки shows the change-password form and a "Выйти из профиля" button.
4. Type a new password (matching in both fields) and click "Сменить пароль" → "Пароль изменён" appears.
5. Click "Выйти из профиля" → returns to the profile picker.
6. Relaunch and log into that same profile using the **new** password (the old one should no longer work) — confirms the rekey persisted to disk.

Have the user confirm all six points. This completes the MVP shell described in the spec.

---

## Self-Review Notes

- **Spec coverage:** every spec section maps to a task — stack/SPM setup → Task 1; profile model & storage → Task 2; SQLCipher encryption → Task 3; Keychain → Task 4; profile picker/create/login screens → Task 5; main shell + settings stub actions → Task 6. The spec's "no recovery" and "no retry-count" decisions are reflected in the UI code (no reset-password affordance, no attempt counter) and called out in `CreateProfileView`'s copy.
- **Type consistency checked:** `Profile`, `ProfileStore`, `ProfileStoreError`, `DatabaseConnection`, `DatabaseError`, `KeychainService`, `KeychainError`, `AppSession` (and its `Screen` enum and method signatures) are used identically across every task that references them.
- **No placeholders:** every step contains complete, runnable code; the one intentional in-app placeholder (Task 5 Step 6's temporary `Text(...)`) is explicitly called out as temporary and replaced in Task 6 Step 4.
