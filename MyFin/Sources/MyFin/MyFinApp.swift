import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct MyFinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = AppSession()
    @StateObject private var preferences = AppPreferences()
    @StateObject private var systemAppearance = SystemAppearanceObserver()

    /// Always an explicit `.light`/`.dark` value, never `nil` — see
    /// `SystemAppearanceObserver` for why "System" mode is resolved here
    /// instead of being passed through as `nil`.
    private var resolvedColorScheme: ColorScheme {
        switch preferences.theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return systemAppearance.isDark ? .dark : .light
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.screen {
                case .profilePicker:
                    ProfilePickerView(session: session)
                case .onboarding:
                    OnboardingView(session: session)
                case .mainShell:
                    MainShellView(session: session)
                }
            }
            .frame(minWidth: 700, minHeight: 480)
            .environmentObject(preferences)
            .preferredColorScheme(resolvedColorScheme)
        }
        .defaultSize(width: 1280, height: 820)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}
