import SwiftUI
import SwiftData

struct TripsView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: [SortDescriptor(\Trip.startDate, order: .reverse), SortDescriptor(\Trip.createdAt, order: .reverse)]) private var trips: [Trip]
    @State private var showEditor = false

    var body: some View {
        ScrollView {
            if trips.isEmpty {
                EmptyStateView(title: "No trips yet", message: "Group stamps and memories into a trip to see them together on a timeline.",
                               systemImage: "suitcase", actionTitle: "Create a trip") { showEditor = true }
                    .padding(.top, SQSpace.xl)
                    .accessibilityIdentifier("trips-empty")
            } else {
                LazyVStack(spacing: SQSpace.sm) {
                    ForEach(trips) { trip in
                        Button { env.router.push(.trip(trip.id)) } label: { TripCard(trip: trip) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("trip-\(trip.title)")
                    }
                }
                .padding(.horizontal, SQSpace.screenMargin)
                .padding(.bottom, SQSpace.xxl)
            }
        }
        .sqScreenBackground()
        .navigationTitle("Trips")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New trip")
                    .accessibilityIdentifier("new-trip")
            }
        }
        .sheet(isPresented: $showEditor) { TripEditorSheet() }
    }
}

extension Trip {
    var dateRangeText: String? {
        switch (startDate, endDate) {
        case let (s?, e?):
            let calendar = Calendar.current
            if calendar.isDate(s, inSameDayAs: e) { return s.formatted(date: .abbreviated, time: .omitted) }
            return "\(s.formatted(date: .abbreviated, time: .omitted)) – \(e.formatted(date: .abbreviated, time: .omitted))"
        case let (s?, nil): return String(localized: "From \(s.formatted(date: .abbreviated, time: .omitted))")
        case let (nil, e?): return String(localized: "Until \(e.formatted(date: .abbreviated, time: .omitted))")
        default: return nil
        }
    }
}

struct TripCard: View {
    let trip: Trip
    @Environment(\.passport) private var passport

    var body: some View {
        let stamps = passport.snapshot.stamps.filter { $0.tripID == trip.id }
        let items = stamps.prefix(3).compactMap { passport.item(id: $0.destinationID) }
        HStack(spacing: SQSpace.md) {
            ZStack {
                if items.isEmpty {
                    Image(systemName: "suitcase").font(.system(size: 26, weight: .light)).foregroundStyle(SQColor.accent)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        PerforatedStampView(design: item.design, showsTitle: false, isDecorative: true)
                            .frame(width: 48)
                            .rotationEffect(.degrees(Double(index - 1) * 8))
                            .offset(x: CGFloat(index - 1) * 14)
                    }
                }
            }
            .frame(width: 84, height: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.title).font(SQFont.headline).foregroundStyle(SQColor.textPrimary).lineLimit(2)
                if let range = trip.dateRangeText { Text(range).font(SQFont.caption).foregroundStyle(SQColor.textSecondary) }
                Text(stamps.count == 1 ? "1 stamp" : "\(stamps.count) stamps").font(SQFont.caption).foregroundStyle(SQColor.textTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(SQColor.textTertiary)
        }
        .padding(SQSpace.md)
        .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SQRadius.large, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(trip.title), \(trip.dateRangeText ?? "no dates"), \(stamps.count) stamps")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Detail

struct TripDetailView: View {
    let tripID: UUID
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Query private var found: [Trip]
    @Query private var memories: [MemoryEntry]
    @State private var showEditor = false
    @State private var showAddStamps = false
    @State private var showMemoryEditor = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    init(tripID: UUID) {
        self.tripID = tripID
        _found = Query(filter: #Predicate<Trip> { $0.id == tripID })
        _memories = Query(filter: #Predicate<MemoryEntry> { $0.tripID == tripID }, sort: [SortDescriptor(\MemoryEntry.eventDate)])
    }

    var body: some View {
        if let trip = found.first {
            content(trip)
        } else {
            EmptyStateView(title: "Trip not found", message: "It may have been deleted.", systemImage: "suitcase").sqScreenBackground()
        }
    }

    private func content(_ trip: Trip) -> some View {
        let stamps = passport.snapshot.stamps.filter { $0.tripID == trip.id }
        return ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.lg) {
                VStack(alignment: .leading, spacing: SQSpace.xs) {
                    if let range = trip.dateRangeText { Text(range).sqEyebrow() }
                    Text(trip.title).font(SQFont.display).foregroundStyle(SQColor.textPrimary).accessibilityAddTraits(.isHeader)
                    if !trip.notes.isEmpty { Text(trip.notes).font(SQFont.story).foregroundStyle(SQColor.textSecondary) }
                }
                if !trip.destinationIDs.isEmpty { places(trip) }
                timeline(stamps)
                HStack(spacing: SQSpace.sm) {
                    SecondaryActionButton(title: "Add stamps", systemImage: "checkmark.seal") { showAddStamps = true }
                        .accessibilityIdentifier("trip-add-stamps")
                    SecondaryActionButton(title: "Add memory", systemImage: "heart.text.square") { showMemoryEditor = true }
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete trip", systemImage: "trash").font(SQFont.headline).frame(maxWidth: .infinity, minHeight: 52)
                }
                .foregroundStyle(SQColor.error)
                .accessibilityIdentifier("delete-trip")
            }
            .padding(.horizontal, SQSpace.screenMargin)
            .padding(.bottom, SQSpace.xxl)
        }
        .sqScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "pencil") }
                    .accessibilityLabel("Edit trip").accessibilityIdentifier("edit-trip")
            }
        }
        .sheet(isPresented: $showEditor) { TripEditorSheet(trip: trip) }
        .sheet(isPresented: $showAddStamps) { AddStampsToTripSheet(tripID: trip.id) }
        .sheet(isPresented: $showMemoryEditor) { MemoryEditorSheet(prefilledTripID: trip.id) }
        .confirmationDialog("Delete “\(trip.title)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) { delete(trip) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Only the trip is deleted. Its stamps and memories stay where they are.") }
        .alert("Couldn’t delete", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func places(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.sm) {
            Text("Places").font(SQFont.section).accessibilityAddTraits(.isHeader)
            FlowLayout {
                ForEach(trip.destinationIDs, id: \.self) { id in
                    if let item = passport.item(id: id) {
                        Button { env.router.push(.destination(id)) } label: {
                            CategoryChip(title: item.destination.name, systemImage: item.state.isInPassport ? "checkmark.seal.fill" : "mappin.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private struct TimelineEntry: Identifiable {
        let id: String
        let date: Date
        let symbol: String
        let title: String
        let detail: String
        let route: Route
    }

    private func timeline(_ stamps: [CollectedStamp]) -> some View {
        var entries: [TimelineEntry] = stamps.map {
            TimelineEntry(id: "s-\($0.stampID)", date: $0.collectedAt, symbol: $0.isVerified ? "location.circle.fill" : "checkmark.seal.fill",
                          title: $0.title, detail: String(localized: "Stamp"), route: .stamp($0.destinationID))
        }
        entries += memories.map {
            TimelineEntry(id: "m-\($0.id)", date: $0.eventDate, symbol: "heart.text.square.fill",
                          title: $0.title.isEmpty ? String(localized: "Memory") : $0.title, detail: String(localized: "Memory"), route: .memory($0.id))
        }
        entries.sort { $0.date < $1.date }
        return VStack(alignment: .leading, spacing: SQSpace.sm) {
            Text("Timeline").font(SQFont.section).accessibilityAddTraits(.isHeader)
            if entries.isEmpty {
                Text("Add stamps and memories to build this trip’s timeline.").font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
            } else {
                TripTimelineView(entries: entries.map { ($0.id, $0.date, $0.symbol, $0.title, $0.detail, $0.route) }) { env.router.push($0) }
            }
        }
    }

    private func delete(_ trip: Trip) {
        do {
            try env.store.deleteTrip(trip)
            if !env.router.path(for: env.router.selectedTab).isEmpty { env.router.popToRoot() }
        } catch { errorMessage = (error as? PassportError)?.errorDescription }
    }
}

struct TripTimelineView: View {
    let entries: [(id: String, date: Date, symbol: String, title: String, detail: String, route: Route)]
    let open: (Route) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack(alignment: .top, spacing: SQSpace.sm) {
                    VStack(spacing: 0) {
                        Image(systemName: entry.symbol).font(.system(size: 14, weight: .semibold)).frame(width: 30, height: 30)
                            .background(SQColor.accent.opacity(0.16), in: Circle()).foregroundStyle(SQColor.accentText).accessibilityHidden(true)
                        if index < entries.count - 1 { Rectangle().fill(SQColor.border).frame(width: 1.5).frame(maxHeight: .infinity) }
                    }
                    Button { open(entry.route) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).font(SQFont.subheadline.weight(.semibold)).foregroundStyle(SQColor.textPrimary)
                            Text("\(entry.detail) · \(entry.date.formatted(date: .abbreviated, time: .omitted))").font(SQFont.caption).foregroundStyle(SQColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, SQSpace.md)
                        .frame(minHeight: SQHit.minimum, alignment: .top)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Editor

struct TripEditorSheet: View {
    var trip: Trip?
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var hasStart = false
    @State private var hasEnd = false
    @State private var start = Calendar.current.startOfDay(for: .now)
    @State private var end = Calendar.current.startOfDay(for: .now)
    @State private var destinationIDs: [String] = []
    @State private var errorMessage: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip name", text: $title).accessibilityIdentifier("trip-title")
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...6)
                }
                Section("Dates") {
                    Toggle("Start date", isOn: $hasStart.animation())
                    if hasStart { DatePicker("Starts", selection: $start, displayedComponents: .date) }
                    Toggle("End date", isOn: $hasEnd.animation())
                    if hasEnd { DatePicker("Ends", selection: $end, in: (hasStart ? start : .distantPast)..., displayedComponents: .date) }
                }
                Section("Places") {
                    NavigationLink {
                        MultiDestinationPicker(selection: $destinationIDs)
                    } label: {
                        LabeledContent("Places on this trip", value: destinationIDs.isEmpty ? String(localized: "None") : "\(destinationIDs.count)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .sqScreenBackground()
            .navigationTitle(trip == nil ? "New trip" : "Edit trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityIdentifier("trip-save")
                }
            }
            .alert("Can’t save this trip", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded, let trip else { loaded = true; return }
        loaded = true
        title = trip.title
        notes = trip.notes
        destinationIDs = trip.destinationIDs
        if let s = trip.startDate { hasStart = true; start = s }
        if let e = trip.endDate { hasEnd = true; end = e }
    }

    private func save() {
        let draft = TripDraft(title: title, startDate: hasStart ? start : nil, endDate: hasEnd ? end : nil, notes: notes, destinationIDs: destinationIDs)
        do {
            try env.store.saveTrip(draft, replacing: trip)
            dismiss()
        } catch { errorMessage = (error as? PassportError)?.errorDescription ?? String(localized: "The trip couldn’t be saved.") }
    }
}

struct MultiDestinationPicker: View {
    @Binding var selection: [String]
    @Environment(AppEnvironment.self) private var env
    @State private var query = ""

    var body: some View {
        List(env.catalog.search(query)) { destination in
            Button {
                if let i = selection.firstIndex(of: destination.id) { selection.remove(at: i) } else { selection.append(destination.id) }
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(destination.name).font(SQFont.body).foregroundStyle(SQColor.textPrimary)
                        Text(destination.subtitle).font(SQFont.caption).foregroundStyle(SQColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: selection.contains(destination.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection.contains(destination.id) ? SQColor.accentText : SQColor.textTertiary)
                }
            }
            .accessibilityAddTraits(selection.contains(destination.id) ? .isSelected : [])
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search places")
    }
}

struct AddStampsToTripSheet: View {
    let tripID: UUID
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if passport.snapshot.stamps.isEmpty {
                    EmptyStateView(title: "No stamps yet", message: "Collect a stamp first, then add it to a trip.", systemImage: "checkmark.seal")
                } else {
                    List(passport.snapshot.stamps) { stamp in
                        let inTrip = stamp.tripID == tripID
                        Button { toggle(stamp, inTrip: inTrip) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(stamp.title).font(SQFont.body).foregroundStyle(SQColor.textPrimary)
                                    Text(CountryInfo.name(for: stamp.countryCode)).font(SQFont.caption).foregroundStyle(SQColor.textSecondary)
                                }
                                Spacer()
                                Image(systemName: inTrip ? "checkmark.circle.fill" : "circle").foregroundStyle(inTrip ? SQColor.accentText : SQColor.textTertiary)
                            }
                        }
                        .accessibilityAddTraits(inTrip ? .isSelected : [])
                    }
                }
            }
            .sqScreenBackground()
            .navigationTitle("Add stamps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Couldn’t update", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func toggle(_ stamp: CollectedStamp, inTrip: Bool) {
        do { try env.store.setTrip(destinationID: stamp.destinationID, tripID: inTrip ? nil : tripID) }
        catch { errorMessage = (error as? PassportError)?.errorDescription }
    }
}
