import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @Query private var stamps: [UserStamp]
    @Query private var wishlist: [WishlistItem]
    @Query private var trips: [Trip]
    @Query private var memories: [MemoryEntry]
    @State private var exportOptions = ExportOptions()
    @State private var confirmDelete = false
    @State private var confirmReset = false
    @State private var errorMessage: String?
    @State private var deleted = false

    var body: some View {
        @Bindable var prefs = env.preferences
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $prefs.appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("appearance-picker")
                VStack(alignment: .leading, spacing: SQSpace.xs) {
                    Text("Passport cover").font(SQFont.body)
                    HStack(spacing: SQSpace.sm) {
                        ForEach(PassportStyle.allCases) { style in
                            Button { prefs.passportStyle = style } label: {
                                Circle().fill(style.color).frame(width: 34, height: 34)
                                    .overlay(Circle().strokeBorder(SQColor.textPrimary, lineWidth: prefs.passportStyle == style ? 2.5 : 0).padding(-4))
                                    .frame(width: SQHit.minimum, height: SQHit.minimum)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(style.title)
                            .accessibilityAddTraits(prefs.passportStyle == style ? .isSelected : [])
                        }
                    }
                }
            }
            Section {
                Toggle("Haptic feedback", isOn: $prefs.hapticsEnabled)
                Picker("Reduce motion", selection: $prefs.motion) {
                    ForEach(MotionPreference.allCases) { Text($0.title).tag($0) }
                }
            } header: { Text("Motion & haptics") } footer: {
                Text("“Follow system” respects the Reduce Motion setting in iOS. Haptics are only used for meaningful moments, like a stamp landing.")
            }
            Section {
                Toggle("Offer visit verification", isOn: $prefs.locationVerificationEnabled)
                    .accessibilityIdentifier("verification-toggle")
                LabeledContent("Location access", value: authorizationText)
                Button("Open iOS Settings") { env.openSystemSettings() }
            } header: { Text("Location verification") } footer: {
                Text("Verification is optional and happens only when you tap “Verify my visit”. StampQuest checks your location once, in the foreground. It never tracks you or keeps a location history, and manual collecting always works.")
            }
            Section("Privacy") {
                NavigationLink("Privacy & your data") { PrivacyView() }
                if let url = AppConfiguration.privacyPolicyURL { Button("Privacy policy") { openURL(url) } }
                if let url = AppConfiguration.termsURL { Button("Terms of use") { openURL(url) } }
            }
            Section {
                Toggle("Include private notes", isOn: $exportOptions.includePrivateNotes)
                ShareLink(item: exportFile, preview: SharePreview("StampQuest passport backup", image: Image(systemName: "book.closed"))) {
                    Label("Export my data", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("export-data")
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete all my data…", systemImage: "trash") }
                    .accessibilityIdentifier("delete-all-data")
                Button("Reset preferences") { confirmReset = true }
            } header: { Text("Your data") } footer: {
                Text("The export is a JSON file of your stamps, wishlist and trips. Journal text, captions and trip notes are left out unless you include them. Photos are never exported.")
            }
            Section("Catalog") {
                LabeledContent("Version", value: env.catalog.version)
                LabeledContent("Destinations", value: "\(env.catalog.destinations.count)")
                LabeledContent("Collections", value: "\(env.catalog.collections.count)")
                if !env.catalog.issues.isEmpty {
                    LabeledContent("Skipped entries", value: "\(env.catalog.issues.count)")
                }
            }
            Section("About StampQuest") {
                LabeledContent("Version", value: AppConfiguration.versionString)
                Text("Your world, one stamp at a time.").font(SQFont.story).foregroundStyle(SQColor.textSecondary)
                Text("All stamp illustrations are original artwork drawn for StampQuest.").font(SQFont.caption).foregroundStyle(SQColor.textSecondary)
                if let email = AppConfiguration.supportEmail, let url = URL(string: "mailto:\(email)") {
                    Button("Send feedback") { openURL(url) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .sqScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete all your data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every stamp, wishlist entry, memory, trip and photo from this device. It can’t be undone, so export first if you want a copy.")
        }
        .confirmationDialog("Reset preferences?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset preferences", role: .destructive) { env.preferences.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Appearance, haptics, motion and location settings return to their defaults. Your passport isn’t affected.") }
        .alert("Couldn’t delete", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .alert("All data deleted", isPresented: $deleted) { Button("OK", role: .cancel) {} } message: {
            Text("Your passport is empty again. Nothing is stored on this device.")
        }
    }

    private var authorizationText: String {
        switch env.verification.authorization {
        case .authorized: String(localized: "Allowed")
        case .denied: String(localized: "Not allowed")
        case .restricted: String(localized: "Restricted")
        case .notDetermined: String(localized: "Not asked yet")
        }
    }

    private var exportFile: PassportExportFile {
        let catalogVersion = env.catalog.version
        let options = exportOptions
        let stamps = stamps, wishlist = wishlist, trips = trips, memories = memories
        return PassportExportFile {
            let export = PassportExporter.make(stamps: stamps, wishlist: wishlist, trips: trips, memories: memories,
                                               catalogVersion: catalogVersion, options: options)
            return try PassportExporter.encode(export)
        }
    }

    private func deleteAll() {
        do {
            try env.store.deleteAllData()
            env.preferences.clearRecentlyViewed()
            deleted = true
        } catch {
            errorMessage = (error as? PassportError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.lg) {
                Text("Your passport belongs to you").font(SQFont.display).foregroundStyle(SQColor.textPrimary)
                section("lock.shield", "Stays on your device", "Stamps, wishlist, memories, trips and photos are stored only on this device. There’s no account, no sign-in, and nothing is uploaded.")
                section("eye.slash", "No tracking", "StampQuest has no analytics, advertising or tracking code, and doesn’t build a profile of you.")
                section("location", "Location, only when you ask", "Location is used once, in the foreground, when you tap “Verify my visit”. Your coordinates are never saved or sent anywhere. If verification succeeds, only the distance to the place and the accuracy of the reading are kept. You can still collect any stamp without verifying.")
                section("photo", "Photos you choose", "StampQuest only sees photos you pick for a memory. They’re copied into the app, shrunk, and stripped of embedded location data.")
                section("square.and.arrow.up", "Sharing is deliberate", "Shared stamp images contain only the artwork and public place name. Your notes, memories, photos and location are never included.")
                section("trash", "You’re in control", "You can export your data or delete everything at any time from Settings.")
            }
            .padding(SQSpace.screenMargin)
        }
        .sqScreenBackground()
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ symbol: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: SQSpace.md) {
            Image(systemName: symbol).font(.system(size: 20, weight: .medium)).frame(width: 32)
                .foregroundStyle(SQColor.accentText).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SQSpace.xxs) {
                Text(title).font(SQFont.headline).foregroundStyle(SQColor.textPrimary).accessibilityAddTraits(.isHeader)
                Text(text).font(SQFont.body).foregroundStyle(SQColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
