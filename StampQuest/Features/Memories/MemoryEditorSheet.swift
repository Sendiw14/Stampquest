import SwiftUI
import SwiftData
import PhotosUI

/// Create and Edit in one sheet. Photos are picked with the system PhotosPicker (no library permission), downsampled to at
/// most 2,048 px and copied into the app's own container. Save closes the sheet, shows a toast and plays the success haptic
/// only after the write has persisted. It can be opened prefilled with a place (Destination detail, Stamp detail) or a trip.
struct MemoryEditorSheet: View {
    var memory: MemoryEntry?
    var prefilledDestinationID: String?
    var prefilledTripID: UUID?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.dismiss) private var dismiss
    @Query private var allMemories: [MemoryEntry]
    @Query(sort: [SortDescriptor(\Trip.createdAt, order: .reverse)]) private var trips: [Trip]
    @State private var form = MemoryForm()
    @State private var initial = MemoryForm()
    @State private var loaded = false
    @State private var path: [Page] = []
    @State private var showDatePicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var importing = 0
    @State private var importedThisSession: [String] = []
    @State private var failedTiles: [UUID] = []
    @State private var saveError: String?
    @State private var showDiscard = false
    @FocusState private var focus: Field?

    private enum Page: Hashable { case place, trip, tags }
    private enum Field { case title, text }

    private var isEdit: Bool { memory != nil }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        titleField
                        textField
                        photosSection
                        rowsCard.padding(.top, 22)
                        privacyLine.padding(.top, 14)
                        if let saveError { errorBlock(saveError).padding(.top, 16) }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(HomeColor.page.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focus = nil }.accessibilityIdentifier("memory-keyboard-done") } }
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .place:
                    MemoryPlacePicker(selection: Binding(get: { form.destinationID }, set: { new in
                        if new != form.destinationID { form.stampLinked = true }
                        form.destinationID = new
                    }))
                case .trip: MemoryTripPicker(selection: $form.tripID, trips: trips)
                case .tags: MemoryTagEditor(tags: $form.tags, suggestions: MemoryDerived.tagCounts(allMemories.map(MemoryItem.init)).map(\.tag))
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .alert(isEdit ? "Discard your changes?" : "Discard this memory?", isPresented: $showDiscard) {
            Button("Discard", role: .destructive) { discard() }
            Button("Keep editing", role: .cancel) {}
        }
        .onChange(of: pickerItems) { _, items in importPhotos(items) }
        .onChange(of: form.title) { _, new in
            // Return in the title moves to the text field instead of adding a line.
            if new.contains("\n") { form.title = new.replacingOccurrences(of: "\n", with: ""); focus = .text }
        }
        .onAppear(perform: load)
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text(isEdit ? "Edit memory" : "New memory").font(.system(size: 17, weight: .bold)).foregroundStyle(HomeColor.ink).accessibilityAddTraits(.isHeader)
            HStack {
                Button { cancel() } label: {
                    Text("Cancel").font(.system(size: 16.5, weight: .medium)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain).accessibilityIdentifier("memory-cancel")
                Spacer()
                Button(action: save) {
                    Text("Save").font(.system(size: 16.5, weight: .bold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                }
                .buttonStyle(.plain).disabled(!canSave).opacity(canSave ? 1 : 0.55).animation(.easeInOut(duration: 0.3), value: canSave)
                .accessibilityIdentifier("memory-save")
            }
        }
        .padding(.horizontal, 20).padding(.top, 8).frame(minHeight: 56)
    }

    // MARK: Fields

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("", text: $form.title, prompt: Text("Title").foregroundStyle(HomeColor.sub), axis: .vertical)
                .lineLimit(1...3).memoryFont(26, .semibold, serif: true, relativeTo: .title).foregroundStyle(HomeColor.ink).tint(HomeColor.label)
                .focused($focus, equals: .title).submitLabel(.next).onSubmit { focus = .text }
                .accessibilityIdentifier("memory-title").padding(.top, 14)
            DottedRule().padding(.top, 14)
        }
    }

    private var textField: some View {
        TextField("", text: $form.text, prompt: Text("What do you want to remember?").foregroundStyle(HomeColor.sub), axis: .vertical)
            .lineLimit(3...)
            .memoryFont(17, .regular, serif: true, relativeTo: .body).lineSpacing(5).foregroundStyle(HomeColor.ink).tint(HomeColor.label)
            .focused($focus, equals: .text).frame(minHeight: 80, alignment: .topLeading)
            .accessibilityIdentifier("memory-text").padding(.top, 14)
    }

    // MARK: Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos").font(.system(size: 13, weight: .bold)).tracking(0.02 * 13).foregroundStyle(HomeColor.sub).accessibilityAddTraits(.isHeader)
                Spacer()
                if !form.photoFilenames.isEmpty { Text("\(form.photoFilenames.count) selected").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.sub) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(form.photoFilenames.enumerated()), id: \.element) { index, name in
                        tile { MemoryPhoto(filename: name, maxPixel: 250, radius: 14, spokenLabel: String(localized: "Photo \(index + 1) of \(form.photoFilenames.count)")) }
                            onRemove: { withAnimation { form.photoFilenames.removeAll { $0 == name } } }
                    }
                    ForEach(failedTiles, id: \.self) { id in
                        tile { MemoryUnavailableTile(radius: 14) } onRemove: { withAnimation { failedTiles.removeAll { $0 == id } } }
                    }
                    if importing > 0 {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HomeColor.tint.opacity(0.7)).frame(width: 80, height: 80)
                            .overlay { ProgressView() }.accessibilityLabel(Text("Adding photos"))
                    }
                    PhotosPicker(selection: $pickerItems, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                            Text("Add photos").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(HomeColor.label).frame(width: 80, height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HomeColor.label.opacity(0.6), style: StrokeStyle(lineWidth: 1.6, dash: [5, 4])))
                    }
                    .accessibilityIdentifier("memory-add-photos")
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 22)
    }

    private func tile<Content: View>(@ViewBuilder _ content: () -> Content, onRemove: @escaping () -> Void) -> some View {
        content().frame(width: 80, height: 80)
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white).frame(width: 20, height: 20)
                        .background(.black.opacity(0.78), in: Circle()).frame(width: 44, height: 44, alignment: .topTrailing).contentShape(Rectangle())
                }
                .buttonStyle(.plain).offset(x: 12, y: -12).accessibilityLabel(Text("Remove photo"))
            }
    }

    // MARK: Rows

    private var rowsCard: some View {
        VStack(spacing: 0) {
            dateRow
            divider
            row(icon: "mappin", label: "Place", value: placeValue, set: form.destinationID != nil, id: "memory-row-place") { path.append(.place) }
            divider
            stampRow
            if !trips.isEmpty {
                divider
                row(icon: "suitcase", label: "Trip", value: tripValue, set: form.tripID != nil, id: "memory-row-trip") { path.append(.trip) }
            }
            divider
            tagsRow
        }
        .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
    }

    private var divider: some View { Rectangle().fill(PassportColor.cardLine).frame(height: 1).padding(.leading, 56) }

    private func rowLabel(icon: String, label: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium)).foregroundStyle(HomeColor.label).frame(width: 24)
            Text(label).font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.ink)
        }
    }

    private func row(icon: String, label: LocalizedStringKey, value: String, set: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                rowLabel(icon: icon, label: label)
                Spacer(minLength: 8)
                Text(value).font(.system(size: 15, weight: set ? .semibold : .medium)).foregroundStyle(set ? HomeColor.ink : HomeColor.sub).lineLimit(1)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.ink3)
            }
            .padding(.horizontal, 16).frame(minHeight: 52).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }

    private var dateRow: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.25)) { showDatePicker.toggle() } } label: {
                HStack {
                    rowLabel(icon: "calendar", label: "Date")
                    Spacer(minLength: 8)
                    Text(dateValue).font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.ink).padding(.horizontal, 12).frame(minHeight: 30)
                        .background(PassportColor.quiet, in: Capsule())
                    Image(systemName: showDatePicker ? "chevron.down" : "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.ink3)
                }
                .padding(.horizontal, 16).frame(minHeight: 52).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("memory-row-date")
            if showDatePicker {
                DatePicker("Date", selection: $form.eventDate, in: ...Date.now, displayedComponents: .date).datePickerStyle(.graphical).labelsHidden()
                    .tint(HomeColor.cta).padding(.horizontal, 12).padding(.bottom, 8).transition(.opacity)
            }
        }
    }

    private var stampRow: some View {
        let place = form.destinationID.flatMap { passport.item(id: $0) }
        let inPassport = place?.state.isInPassport ?? false
        return Button { if inPassport { withAnimation { form.stampLinked.toggle() } } } label: {
            HStack {
                rowLabel(icon: "rosette", label: "Stamp")
                Spacer(minLength: 8)
                if let place, inPassport, form.stampLinked {
                    if place.state == .verified { VerifiedSeal(size: 16) }
                    Text(place.destination.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(1)
                } else {
                    Text(stampValue(place: place, inPassport: inPassport)).font(.system(size: 15, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1)
                }
            }
            .padding(.horizontal, 16).frame(minHeight: 52).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!inPassport).accessibilityIdentifier("memory-row-stamp")
    }

    private func stampValue(place: DestinationItem?, inPassport: Bool) -> String {
        if place == nil { return String(localized: "Pick a place first") }
        return inPassport ? String(localized: "None") : String(localized: "Not in your passport")
    }

    private var tagsRow: some View {
        Button { path.append(.tags) } label: {
            HStack(alignment: .center) {
                rowLabel(icon: "tag", label: "Tags")
                Spacer(minLength: 8)
                if form.tags.isEmpty { Text("Add tags").font(.system(size: 15, weight: .medium)).foregroundStyle(HomeColor.sub) }
                else { Text(form.tags.joined(separator: ", ")).font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(1) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.ink3)
            }
            .padding(.horizontal, 16).frame(minHeight: 52).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier("memory-row-tags")
    }

    private var privacyLine: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock").font(.system(size: 12, weight: .semibold))
            Text("Private by default. Memories are left out of anything you share unless you choose to include them.").font(.system(size: 12.5, weight: .medium))
        }
        .foregroundStyle(HomeColor.sub).accessibilityElement(children: .combine)
    }

    private func errorBlock(_ message: String) -> some View {
        InlineErrorView(title: "Couldn’t save", message: message, retry: save)
    }

    private var placeValue: String {
        guard let id = form.destinationID else { return String(localized: "None") }
        guard let d = env.catalog.destination(id: id) else { return String(localized: "Place no longer in the catalog") }
        return "\(d.name), \(d.countryName)"
    }

    private var tripValue: String { form.tripID.flatMap { id in trips.first { $0.id == id }?.title } ?? String(localized: "None") }

    private var dateValue: String {
        Calendar.current.isDateInToday(form.eventDate) ? String(localized: "Today") : form.eventDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }

    // MARK: State

    private var hasContent: Bool {
        !form.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !form.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !form.photoFilenames.isEmpty
    }

    private var hasChanges: Bool { loaded && form != initial }

    /// Create: something to say. Edit: something to say and something changed. Never while a photo is still loading.
    private var canSave: Bool { importing == 0 && hasContent && (isEdit ? hasChanges : true) }

    private func load() {
        guard !loaded else { return }
        if let memory {
            form = MemoryForm(title: memory.title, text: memory.text, eventDate: memory.eventDate, destinationID: memory.destinationID,
                              stampLinked: memory.stampID != nil, tripID: memory.tripID, tags: memory.tags, photoFilenames: memory.photoFilenames)
        } else {
            form = MemoryForm(eventDate: Calendar.current.startOfDay(for: .now), destinationID: prefilledDestinationID, tripID: prefilledTripID)
        }
        initial = form
        loaded = true
    }

    // MARK: Actions

    private func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        importing += items.count
        pickerItems = []
        Task {
            for item in items {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoStoreError.unreadable }
                    let name = try await env.photos.importPhoto(data: data)
                    importedThisSession.append(name)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { form.photoFilenames.append(name) }
                } catch {
                    failedTiles.append(UUID())
                }
                importing -= 1
            }
        }
    }

    private func save() {
        guard canSave else { return }
        var draft = MemoryDraft()
        draft.title = form.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.text = form.text.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.eventDate = min(form.eventDate, .now)
        draft.destinationID = form.destinationID
        let linkable = form.destinationID.flatMap { passport.item(id: $0) }?.state.isInPassport ?? false
        draft.stampID = (linkable && form.stampLinked) ? form.destinationID.map(StampID.make(for:)) : nil
        draft.tripID = form.tripID
        draft.tags = MemoryTags.normalize(form.tags)
        draft.photoFilenames = form.photoFilenames
        do {
            try env.store.saveMemory(draft, replacing: memory)
            saveError = nil
            env.haptics.success()
            env.toasts.show(isEdit ? String(localized: "Changes saved") : String(localized: "Memory saved"))
            dismiss()
        } catch {
            saveError = String(localized: "Your memory couldn’t be saved. Nothing was lost.")
        }
    }

    private func cancel() {
        if hasChanges || (!isEdit && (hasContent || !importedThisSession.isEmpty)) { showDiscard = true } else { dismiss() }
    }

    /// Photos added in this sheet but never saved are removed so nothing is orphaned.
    private func discard() {
        let kept = Set(memory?.photoFilenames ?? [])
        let orphans = importedThisSession.filter { !kept.contains($0) }
        if !orphans.isEmpty { env.photos.deletePhotos(named: orphans) }
        dismiss()
    }
}

/// The editable fields of the sheet, compared with the loaded state to know whether anything changed.
struct MemoryForm: Equatable {
    var title = ""
    var text = ""
    var eventDate = Calendar.current.startOfDay(for: .now)
    var destinationID: String?
    /// Whether the memory is linked to the place's stamp (when that stamp is in the passport). Linking is automatic; "None" unlinks.
    var stampLinked = true
    var tripID: UUID?
    var tags: [String] = []
    var photoFilenames: [String] = []
}

// MARK: - Pickers

/// Pushed inside the sheet: a searchable list of catalog places, with None first and the places already in the passport next.
struct MemoryPlacePicker: View {
    @Binding var selection: String?
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var places: [Destination] {
        let found = env.catalog.search(query)
        guard query.trimmingCharacters(in: .whitespaces).isEmpty else { return found }
        let inPassport = found.filter { passport.snapshot.state(of: $0.id).isInPassport }
        return inPassport + found.filter { !passport.snapshot.state(of: $0.id).isInPassport }
    }

    var body: some View {
        List {
            Button { selection = nil; dismiss() } label: {
                HStack { Text("None").foregroundStyle(HomeColor.ink); Spacer(); if selection == nil { Image(systemName: "checkmark").foregroundStyle(HomeColor.label) } }
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).listRowBackground(HomeColor.page).accessibilityIdentifier("memory-place-none")
            ForEach(places) { place in
                Button { selection = place.id; dismiss() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(place.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.ink)
                            Text("\(place.countryName) · \(place.category.singularTitle)").font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.sub)
                        }
                        Spacer()
                        if selection == place.id { Image(systemName: "checkmark").foregroundStyle(HomeColor.label) }
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).listRowBackground(HomeColor.page).accessibilityAddTraits(selection == place.id ? .isSelected : [])
                .accessibilityIdentifier("memory-place-\(place.id)")
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(HomeColor.page)
        .searchable(text: $query, prompt: "Search places").navigationTitle("Place").navigationBarTitleDisplayMode(.inline)
    }
}

struct MemoryTripPicker: View {
    @Binding var selection: UUID?
    let trips: [Trip]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Button { selection = nil; dismiss() } label: {
                HStack { Text("None").foregroundStyle(HomeColor.ink); Spacer(); if selection == nil { Image(systemName: "checkmark").foregroundStyle(HomeColor.label) } }
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).listRowBackground(HomeColor.page)
            ForEach(trips) { trip in
                Button { selection = trip.id; dismiss() } label: {
                    HStack { Text(trip.title).foregroundStyle(HomeColor.ink); Spacer(); if selection == trip.id { Image(systemName: "checkmark").foregroundStyle(HomeColor.label) } }
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).listRowBackground(HomeColor.page).accessibilityAddTraits(selection == trip.id ? .isSelected : [])
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(HomeColor.page)
        .navigationTitle("Trip").navigationBarTitleDisplayMode(.inline)
    }
}

/// A text field, the person's existing tags as suggestions (most used first) and the current tags as removable chips.
struct MemoryTagEditor: View {
    @Binding var tags: [String]
    let suggestions: [String]
    @State private var text = ""
    @FocusState private var focused: Bool

    private var available: [String] { suggestions.filter { s in !tags.contains { MemoryTags.key($0) == MemoryTags.key(s) } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    TextField("", text: $text, prompt: Text("Add a tag").foregroundStyle(HomeColor.sub))
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(HomeColor.ink).focused($focused).submitLabel(.done)
                        .textInputAutocapitalization(.never).onSubmit(add).onChange(of: text) { _, new in if new.count > MemoryTags.maxLength { text = String(new.prefix(MemoryTags.maxLength)) } }
                        .accessibilityIdentifier("memory-tag-field")
                    Button("Add", action: add).font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.label)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || tags.count >= MemoryTags.maxCount).frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("memory-tag-add")
                }
                .padding(.horizontal, 16).frame(minHeight: 48).background(PassportColor.quiet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
                if !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("^[\(tags.count) tag](inflect: true), up to \(MemoryTags.maxCount)").font(.system(size: 13, weight: .bold)).foregroundStyle(HomeColor.sub)
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Button { tags.removeAll { $0 == tag } } label: {
                                    HStack(spacing: 6) { Text(tag); Image(systemName: "xmark").font(.system(size: 10, weight: .bold)) }
                                        .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(HomeColor.ctaText).padding(.horizontal, 14).frame(minHeight: 36)
                                        .background(HomeColor.cta, in: Capsule()).frame(minHeight: 44).contentShape(Capsule())
                                }
                                .buttonStyle(.plain).accessibilityLabel(Text("\(tag), remove"))
                            }
                        }
                    }
                }
                if !available.isEmpty, tags.count < MemoryTags.maxCount {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your tags").font(.system(size: 13, weight: .bold)).foregroundStyle(HomeColor.sub)
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(available.prefix(20), id: \.self) { tag in
                                Button { tags = MemoryTags.normalize(tags + [tag]) } label: {
                                    Text(tag).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(HomeColor.ink).padding(.horizontal, 14).frame(minHeight: 36)
                                        .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
                                        .frame(minHeight: 44).contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(HomeColor.page.ignoresSafeArea()).navigationTitle("Tags").navigationBarTitleDisplayMode(.inline).onAppear { focused = true }
    }

    private func add() {
        guard tags.count < MemoryTags.maxCount else { return }
        tags = MemoryTags.normalize(tags + [text])
        text = ""
    }
}
