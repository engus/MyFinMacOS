import SwiftUI

extension AccountThemePreset {
    var title: String {
        switch self {
        case .obsidianMatte: return "Obsidian Matte"
        case .sapphireWave: return "Sapphire Wave"
        case .emeraldGlass: return "Emerald Glass"
        case .roseGoldMetallic: return "Solar Flare"
        case .titaniumFrost: return "Titanium Frost"
        case .cyberHologram: return "Cyber Hologram"
        }
    }
    var colors: [Color] {
        let hex: [UInt32]
        switch self {
        case .obsidianMatte: hex = [0x30353C, 0x202328, 0x111315]
        case .sapphireWave: hex = [0x0A47A3, 0x007AFF, 0x153A7D]
        case .emeraldGlass: hex = [0x0C392B, 0x10704F, 0x062018]
        case .roseGoldMetallic: hex = [0xFF6B4A, 0xD84275, 0x6B3BA7]
        case .titaniumFrost: hex = [0xE4E4E7, 0xD1D1D6, 0xA1A1AA]
        case .cyberHologram: hex = [0x3B0764, 0x0284C7, 0xEC4899]
        }
        return hex.map { Color(red: Double(($0 >> 16) & 255) / 255, green: Double(($0 >> 8) & 255) / 255, blue: Double($0 & 255) / 255) }
    }
}
extension AccountAccentTint {
    var labelKey: L10nKey {
        switch self { case .blue: return .tintBlue; case .green: return .tintGreen; case .orange: return .tintOrange; case .purple: return .tintPurple; case .pink: return .tintPink; case .gray: return .tintGray }
    }
    var color: Color {
        switch self { case .blue: return .blue; case .green: return .green; case .orange: return .orange; case .purple: return .purple; case .pink: return .pink; case .gray: return .gray }
    }
}
extension AccountBadgeIcon {
    var labelKey: L10nKey {
        switch self { case .bank: return .badgeBank; case .card: return .badgeCard; case .wallet: return .badgeWallet; case .lock: return .badgeLock; case .chart: return .badgeChart }
    }
    var symbol: String {
        switch self { case .bank: return "building.columns.fill"; case .card: return "creditcard.fill"; case .wallet: return "wallet.pass.fill"; case .lock: return "lock.fill"; case .chart: return "chart.line.uptrend.xyaxis" }
    }
}
extension PaymentNetwork {
    var title: String {
        switch self { case .mastercard: return "Mastercard"; case .visa: return "Visa"; case .kaspiPay: return "Kaspi Pay"; case .unionPay: return "UnionPay"; case .virtual: return "Virtual" }
    }
}
struct AccountVirtualCardView: View {
    let accountName: String
    let institutionName: String?
    let type: AccountType
    let currency: Currency
    let balance: String
    let appearance: AccountAppearance
    var country: Country? = nil
    var baseCurrencyEquivalent: String? = nil
    @EnvironmentObject private var preferences: AppPreferences

    private var ink: Color { appearance.themePreset == .titaniumFrost ? .black : .white }
    private var subtitle: String {
        var parts = [preferences.string(type.labelKey)]
        if let country { parts.append(country.rawValue + " " + country.flag) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: appearance.badgeIcon.symbol)
                    .padding(7).background(appearance.accentTint.color, in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 4) {
                    Text(institutionName ?? accountName).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium)).textCase(.uppercase).opacity(0.65)
                }
                Spacer(minLength: 0)
            }
            HStack {
                if type == .debitCard {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: chipColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        HStack(spacing: 0) {
                            Rectangle().stroke(.black.opacity(0.25)).frame(width: 11)
                            RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.3)).padding(.vertical, 5)
                            Rectangle().stroke(.black.opacity(0.25)).frame(width: 11)
                        }
                    }.frame(width: 44, height: 32).clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.4)) }
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(preferences.string(.currentBalanceLabel).uppercased()).font(.system(size: 9, weight: .semibold)).opacity(0.6)
                    Text(balance + " " + currency.rawValue).font(.system(size: 23, weight: .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.55)
                    if let baseCurrencyEquivalent {
                        Text(baseCurrencyEquivalent).font(.system(size: 11, weight: .medium)).monospacedDigit().opacity(0.75)
                    }
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(accountName).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                }
                Spacer(minLength: 0)
                if type == .debitCard, let network = appearance.paymentNetwork {
                    if network == .mastercard {
                        HStack(spacing: -9) { Circle().fill(.red); Circle().fill(.orange.opacity(0.9)) }.frame(width: 40, height: 25)
                    } else { Text(network.title).font(.system(size: 13, weight: .heavy)).italic() }
                }
            }
        }
        .foregroundStyle(ink).padding(20)
        .frame(maxWidth: .infinity, minHeight: 225)
        .background(LinearGradient(colors: appearance.themePreset.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(appearance.accentTint.color.opacity(0.6)) }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
    }

    private let chipColors = [Color(red: 0.95, green: 0.82, blue: 0.45), Color(red: 0.7, green: 0.5, blue: 0.18), Color(red: 1, green: 0.9, blue: 0.6)]
}
