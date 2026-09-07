import Foundation

enum AccountThemePreset: String, CaseIterable { case obsidianMatte, sapphireWave, emeraldGlass, roseGoldMetallic, titaniumFrost, cyberHologram }
enum AccountAccentTint: String, CaseIterable { case blue, green, orange, purple, pink, gray }
enum AccountBadgeIcon: String, CaseIterable { case bank, card, wallet, lock, chart }
enum PaymentNetwork: String, CaseIterable { case mastercard, visa, kaspiPay, unionPay, virtual }

struct AccountAppearance: Equatable {
    var themePreset: AccountThemePreset = .obsidianMatte
    var accentTint: AccountAccentTint = .blue
    var badgeIcon: AccountBadgeIcon = .card
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
