import Foundation
import LocalAuthentication

protocol BiometricAuthenticating {
    func authenticate(reason: String) async -> Bool
}

/// Prompts Touch ID / the Mac's login password via LocalAuthentication.
struct DeviceAuthenticator: BiometricAuthenticating {
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
