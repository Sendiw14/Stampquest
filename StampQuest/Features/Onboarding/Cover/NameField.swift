import SwiftUI

/// "Your name": an optional single-line field with an underline, 24 characters at most. Never blocked by the cover
/// choice or the Plus flag; it asks for nothing and prefills nothing.
struct NameField: View {
    let text: String
    let onChange: @MainActor @Sendable (String) -> Void
    var focus: FocusState<Bool>.Binding

    @ScaledMetric(relativeTo: .title3) private var size = 20.0
    @ScaledMetric(relativeTo: .footnote) private var helperSize = 12.5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("", text: Binding(get: { text }, set: onChange),
                      prompt: Text("onboarding.cover.name.placeholder").foregroundStyle(OnbColor.inkSecondary))
                .font(.system(size: size, weight: .medium))
                .tracking(-0.02 * size)
                .foregroundStyle(OnbColor.inkPrimary)
                .tint(OnbColor.accentText)
                .focused(focus)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { focus.wrappedValue = false }
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(focus.wrappedValue ? OnbColor.accentText : OnbColor.inkPrimary.opacity(0.5))
                        .frame(height: focus.wrappedValue ? 2 : 1)
                        .animation(.easeInOut(duration: 0.25), value: focus.wrappedValue)
                }
                .accessibilityLabel(Text("onboarding.cover.name.a11y"))
                .accessibilityHint(Text("onboarding.cover.name.helper"))
                .accessibilityIdentifier("onboarding.cover.name")
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("onboarding.common.done") { focus.wrappedValue = false }
                            .accessibilityIdentifier("onboarding.cover.keyboardDone")
                    }
                }
            Text("onboarding.cover.name.helper")
                .font(.system(size: helperSize))
                .lineSpacing(2)
                .foregroundStyle(OnbColor.inkSecondary)
                .padding(.top, 6)
                .accessibilityHidden(true)
        }
    }
}
