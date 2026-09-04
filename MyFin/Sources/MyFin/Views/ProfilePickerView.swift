import SwiftUI

struct ProfilePickerView: View {
    @ObservedObject var session: AppSession
    @EnvironmentObject var preferences: AppPreferences
    @State private var showingCreateProfile = false
    @State private var loginTarget: Profile?

    var body: some View {
        VStack(spacing: 16) {
            Text("MyFin").font(.largeTitle.bold())
            PreferencesControls()

            if session.profiles.isEmpty {
                Text(preferences.string(.noProfilesYet))
                    .foregroundStyle(.secondary)
            } else {
                List(session.profiles) { profile in
                    HStack {
                        Image(systemName: profile.iconName)
                            .foregroundStyle(ProfileIconPalette.color(named: profile.iconColor))
                        Text(profile.displayName)
                        Spacer()
                        Button(preferences.string(.loginButton)) { attemptLogin(profile) }
                    }
                }
                .frame(minHeight: 120)
            }

            Button(preferences.string(.createProfileButton)) { showingCreateProfile = true }
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 320)
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView(session: session)
        }
        .sheet(item: $loginTarget) { profile in
            LoginView(session: session, profile: profile)
        }
        .onAppear { session.refreshProfiles() }
    }

    private func attemptLogin(_ profile: Profile) {
        Task {
            if await session.logInWithRememberedPassword(profile: profile) {
                return
            }
            loginTarget = profile
        }
    }
}
