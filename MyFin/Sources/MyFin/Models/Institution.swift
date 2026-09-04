import Foundation

enum InstitutionSource: String, Codable, Equatable {
    case system
    case custom
}

struct Institution: Identifiable, Equatable {
    let id: String
    let source: InstitutionSource
    var country: Country
    var name: String
    let aliases: [String]
    var archived: Bool
    let createdAt: Date
    var updatedAt: Date
}

enum InstitutionPickerItem: Identifiable, Equatable {
    case institution(Institution)
    case otherBank

    var id: String {
        switch self {
        case .institution(let institution): return institution.id
        case .otherBank: return "__other_bank__"
        }
    }
}

enum InstitutionError: Error, Equatable {
    case systemInstitutionIsReadOnly
    case inUse
    case conflictWithArchived(Institution)
    case notFound
    case invalidName
}

enum InstitutionSelection: Equatable {
    case existing(id: String)
    case none
    case newCustom(name: String)
}
