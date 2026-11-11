import SwiftUI

/// What can be done to a stamp from the grid, a page or the list. The same three actions feed the context menu, the
/// swipe actions and VoiceOver's custom actions.
struct PassportStampActions {
    let open: (PassportEntry) -> Void
    let toggleFavorite: (PassportEntry) -> Void
    let share: (PassportEntry) -> Void
    let remove: (PassportEntry) -> Void
}

struct PassportStampButton<Content: View>: View {
    let entry: PassportEntry
    let actions: PassportStampActions
    var transitionID: String?
    @ViewBuilder var label: () -> Content

    private var favoriteName: Text { entry.isFavorite ? Text("Unfavorite") : Text("Favorite") }

    private var menu: some View {
        Button { actions.open(entry) } label: { label() }
            .buttonStyle(.plain)
            .contextMenu {
                Button { actions.toggleFavorite(entry) } label: {
                    entry.isFavorite ? Label("Unfavorite", systemImage: "heart.slash") : Label("Favorite", systemImage: "heart")
                }
                if entry.design != nil { Button { actions.share(entry) } label: { Label("Share stamp", systemImage: "square.and.arrow.up") } }
                Button(role: .destructive) { actions.remove(entry) } label: { Label("Remove from passport", systemImage: "trash") }
            }
    }

    var body: some View {
        let entry = entry, actions = actions
        return menu
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(entry.spokenLabel()))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("passport-stamp-\(entry.destinationID)")
            .accessibilityAction(named: favoriteName) { actions.toggleFavorite(entry) }
            .accessibilityAction(named: Text("Share stamp")) { if entry.design != nil { actions.share(entry) } }
            .accessibilityAction(named: Text("Remove from passport")) { actions.remove(entry) }
    }
}
