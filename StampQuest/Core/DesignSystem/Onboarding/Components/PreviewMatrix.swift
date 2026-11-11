import SwiftUI

/// Renders `content` in the four variants every onboarding view is previewed in:
/// light, dark, Dynamic Type AX3 and Reduce Motion.
struct PreviewMatrix<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                variant("Light") { content.environment(\.colorScheme, .light) }
                variant("Dark") { content.environment(\.colorScheme, .dark) }
                variant("AX3") { content.environment(\.dynamicTypeSize, .accessibility3) }
                variant("Reduce Motion") { content.environment(\.obReducesMotion, true) }
            }
            .padding()
        }
    }

    private func variant<V: View>(_ name: String, @ViewBuilder _ view: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.caption.bold()).foregroundStyle(.secondary)
            view()
        }
    }
}
