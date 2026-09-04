import AppKit
import SwiftUI

/// Tracks whether the OS is currently in Dark Mode, live, via KVO on
/// `NSApp.effectiveAppearance`.
///
/// This exists so `MyFinApp` never has to pass `nil` to `.preferredColorScheme`
/// for "System" mode. Passing `nil` and later switching back to it triggers a
/// real SwiftUI/AppKit bug on macOS: `List`/`Form` (backed by NSTableView)
/// can end up with both stale rendering AND broken hit-testing (clicks not
/// reaching most controls) after such a transition. Instead, "System" mode
/// resolves to an explicit `.light`/`.dark` value here, kept in sync with the
/// OS, so `.preferredColorScheme` is always given a concrete value and that
/// buggy transition is never triggered in the first place.
@MainActor
final class SystemAppearanceObserver: NSObject, ObservableObject {
    @Published private(set) var isDark: Bool

    private var observation: NSKeyValueObservation?

    override init() {
        isDark = Self.resolveIsDark(NSApp.effectiveAppearance)
        super.init()
        observation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, change in
            guard let appearance = change.newValue else { return }
            let isDark = Self.resolveIsDark(appearance)
            DispatchQueue.main.async {
                self?.isDark = isDark
            }
        }
    }

    private static func resolveIsDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
