import SwiftUI

// MARK: - Section header

struct SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SQFont.section)
                    .foregroundStyle(SQColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(SQFont.meta).foregroundStyle(SQColor.textSecondary)
                }
            }
            Spacer(minLength: SQSpace.sm)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle).font(SQFont.subheadline.weight(.semibold))
                }
                .foregroundStyle(SQColor.accentText)
                .frame(minHeight: SQHit.minimum)
            }
        }
    }
}

// MARK: - Chips

struct CategoryChip: View {
    let title: String
    var systemImage: String?
    var isSelected = false

    var body: some View {
        HStack(spacing: SQSpace.xxs) {
            if let systemImage { Image(systemName: systemImage).imageScale(.small) }
            Text(title).lineLimit(1)
        }
        .font(SQFont.subheadline.weight(.medium))
        .foregroundStyle(isSelected ? SQColor.onAccent : SQColor.textPrimary)
        .padding(.horizontal, SQSpace.sm)
        .frame(minHeight: 36)
        .background(isSelected ? SQColor.accentStrong : SQColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(isSelected ? .clear : SQColor.border, lineWidth: 1))
        .contentShape(Capsule())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Destination card (carousels)

struct DestinationCard: View {
    let item: DestinationItem
    var caption: String?
    var width: CGFloat = 176

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.sm) {
            PerforatedStampView(design: item.design, presentation: .full, isDecorative: true)
                .padding(.horizontal, SQSpace.xs)
                .padding(.top, SQSpace.xs)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.destination.name)
                    .font(SQFont.headline.weight(.semibold))
                    .foregroundStyle(SQColor.textPrimary)
                    .lineLimit(2)
                Text(item.destination.subtitle)
                    .font(SQFont.meta)
                    .foregroundStyle(SQColor.textSecondary)
                    .lineLimit(2)
                if let caption {
                    Text(caption)
                        .font(SQFont.caption.weight(.medium))
                        .foregroundStyle(SQColor.accentText)
                        .padding(.top, 2)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            if item.state != .notCollected { StampCollectionStateBadge(state: item.state) }
        }
        .padding(SQSpace.sm)
        .frame(width: width, alignment: .topLeading)
        .frame(minHeight: width * 1.62, alignment: .top)
        .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SQRadius.large, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.destination.name), \(item.destination.subtitle)")
        .accessibilityValue(caption.map { "\(item.state.title). \($0)" } ?? item.state.title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Destination row (lists)

struct DestinationRow: View {
    let item: DestinationItem
    var detail: String?

    var body: some View {
        HStack(spacing: SQSpace.md) {
            PerforatedStampView(design: item.design, showsTitle: false, isDecorative: true)
                .frame(width: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.destination.name)
                    .font(SQFont.headline)
                    .foregroundStyle(SQColor.textPrimary)
                    .lineLimit(2)
                Text(detail ?? item.destination.subtitle)
                    .font(SQFont.meta)
                    .foregroundStyle(SQColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: SQSpace.xs)
            if item.state != .notCollected { StampCollectionStateBadge(state: item.state, compact: true) }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SQColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, SQSpace.xs)
        .frame(minHeight: SQHit.minimum)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.destination.name), \(detail ?? item.destination.subtitle)")
        .accessibilityValue(item.state.title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Stamp grid item

struct StampGridItem: View {
    let item: DestinationItem
    var showsPostmark: Bool = false
    var postmarkDate: Date?

    var body: some View {
        VStack(spacing: SQSpace.xs) {
            PassportStamp(design: item.design,
                          presentation: item.state.isInPassport ? .full : .muted,
                          postmark: showsPostmark && item.state.isInPassport
                              ? (item.destination.name, postmarkDate ?? .now, item.state == .verified ? .verified : .collected) : nil,
                          isDecorative: true)
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.destination.name)
                        .font(SQFont.subheadline.weight(.semibold))
                        .foregroundStyle(item.state.isInPassport ? SQColor.textPrimary : SQColor.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    if !item.state.isInPassport {
                        Image(systemName: item.state == .wishlisted ? "heart.fill" : "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(item.state.tint)
                            .accessibilityHidden(true)
                    }
                }
                Text(item.destination.subtitle)
                    .font(SQFont.caption)
                    .foregroundStyle(SQColor.textSecondary)
                    .lineLimit(1)
                if item.state == .verified {
                    Label("Verified", systemImage: "location.circle.fill")
                        .font(SQFont.caption.weight(.medium))
                        .foregroundStyle(SQColor.verified)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.destination.name), \(item.destination.subtitle)")
        .accessibilityValue(item.state.title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Collection

struct CollectionProgressView: View {
    let progress: CollectionProgress
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AccessibleProgressIndicator(value: progress.collected, total: progress.total,
                                        tint: progress.isComplete ? SQColor.success : SQColor.accent,
                                        height: compact ? 6 : 8)
            HStack {
                Text("\(progress.collected) of \(progress.total)")
                    .font(SQFont.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(SQColor.textSecondary)
                if progress.isComplete {
                    Spacer()
                    Label("Complete", systemImage: "rosette")
                        .font(SQFont.caption.weight(.semibold))
                        .foregroundStyle(SQColor.success)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A collection tile: cover stamp, title, summary and progress.
struct CollectionCard: View {
    let progress: CollectionProgress
    let cover: DestinationItem?
    var width: CGFloat? = 260

    var body: some View {
        HStack(alignment: .top, spacing: SQSpace.sm) {
            if let cover {
                PerforatedStampView(design: cover.design, showsTitle: false, isDecorative: true)
                    .frame(width: 64)
                    .rotationEffect(.degrees(-3))
            }
            VStack(alignment: .leading, spacing: SQSpace.xxs) {
                Label(progress.collection.subtitle, systemImage: progress.collection.symbolName)
                    .font(SQFont.caption.weight(.medium))
                    .foregroundStyle(SQColor.textSecondary)
                    .labelStyle(.titleOnly)
                Text(progress.collection.title)
                    .font(SQFont.headline.weight(.semibold))
                    .foregroundStyle(SQColor.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                CollectionProgressView(progress: progress, compact: true)
            }
        }
        .padding(SQSpace.sm)
        .frame(width: width, height: 120, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SQRadius.large, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: Int
    let label: LocalizedStringKey
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.xxs) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SQColor.accentText)
                .accessibilityHidden(true)
            Text("\(value)")
                .font(SQFont.numeral)
                .foregroundStyle(SQColor.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(SQFont.caption)
                .foregroundStyle(SQColor.textSecondary)
                .lineLimit(2)
        }
        .padding(SQSpace.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Achievement card

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            ZStack {
                Circle().fill(achievement.isUnlocked ? SQColor.accent.opacity(0.18) : SQColor.stone.opacity(0.4))
                Image(systemName: achievement.isUnlocked ? achievement.symbolName : "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? SQColor.accentText : SQColor.textTertiary)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)
            Text(achievement.title).font(SQFont.subheadline.weight(.semibold)).foregroundStyle(SQColor.textPrimary)
            if let date = achievement.unlockedAt {
                Text(date.formatted(date: .abbreviated, time: .omitted)).font(SQFont.caption).foregroundStyle(SQColor.textSecondary)
            } else {
                Text(achievement.detail).font(SQFont.caption).foregroundStyle(SQColor.textSecondary).lineLimit(3)
                AccessibleProgressIndicator(value: achievement.current, total: achievement.target, height: 5)
            }
        }
        .padding(SQSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 150, alignment: .top)
        .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(achievement.title)
        .accessibilityValue(achievement.isUnlocked ? "Unlocked \(achievement.unlockedAt?.formatted(date: .long, time: .omitted) ?? "")"
                                                    : "\(achievement.current) of \(achievement.target). \(achievement.detail)")
    }
}
