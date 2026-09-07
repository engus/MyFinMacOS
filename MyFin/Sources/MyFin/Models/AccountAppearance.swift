import Foundation

enum AccountThemePreset: String, CaseIterable { case obsidianMatte, sapphireWave, emeraldGlass, roseGoldMetallic, titaniumFrost, cyberHologram }
enum AccountAccentTint: String, CaseIterable { case blue, green, orange, purple, pink, gray }
enum AccountBadgeIcon: String, CaseIterable { case bank, card, wallet, lock, chart }
enum PaymentNetwork: String, CaseIterable { case mastercard, visa, kaspiPay, unionPay, virtual }

struct AccountAppearance: Equatable {
    var themePreset: AccountThemePreset = .obsidianMatte
    var accentTint: AccountAccentTint {
        switch themePreset {
        case .obsidianMatte, .titaniumFrost: return .gray
        case .sapphireWave: return .blue
        case .emeraldGlass: return .green
        case .roseGoldMetallic: return .orange
        case .cyberHologram: return .purple
        }
    }
    var badgeIcon: AccountBadgeIcon {
        switch themePreset {
        case .obsidianMatte, .roseGoldMetallic: return .card
        case .sapphireWave: return .bank
        case .emeraldGlass: return .wallet
        case .titaniumFrost: return .lock
        case .cyberHologram: return .chart
        }
    }
    var tags: [String] = []
    var paymentNetwork: PaymentNetwork? = .mastercard

    func sanitized(for type: AccountType) -> Self {
        var value = self
        var seen = Set<String>()
        value.tags = tags.compactMap {
            let text = String($0.trimmingCharacters(in: .whitespacesAndNewlines).drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespacesAndNewlines)
            return !text.isEmpty && seen.insert(text.lowercased()).inserted ? text : nil
        }
        if type != .debitCard {
            value.paymentNetwork = nil
        }
        return value
    }
}
