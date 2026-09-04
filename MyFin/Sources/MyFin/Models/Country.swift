import Foundation

enum Country: String, Codable, CaseIterable, Equatable {
    case kz = "KZ"
    case ae = "AE"
    case ru = "RU"
    case us = "US"

    var displayName: String {
        switch self {
        case .kz: return "Kazakhstan"
        case .ae: return "United Arab Emirates"
        case .ru: return "Russia"
        case .us: return "United States"
        }
    }

    var flag: String {
        switch self {
        case .kz: return "🇰🇿"
        case .ae: return "🇦🇪"
        case .ru: return "🇷🇺"
        case .us: return "🇺🇸"
        }
    }
}
