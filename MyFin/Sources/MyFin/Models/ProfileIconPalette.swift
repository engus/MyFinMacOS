import SwiftUI

enum ProfileIconPalette {
    static let iconNames = [
        "person.crop.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "leaf.circle.fill",
        "bolt.circle.fill",
        "moon.circle.fill",
        "sun.max.circle.fill",
        "pawprint.circle.fill",
        "gift.circle.fill",
        "car.circle.fill",
        "airplane.circle.fill",
        "graduationcap.circle.fill"
    ]

    static let colorNames = ["blue", "green", "orange", "pink", "purple", "red", "teal", "yellow"]

    static func color(named name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "red": return .red
        case "teal": return .teal
        case "yellow": return .yellow
        default: return .blue
        }
    }
}
