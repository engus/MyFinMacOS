import Foundation

enum SystemInstitutionCatalog {
    struct Entry {
        let id: String
        let country: Country
        let name: String
        let aliases: [String]
        let color: String
    }

    static let institutionIconName = "building.columns.fill"

    static func color(forID id: String) -> String? {
        all.first { $0.id == id }?.color
    }

    static let all: [Entry] = [
        // KZ — Kazakhstan
        Entry(id: "kz.halyk-bank", country: .kz, name: "Halyk Bank", aliases: ["Halyk", "Народный банк"], color: "blue"),
        Entry(id: "kz.kaspi-bank", country: .kz, name: "Kaspi Bank", aliases: ["Kaspi", "Kaspi.kz"], color: "green"),
        Entry(id: "kz.bank-centercredit", country: .kz, name: "Bank CenterCredit", aliases: ["BCC", "ЦентрКредит"], color: "orange"),
        Entry(id: "kz.fortebank", country: .kz, name: "ForteBank", aliases: ["Forte"], color: "pink"),
        Entry(id: "kz.freedom-bank-kazakhstan", country: .kz, name: "Freedom Bank Kazakhstan", aliases: ["Freedom", "Фридом"], color: "purple"),
        Entry(id: "kz.eurasian-bank", country: .kz, name: "Eurasian Bank", aliases: ["Евразийский банк"], color: "red"),
        Entry(id: "kz.otbasy-bank", country: .kz, name: "Otbasy Bank", aliases: ["Отбасы", "ЖССБ"], color: "teal"),
        Entry(id: "kz.alatau-city-bank", country: .kz, name: "Alatau City Bank", aliases: ["Alatau", "Jusan", "Жусан"], color: "yellow"),
        Entry(id: "kz.bereke-bank", country: .kz, name: "Bereke Bank", aliases: ["Bereke", "Береке"], color: "blue"),
        Entry(id: "kz.home-credit-bank-kazakhstan", country: .kz, name: "Home Credit Bank Kazakhstan", aliases: ["Home Credit", "Хоум Кредит"], color: "green"),
        Entry(id: "kz.nurbank", country: .kz, name: "Nurbank", aliases: ["Нурбанк"], color: "orange"),
        Entry(id: "kz.bank-rbk", country: .kz, name: "Bank RBK", aliases: ["RBK"], color: "pink"),
        Entry(id: "kz.altyn-bank", country: .kz, name: "Altyn Bank", aliases: ["Алтын"], color: "purple"),
        Entry(id: "kz.kzi-bank", country: .kz, name: "KZI Bank", aliases: ["Kazakhstan-Ziraat", "KZI"], color: "red"),
        Entry(id: "kz.zaman-bank", country: .kz, name: "Zaman-Bank", aliases: ["Zaman"], color: "teal"),

        // AE — United Arab Emirates
        Entry(id: "ae.emirates-nbd", country: .ae, name: "Emirates NBD", aliases: ["ENBD"], color: "yellow"),
        Entry(id: "ae.first-abu-dhabi-bank", country: .ae, name: "First Abu Dhabi Bank", aliases: ["FAB"], color: "blue"),
        Entry(id: "ae.abu-dhabi-commercial-bank", country: .ae, name: "Abu Dhabi Commercial Bank", aliases: ["ADCB"], color: "green"),
        Entry(id: "ae.dubai-islamic-bank", country: .ae, name: "Dubai Islamic Bank", aliases: ["DIB"], color: "orange"),
        Entry(id: "ae.mashreq", country: .ae, name: "Mashreq", aliases: ["Mashreq Bank"], color: "pink"),
        Entry(id: "ae.abu-dhabi-islamic-bank", country: .ae, name: "Abu Dhabi Islamic Bank", aliases: ["ADIB"], color: "purple"),
        Entry(id: "ae.emirates-islamic", country: .ae, name: "Emirates Islamic", aliases: ["EI"], color: "red"),
        Entry(id: "ae.rakbank", country: .ae, name: "RAKBANK", aliases: ["National Bank of Ras Al-Khaimah"], color: "teal"),
        Entry(id: "ae.commercial-bank-of-dubai", country: .ae, name: "Commercial Bank of Dubai", aliases: ["CBD"], color: "yellow"),
        Entry(id: "ae.national-bank-of-fujairah", country: .ae, name: "National Bank of Fujairah", aliases: ["NBF"], color: "blue"),
        Entry(id: "ae.wio-bank", country: .ae, name: "Wio Bank", aliases: ["Wio"], color: "green"),
        Entry(id: "ae.al-hilal-bank", country: .ae, name: "Al Hilal Bank", aliases: ["Al Hilal"], color: "orange"),
        Entry(id: "ae.sharjah-islamic-bank", country: .ae, name: "Sharjah Islamic Bank", aliases: ["SIB"], color: "pink"),
        Entry(id: "ae.ajman-bank", country: .ae, name: "Ajman Bank", aliases: ["Ajman"], color: "purple"),
        Entry(id: "ae.hsbc-uae", country: .ae, name: "HSBC UAE", aliases: ["HSBC"], color: "red"),
        Entry(id: "ae.standard-chartered-uae", country: .ae, name: "Standard Chartered UAE", aliases: ["Standard Chartered"], color: "teal"),
        Entry(id: "ae.citibank-uae", country: .ae, name: "Citibank UAE", aliases: ["Citi UAE", "Citi"], color: "yellow"),

        // RU — Russia
        Entry(id: "ru.sberbank", country: .ru, name: "Sberbank", aliases: ["Сбер", "Сбербанк"], color: "blue"),
        Entry(id: "ru.vtb", country: .ru, name: "VTB", aliases: ["ВТБ"], color: "green"),
        Entry(id: "ru.alfa-bank", country: .ru, name: "Alfa-Bank", aliases: ["Альфа-Банк", "Альфа"], color: "orange"),
        Entry(id: "ru.t-bank", country: .ru, name: "T-Bank", aliases: ["Т-Банк", "Tinkoff", "Тинькофф"], color: "pink"),
        Entry(id: "ru.gazprombank", country: .ru, name: "Gazprombank", aliases: ["Газпромбанк", "ГПБ"], color: "purple"),
        Entry(id: "ru.sovcombank", country: .ru, name: "Sovcombank", aliases: ["Совкомбанк"], color: "red"),
        Entry(id: "ru.russian-agricultural-bank", country: .ru, name: "Russian Agricultural Bank", aliases: ["Россельхозбанк", "РСХБ"], color: "teal"),
        Entry(id: "ru.psb", country: .ru, name: "PSB", aliases: ["ПСБ", "Промсвязьбанк"], color: "yellow"),
        Entry(id: "ru.moscow-credit-bank", country: .ru, name: "Moscow Credit Bank", aliases: ["МКБ", "Московский кредитный банк"], color: "blue"),
        Entry(id: "ru.dom-rf", country: .ru, name: "DOM.RF", aliases: ["ДОМ.РФ"], color: "green"),
        Entry(id: "ru.raiffeisenbank", country: .ru, name: "Raiffeisenbank", aliases: ["Райффайзен", "Райффайзенбанк"], color: "orange"),
        Entry(id: "ru.unicredit-bank", country: .ru, name: "UniCredit Bank", aliases: ["ЮниКредит"], color: "pink"),
        Entry(id: "ru.bank-saint-petersburg", country: .ru, name: "Bank Saint Petersburg", aliases: ["Банк Санкт-Петербург", "БСПБ"], color: "purple"),
        Entry(id: "ru.ak-bars-bank", country: .ru, name: "Ak Bars Bank", aliases: ["Ак Барс"], color: "red"),
        Entry(id: "ru.russian-standard", country: .ru, name: "Russian Standard", aliases: ["Русский Стандарт"], color: "teal"),
        Entry(id: "ru.mts-bank", country: .ru, name: "MTS Bank", aliases: ["МТС Банк"], color: "yellow"),
        Entry(id: "ru.ozon-bank", country: .ru, name: "Ozon Bank", aliases: ["Ozon", "Озон Банк"], color: "blue"),
        Entry(id: "ru.yandex-bank", country: .ru, name: "Yandex Bank", aliases: ["Яндекс Банк", "Yandex"], color: "green"),
        Entry(id: "ru.post-bank", country: .ru, name: "Post Bank", aliases: ["Почта Банк"], color: "orange"),

        // US — United States
        Entry(id: "us.chase", country: .us, name: "Chase", aliases: ["JPMorgan Chase"], color: "pink"),
        Entry(id: "us.bank-of-america", country: .us, name: "Bank of America", aliases: ["BofA", "BOA"], color: "purple"),
        Entry(id: "us.citibank", country: .us, name: "Citibank", aliases: ["Citi"], color: "red"),
        Entry(id: "us.wells-fargo", country: .us, name: "Wells Fargo", aliases: ["Wells"], color: "teal"),
        Entry(id: "us.u-s-bank", country: .us, name: "U.S. Bank", aliases: ["US Bank", "USB"], color: "yellow"),
        Entry(id: "us.capital-one", country: .us, name: "Capital One", aliases: ["CapitalOne"], color: "blue"),
        Entry(id: "us.pnc", country: .us, name: "PNC", aliases: ["PNC Bank"], color: "green"),
        Entry(id: "us.truist", country: .us, name: "Truist", aliases: ["Truist Bank"], color: "orange"),
        Entry(id: "us.td-bank", country: .us, name: "TD Bank", aliases: ["TD"], color: "pink"),
        Entry(id: "us.bmo", country: .us, name: "BMO", aliases: ["BMO Bank"], color: "purple"),
        Entry(id: "us.fifth-third-bank", country: .us, name: "Fifth Third Bank", aliases: ["5/3", "Fifth Third"], color: "red"),
        Entry(id: "us.huntington", country: .us, name: "Huntington", aliases: ["Huntington Bank"], color: "teal"),
        Entry(id: "us.keybank", country: .us, name: "KeyBank", aliases: ["Key Bank"], color: "yellow"),
        Entry(id: "us.regions-bank", country: .us, name: "Regions Bank", aliases: ["Regions"], color: "blue"),
        Entry(id: "us.citizens", country: .us, name: "Citizens", aliases: ["Citizens Bank"], color: "green"),
        Entry(id: "us.santander-bank", country: .us, name: "Santander Bank", aliases: ["Santander"], color: "orange"),
        Entry(id: "us.ally-bank", country: .us, name: "Ally Bank", aliases: ["Ally"], color: "pink"),
        Entry(id: "us.synchrony-bank", country: .us, name: "Synchrony Bank", aliases: ["Synchrony"], color: "purple"),
        Entry(id: "us.charles-schwab-bank", country: .us, name: "Charles Schwab Bank", aliases: ["Schwab"], color: "red"),
        Entry(id: "us.sofi", country: .us, name: "SoFi", aliases: ["SoFi Bank"], color: "teal"),
        Entry(id: "us.usaa", country: .us, name: "USAA", aliases: ["USAA Federal Savings Bank"], color: "yellow"),
        Entry(id: "us.navy-federal-credit-union", country: .us, name: "Navy Federal Credit Union", aliases: ["Navy Federal"], color: "blue"),
        Entry(id: "us.penfed-credit-union", country: .us, name: "PenFed Credit Union", aliases: ["PenFed"], color: "green"),
        Entry(id: "us.alliant-credit-union", country: .us, name: "Alliant Credit Union", aliases: ["Alliant"], color: "orange"),
        Entry(id: "us.chime", country: .us, name: "Chime", aliases: ["Chime Financial"], color: "pink"),
        Entry(id: "us.varo-bank", country: .us, name: "Varo Bank", aliases: ["Varo"], color: "purple"),
        Entry(id: "us.axos-bank", country: .us, name: "Axos Bank", aliases: ["Axos"], color: "red")
    ]
}
