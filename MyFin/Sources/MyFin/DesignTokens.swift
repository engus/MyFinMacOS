import SwiftUI

/// Native, appearance-aware values taken from docs/design/sidebar_dashboard and accounts.
enum DesignTokens {
    enum Colors {
        static let accent = Color(red: 0, green: 122 / 255, blue: 1)
        static let canvas = adaptive(light: 0xFCFCFD, dark: 0x1C1C1E)
        static let cardBackground = adaptive(light: 0xFFFFFF, dark: 0x252527)
        static let subtleBackground = adaptive(light: 0xF5F6F8, dark: 0x2D2D30)
        static let cardBorder = Color.primary.opacity(0.08)
        static let sectionHeader = Color.secondary
        static let positive = Color(nsColor: .systemGreen)
        static let negative = Color(nsColor: .systemRed)
        static let secondaryAccent = Color(nsColor: .systemIndigo)

        private static func adaptive(light: UInt32, dark: UInt32) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
                return NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                               green: CGFloat((rgb >> 8) & 255) / 255,
                               blue: CGFloat(rgb & 255) / 255, alpha: 1)
            })
        }
    }

    enum Metrics {
        static let cardCornerRadius: CGFloat = 12
        static let cardPadding: CGFloat = 20
        static let cardBorderWidth: CGFloat = 1
        static let sectionSpacing: CGFloat = 24
        static let pagePadding: CGFloat = 32
        static let sidebarDotSize: CGFloat = 8
    }

    static func color(for key: String) -> Color {
        if key == "__cash__" { return .green }
        if let name = SystemInstitutionCatalog.color(forID: key) { return ProfileIconPalette.color(named: name) }
        let colors: [Color] = [.blue, .green, .indigo, .orange, .purple, .teal]
        // Swift's hashValue changes between launches; keep custom account colors stable.
        let hash = key.utf8.reduce(UInt(0)) { ($0 &* 31) &+ UInt($1) }
        return colors[Int(hash % UInt(colors.count))]
    }

    static func color(for account: Account) -> Color {
        color(for: account.type == .cash ? "__cash__" : (account.institutionId ?? account.id))
    }
}

extension View {
    func cardSurface() -> some View {
        background(DesignTokens.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Metrics.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.cardBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.025), radius: 2, y: 1)
    }

    func dashboardCardStyle() -> some View {
        padding(DesignTokens.Metrics.cardPadding).cardSurface()
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .background(configuration.isPressed ? Color.primary.opacity(0.09) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
    }
}

extension ToolbarContent {
    /// Keep the breadcrumb as plain text on Tahoe, as on the reference's unified titlebar.
    @ToolbarContentBuilder func flatToolbarBackground() -> some ToolbarContent {
        if #available(macOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
