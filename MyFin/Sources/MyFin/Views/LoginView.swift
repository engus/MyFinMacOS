import SwiftUI

struct LoginView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    let profile: Profile
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: preferences.string(.loginTitleFormat), profile.displayName)).font(.title2.bold())
            RevealableSecureField(title: preferences.string(.passwordField), text: $password)
                .onSubmit { submit() }

            if let message = session.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            HStack {
                Button(preferences.string(.cancelButton)) { dismiss() }
                Spacer()
                Button(preferences.string(.loginButton)) { submit() }
                    .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
        .onAppear { session.errorMessage = nil }
    }

    private func submit() {
        session.logIn(profile: profile, password: password)
        if session.unlockedProfile?.id == profile.id {
            dismiss()
        }
    }
}
