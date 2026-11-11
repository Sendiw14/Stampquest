import SwiftUI

/// The chips of the active filters and "Showing 3 of 8 stamps" under the controls.
struct PassportFilterSummary: View {
    let chips: [PassportFilterChip]
    let shown: Int
    let total: Int
    let onRemove: (PassportFilterChip.Kind) -> Void
    let onClearAll: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var size = 14.5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !chips.isEmpty {
                HStack(alignment: .top) {
                    FlowLayout(spacing: 8, lineSpacing: 8) { ForEach(chips) { chip(for: $0) } }
                    Spacer(minLength: 8)
                    Button("Clear all", action: onClearAll).font(.system(size: size, weight: .semibold)).foregroundStyle(HomeColor.label)
                        .frame(minHeight: 44).fixedSize().accessibilityIdentifier("passport-clear-all")
                }
            }
            Text("Showing \(shown) of ^[\(total) stamp](inflect: true)").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.sub)
                .contentTransition(.opacity).accessibilityIdentifier("passport-count")
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
    }

    private func chip(for chip: PassportFilterChip) -> some View {
        Button { onRemove(chip.kind) } label: {
            HStack(spacing: 6) {
                Text(chip.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(HomeColor.label).padding(.horizontal, 12).frame(minHeight: 32)
            .background(PassportColor.accentTint, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.accentBorder, lineWidth: 1))
            .frame(minHeight: 44).contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Filter: \(chip.title)")).accessibilityHint(Text("Double tap to remove.")).accessibilityIdentifier("passport-chip-\(chip.id)")
    }
}

/// After the last row: "That is all 8 so far." with Explore, or "Not seeing one?" with Clear while filters hide stamps.
struct PassportFooterCard: View {
    let total: Int
    let hidden: Int
    let onExplore: () -> Void
    let onClear: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var titleSize = 17.0
    @ScaledMetric(relativeTo: .footnote) private var bodySize = 13.0

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 12) { copy; button } }
            else { HStack(spacing: 12) { copy; Spacer(minLength: 0); button } }
        }
        .padding(.horizontal, 20).padding(.vertical, 16).frame(minHeight: 92)
        .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 3) {
            if hidden > 0 {
                Text("Not seeing one?").font(.system(size: titleSize, weight: .semibold)).foregroundStyle(HomeColor.ink)
                (hidden == 1 ? Text("1 stamp is hidden by your filters.") : Text("\(hidden) stamps are hidden by your filters.")).font(.system(size: bodySize, weight: .medium)).foregroundStyle(HomeColor.sub)
            } else {
                Text("That is all \(total) so far.").font(.system(size: titleSize, weight: .semibold)).foregroundStyle(HomeColor.ink)
                Text("Find your next stamp.").font(.system(size: bodySize, weight: .medium)).foregroundStyle(HomeColor.sub)
            }
        }
    }

    private var button: some View {
        Button(action: hidden > 0 ? onClear : onExplore) {
            Text(hidden > 0 ? "Clear" : "Explore").font(.system(size: 15.5, weight: .bold)).foregroundStyle(HomeColor.ctaText)
                .frame(minWidth: 90, minHeight: 44).padding(.horizontal, 8).background(HomeColor.cta, in: Capsule())
        }
        .buttonStyle(.plain).accessibilityIdentifier(hidden > 0 ? "passport-footer-clear" : "passport-footer-explore")
    }
}

/// An empty passport below the first-stamp card: "Your page" with three dashed slots and the add-by-hand route.
struct PassportEmptyState: View {
    let width: CGFloat
    let onAdd: () -> Void

    @ScaledMetric(relativeTo: .body) private var bodySize = 15.0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PassportSectionHeader(title: "Your page")
            VStack(spacing: 18) {
                let slotWidth = (width - 40 - 48 - 24) / 3
                HStack(spacing: 12) {
                    PassportEmptySlot(width: slotWidth, showsPlus: true, onAdd: onAdd)
                    PassportEmptySlot(width: slotWidth, showsPlus: false, onAdd: onAdd)
                    PassportEmptySlot(width: slotWidth, showsPlus: false, onAdd: onAdd)
                }
                Text("Collected places land here.").font(.system(size: bodySize, weight: .medium)).foregroundStyle(HomeColor.sub).multilineTextAlignment(.center)
                Button(action: onAdd) {
                    Text("Add a stamp by hand").font(.system(size: bodySize, weight: .bold)).foregroundStyle(HomeColor.label).frame(minHeight: 44)
                }
                .buttonStyle(.plain).accessibilityIdentifier("passport-add-by-hand")
            }
            .frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, 24)
            .background {
                ZStack {
                    PerforatedStampShape(perforationsAcrossWidth: 26, notchRatio: 0.3).fill(HomeColor.postcard)
                    RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1).padding(9)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

/// "Removed, Undo": a toast for six seconds after a stamp leaves the passport.
struct PassportUndoToast: View {
    let name: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(name) removed").font(.system(size: 15, weight: .semibold)).lineLimit(2)
            Spacer(minLength: 8)
            Button("Undo", action: onUndo).font(.system(size: 15, weight: .bold)).frame(minHeight: 44).accessibilityIdentifier("passport-undo")
        }
        .foregroundStyle(HomeColor.page).padding(.horizontal, 18).frame(minHeight: 52)
        .background(HomeColor.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine).accessibilityIdentifier("passport-undo-toast")
    }
}
