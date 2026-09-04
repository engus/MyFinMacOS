import SwiftUI

struct CreateProfileView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var rememberPassword = false
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(preferences.string(.createProfileTitle)).font(.title2.bold())

            TextField(preferences.string(.profileNameField), text: $displayName)
            RevealableSecureField(title: preferences.string(.passwordField), text: $password)
            RevealableSecureField(title: preferences.string(.confirmPasswordField), text: $confirmPassword)
            Toggle(preferences.string(.rememberPasswordToggle), isOn: $rememberPassword)

            Text(preferences.string(.passwordRecoveryWarning))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let localError {
                Text(localError).foregroundStyle(.red)
            } else if let message = session.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            HStack {
                Button(preferences.string(.cancelButton)) { dismiss() }
                Spacer()
                Button(preferences.string(.createButton)) { submit() }
                    .disabled(displayName.isEmpty || password.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
        .onAppear { session.errorMessage = nil }
    }

    private func submit() {
        guard password == confirmPassword else {
            localError = preferences.string(.passwordsDoNotMatch)
            return
        }
        session.createProfile(displayName: displayName, password: password, remember: rememberPassword)
        if session.errorMessage == nil {
            dismiss()
        }
    }
}
