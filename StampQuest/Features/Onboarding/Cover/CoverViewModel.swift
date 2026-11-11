import Foundation
import Observation

/// Selection and name for the Cover screen. The selected cover lives in `OnboardingModel.coverStyle` (persisted on every
/// `select`), and the hero, swatch ring, name label and Passport ready all read it. A Plus cover without Plus is kept as the
/// stored selection but shown as the resolved free cover when the screen is entered again. The name is a plain string kept in
/// the on-device onboarding store: it goes nowhere else.
@MainActor
@Observable
final class CoverViewModel {
    let model: OnboardingModel
    private(set) var selected: CoverStyle
    /// Sanitized live as the person types.
    private(set) var typedName: String
    let isRestored: Bool

    init(model: OnboardingModel) {
        self.model = model
        isRestored = model.isRevisit(.cover)
        let available = model.availableCovers
        let shown = CoverEntitlementResolver.effectiveCover(selected: model.coverStyle, isEntitled: model.isPlusEntitled)
        selected = available.contains(shown) ? shown : (available.contains(.default) ? .default : available[0])
        typedName = CoverName.sanitizeWhileTyping(model.coverName)
    }

    var covers: [CoverStyle] { model.availableCovers }
    /// Plus markers exist only when the paywall flag is on.
    var showsPlus: Bool { model.flags.plusPaywallEnabled }
    /// What the cover prints and the store keeps: trimmed, single-spaced, at most 24 characters, no control characters.
    var displayName: String { CoverName.committed(typedName) }
    var selectedIndex: Int { covers.firstIndex(of: selected) ?? 0 }
    /// Whether the chosen cover is a Plus cover. The screen only records it; what a non-subscriber gets is decided later.
    var coverIsPlus: Bool { selected.isPlus }
    var selectedShowsPlusMarker: Bool { showsPlus && selected.isPlus }

    /// The one way a cover is chosen: a swatch tap, a swipe settling or a restore. It is stored at once.
    func select(_ style: CoverStyle) {
        guard covers.contains(style) else { return }
        selected = style
        model.selectCover(style)
    }

    func setName(_ raw: String) { typedName = CoverName.sanitizeWhileTyping(raw) }

    /// Saves the normalised name next to the stored selection (which Continue never changes), then routes on.
    func continueTapped() {
        model.commitCover(model.coverStyle, name: displayName)
        model.continueFrom(.cover)
    }

    /// Skip: the default cover and no name, then the same routing.
    func skipTapped() { model.skip(from: .cover) }
}
