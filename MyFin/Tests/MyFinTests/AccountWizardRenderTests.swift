import XCTest
import SwiftUI
import AppKit
@testable import MyFin

@MainActor
final class AccountWizardRenderTests: XCTestCase {
    func test_renderWizardAndInspectorFixtures() throws {
        guard let directory = ProcessInfo.processInfo.environment["MYFIN_RENDER_DIRECTORY"] else {
            throw XCTSkip("Set MYFIN_RENDER_DIRECTORY for visual fixture rendering")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = AppSession(profileStore: ProfileStore(baseDirectory: root))
        session.createProfile(displayName: "Preview", password: "preview", remember: false)
        let preferences = AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        preferences.language = .en
        var draft = AccountCreationDraft()
        draft.institutionSelection = .existing(id: "kz.kaspi-bank")
        draft.name = "Kaspi Gold"
        draft.balance = "142500"
        draft.appearance.tags = ["Daily-Spend", "Salary"]
        for step in CreationStep.allCases {
            draft.step = step
            for scheme in [ColorScheme.light, .dark] {
                let view = NewAccountWizardView(session: session, draft: draft).environmentObject(preferences).environment(\.colorScheme, scheme)
                try render(view, width: 940, height: 720, path: directory + "/wizard-\(step.rawValue)-\(scheme).png")
            }
        }
        draft.step = .appearance
        draft.type = .cash
        try render(NewAccountWizardView(session: session, draft: draft).environmentObject(preferences), width: 940, height: 720, path: directory + "/wizard-cash.png")
        let card = AccountVirtualCardView(accountName: draft.name, institutionName: "Kaspi Bank", type: .debitCard,
            currency: .kzt, balance: "142,500.00", appearance: draft.appearance).environmentObject(preferences)
        try render(card.padding(16), width: 330, height: 310, path: directory + "/inspector-card.png")
        preferences.language = .ru
        draft.type = .debitCard
        for step in CreationStep.allCases {
            draft.step = step
            try render(NewAccountWizardView(session: session, draft: draft).environmentObject(preferences).environment(\.colorScheme, .light),
                       width: 940, height: 720, path: directory + "/wizard-\(step.rawValue)-ru.png")
        }
    }

    private func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, path: String) throws {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        host.layoutSubtreeIfNeeded()
        let image = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: path))
    }
}
