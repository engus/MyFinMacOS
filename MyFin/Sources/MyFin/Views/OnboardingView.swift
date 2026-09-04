import SwiftUI

struct OnboardingView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 16) {
            Text("Онбординг")
                .font(.largeTitle.bold())
            Button("OK") {
                session.completeOnboarding()
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 420, minHeight: 320)
    }
}
