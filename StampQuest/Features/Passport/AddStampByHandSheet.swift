import SwiftUI

/// Pick a place from the catalogue and save its stamp as a hand-collected one. Works offline and with location denied; it
/// never marks a stamp verified. The save itself is the app's existing collect action, run once the sheet has closed.
struct AddStampByHandSheet: View {
    let onPick: (String) -> Void

    @Environment(\.passport) private var passport
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var results: [Destination] {
        passport.catalog.search(search).filter { !passport.snapshot.state(of: $0.id).isInPassport }
    }

    var body: some View {
        NavigationStack {
            List {
                Section { Text("Free to collect. Works offline. No location needed.").font(.footnote).foregroundStyle(HomeColor.sub).listRowBackground(Color.clear) }
                ForEach(results) { destination in
                    if let item = passport.item(destination) {
                        Button { onPick(destination.id); dismiss() } label: { DestinationRow(item: item, detail: destination.locationLine) }
                            .buttonStyle(.plain).accessibilityIdentifier("passport-add-\(destination.id)")
                    }
                }
                if results.isEmpty {
                    Text(search.isEmpty ? "Every place is already in your passport." : "No places match.").foregroundStyle(HomeColor.sub).listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden).background(HomeColor.page)
            .searchable(text: $search, prompt: Text("Search places"))
            .navigationTitle("Add a stamp by hand").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}
