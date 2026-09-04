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
        decoder.dateDecodingStrategy = .secondsSince1970
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
        // Rounded to the nearest second so the createdAt round-trips exactly
        // through JSON's `.secondsSince1970` encoding (a Double) — an
        // unrounded timestamp can carry sub-second precision that JSON's
        // text-based number serialization doesn't always preserve bit-for-bit,
        // which previously showed up as flaky equality failures on freshly
        // created profiles. Whole-second precision is all this app needs for
        // sorting profiles by creation time.
        let createdAt = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded())
        let profile = Profile(id: UUID(), displayName: displayName, createdAt: createdAt)
        let dir = profileDirectory(for: profile.id)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            try encoder.encode(profile).write(to: metadataURL(for: profile.id))
        } catch {
            throw ProfileStoreError.ioFailure(error.localizedDescription)
        }
        return profile
    }

    func updateProfile(_ profile: Profile) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            try encoder.encode(profile).write(to: metadataURL(for: profile.id))
        } catch {
            throw ProfileStoreError.ioFailure(error.localizedDescription)
        }
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
