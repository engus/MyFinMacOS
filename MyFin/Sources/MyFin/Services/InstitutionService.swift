import Foundation

final class InstitutionService {
    private let connection: DatabaseConnection

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    func listInstitutions(country: Country) throws -> [InstitutionPickerItem] {
        let rows = try connection.query(
            "SELECT * FROM institutions WHERE country = ? AND archived = 0 ORDER BY source DESC, name ASC;",
            params: [.text(country.rawValue)]
        )
        let institutions = rows.compactMap(Self.rowToInstitution)
        return institutions.map(InstitutionPickerItem.institution) + [.otherBank]
    }

    func search(query: String, in country: Country) throws -> [InstitutionPickerItem] {
        let all = try listInstitutions(country: country)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let lowered = trimmed.lowercased()
        return all.filter { item in
            switch item {
            case .otherBank:
                return true
            case .institution(let institution):
                if institution.name.lowercased().contains(lowered) { return true }
                return institution.aliases.contains { $0.lowercased().contains(lowered) }
            }
        }
    }

    static func rowToInstitution(_ row: [String: SQLValue]) -> Institution? {
        guard case let .text(id)? = row["id"],
              case let .text(sourceRaw)? = row["source"],
              let source = InstitutionSource(rawValue: sourceRaw),
              case let .text(countryRaw)? = row["country"],
              let country = Country(rawValue: countryRaw),
              case let .text(name)? = row["name"],
              case let .text(aliasesJSON)? = row["aliases"],
              case let .int(archivedInt)? = row["archived"],
              case let .text(createdAtRaw)? = row["created_at"],
              case let .text(updatedAtRaw)? = row["updated_at"]
        else { return nil }

        let aliases = (try? JSONDecoder().decode([String].self, from: Data(aliasesJSON.utf8))) ?? []
        let formatter = ISO8601DateFormatter()
        let createdAt = formatter.date(from: createdAtRaw) ?? Date()
        let updatedAt = formatter.date(from: updatedAtRaw) ?? Date()

        return Institution(
            id: id, source: source, country: country, name: name, aliases: aliases,
            archived: archivedInt != 0, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

extension InstitutionService {
    func resolveOrCreateCustomInstitution(name: String, country: Country) -> Result<Institution, InstitutionError> {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .failure(.invalidName) }

        let existingRows = (try? connection.query(
            "SELECT * FROM institutions WHERE source = 'custom' AND country = ? AND lower(trim(name)) = lower(trim(?));",
            params: [.text(country.rawValue), .text(normalized)]
        )) ?? []

        if let row = existingRows.first, let existing = Self.rowToInstitution(row) {
            if existing.archived {
                return .failure(.conflictWithArchived(existing))
            }
            return .success(existing)
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let id = UUID().uuidString
        do {
            try connection.execute(
                "INSERT INTO institutions (id, source, country, name, aliases, archived, created_at, updated_at) VALUES (?, 'custom', ?, ?, '[]', 0, ?, ?);",
                params: [.text(id), .text(country.rawValue), .text(normalized), .text(now), .text(now)]
            )
        } catch {
            return .failure(.notFound)
        }
        return .success(Institution(id: id, source: .custom, country: country, name: normalized, aliases: [], archived: false, createdAt: Date(), updatedAt: Date()))
    }

    func listCustomInstitutions(includeArchived: Bool) -> [Institution] {
        let sql = includeArchived
            ? "SELECT * FROM institutions WHERE source = 'custom' ORDER BY country ASC, name ASC;"
            : "SELECT * FROM institutions WHERE source = 'custom' AND archived = 0 ORDER BY country ASC, name ASC;"
        let rows = (try? connection.query(sql)) ?? []
        return rows.compactMap(Self.rowToInstitution)
    }

    private func fetchInstitution(id: String) -> Institution? {
        guard let rows = try? connection.query("SELECT * FROM institutions WHERE id = ?;", params: [.text(id)]),
              let row = rows.first else { return nil }
        return Self.rowToInstitution(row)
    }

    private func requireCustom(id: String) -> Result<Institution, InstitutionError> {
        guard let institution = fetchInstitution(id: id) else { return .failure(.notFound) }
        guard institution.source == .custom else { return .failure(.systemInstitutionIsReadOnly) }
        return .success(institution)
    }

    func renameCustomInstitution(id: String, name: String) -> Result<Institution, InstitutionError> {
        switch requireCustom(id: id) {
        case .failure(let error): return .failure(error)
        case .success:
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .failure(.invalidName) }
            let now = ISO8601DateFormatter().string(from: Date())
            _ = try? connection.execute("UPDATE institutions SET name = ?, updated_at = ? WHERE id = ?;", params: [.text(trimmed), .text(now), .text(id)])
            guard let updated = fetchInstitution(id: id) else { return .failure(.notFound) }
            return .success(updated)
        }
    }

    func archiveCustomInstitution(id: String) -> Result<Institution, InstitutionError> {
        switch requireCustom(id: id) {
        case .failure(let error): return .failure(error)
        case .success:
            let now = ISO8601DateFormatter().string(from: Date())
            _ = try? connection.execute("UPDATE institutions SET archived = 1, updated_at = ? WHERE id = ?;", params: [.text(now), .text(id)])
            guard let updated = fetchInstitution(id: id) else { return .failure(.notFound) }
            return .success(updated)
        }
    }

    func restoreCustomInstitution(id: String) -> Result<Institution, InstitutionError> {
        switch requireCustom(id: id) {
        case .failure(let error): return .failure(error)
        case .success:
            let now = ISO8601DateFormatter().string(from: Date())
            _ = try? connection.execute("UPDATE institutions SET archived = 0, updated_at = ? WHERE id = ?;", params: [.text(now), .text(id)])
            guard let updated = fetchInstitution(id: id) else { return .failure(.notFound) }
            return .success(updated)
        }
    }

    func changeCustomInstitutionCountry(id: String, country: Country) -> Result<Institution, InstitutionError> {
        switch requireCustom(id: id) {
        case .failure(let error): return .failure(error)
        case .success:
            let inUseRows = (try? connection.query("SELECT COUNT(*) AS c FROM accounts WHERE institution_id = ?;", params: [.text(id)])) ?? []
            if case let .int(count)? = inUseRows.first?["c"], count > 0 {
                return .failure(.inUse)
            }
            let now = ISO8601DateFormatter().string(from: Date())
            _ = try? connection.execute("UPDATE institutions SET country = ?, updated_at = ? WHERE id = ?;", params: [.text(country.rawValue), .text(now), .text(id)])
            guard let updated = fetchInstitution(id: id) else { return .failure(.notFound) }
            return .success(updated)
        }
    }
}
