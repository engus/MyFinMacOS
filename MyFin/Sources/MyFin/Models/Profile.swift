import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    let createdAt: Date
    var iconName: String
    var iconColor: String
    var hasCompletedOnboarding: Bool

    static let defaultIconName = "person.crop.circle.fill"
    static let defaultIconColor = "blue"

    init(
        id: UUID,
        displayName: String,
        createdAt: Date,
        iconName: String = Profile.defaultIconName,
        iconColor: String = Profile.defaultIconColor,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.iconName = iconName
        self.iconColor = iconColor
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, createdAt, iconName, iconColor, hasCompletedOnboarding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? Profile.defaultIconName
        iconColor = try container.decodeIfPresent(String.self, forKey: .iconColor) ?? Profile.defaultIconColor
        // A profile.json written before this feature existed has no key here
        // at all -- that must decode to `true` (never show onboarding
        // retroactively to an existing profile). A newly-constructed Profile
        // uses the memberwise initializer above, whose default is `false`.
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? true
    }
}
