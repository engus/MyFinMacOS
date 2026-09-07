import XCTest
import SwiftUI
import AppKit
@testable import MyFin

@MainActor
final class CashflowRenderTests: XCTestCase {
    func test_renderCashflowAndEntry() throws {
        guard let directory = ProcessInfo.processInfo.environment["MYFIN_RENDER_DIRECTORY"] else {
            throw XCTSkip("Set MYFIN_RENDER_DIRECTORY for visual fixtures")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = AppSession(profileStore: ProfileStore(baseDirectory: root))
        session.createProfile(displayName: "Cashflow Preview", password: "preview", remember: false)
        let db = try XCTUnwrap(session.connection)
        try CashflowService(db: db).addDemoData()
        let preferences = AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        preferences.language = .ru
        for scheme in [ColorScheme.light, .dark] {
            try render(CashflowView(session: session, month: .constant(FlowDate.month(Date())))
                .environmentObject(preferences).environment(\.colorScheme, scheme).preferredColorScheme(scheme), width: 1120, height: 800,
                path: directory + "/cashflow-\(scheme).png")
        }
        try render(CashflowEntryView(session: session).environmentObject(preferences).environment(\.colorScheme, .light).preferredColorScheme(.light), width: 640, height: 600,
            path: directory + "/cashflow-entry.png")
    }
    private func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, path: String) throws {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        let image = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: image)
        let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: path))
        window.contentView = nil
    }
}
