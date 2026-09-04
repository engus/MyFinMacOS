import SwiftUI

/// A password field with a toggle button to reveal/hide the plaintext value.
struct RevealableSecureField: View {
    let title: String
    @Binding var text: String
    @EnvironmentObject var preferences: AppPreferences
    @State private var isRevealed = false

    var body: some View {
        HStack {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? preferences.string(.hidePasswordLabel) : preferences.string(.showPasswordLabel))
        }
    }
}
