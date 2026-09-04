import SwiftUI

/// Asks the currently logged-in user to re-enter their password before
/// permanently deleting their own profile. Deletion is only ever offered from
/// inside a logged-in profile's Settings — never from the pre-login picker —
/// so this always acts on `session.unlockedProfile`.
struct DeleteProfileView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(deleteConfirmationTitle).font(.title2.bold())
            Text(preferences.string(.deleteProfileConfirmMessage))
                .font(.caption)
                .foregroundStyle(.secondary)

            RevealableSecureField(title: preferences.string(.passwordField), text: $password)
                .onSubmit { submit() }

            if let message = session.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            HStack {
                Button(preferences.string(.cancelButton)) { dismiss() }
                Spacer()
                Button(preferences.string(.deleteButton), role: .destructive) { submit() }
                    .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 340)
        .onAppear { session.errorMessage = nil }
    }

    private var deleteConfirmationTitle: String {
        String(format: preferences.string(.deleteProfileConfirmTitleFormat), session.unlockedProfile?.displayName ?? "")
    }

    private func submit() {
        session.deleteCurrentProfile(confirmingWithPassword: password)
        if session.screen == .profilePicker {
            dismiss()
        }
    }
}
