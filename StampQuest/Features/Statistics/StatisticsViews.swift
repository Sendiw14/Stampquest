import SwiftUI
import Charts

struct StatisticsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport

    var body: some View {
        let stats = passport.statistics
        ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.lg) {
                VStack(alignment: .leading, spacing: SQSpace.xxs) {
                    Text("Your travel story").sqEyebrow()
                    Text(stats.collectedStamps == 0 ? "Nothing yet" : "\(stats.collectedStamps) \(stats.collectedStamps == 1 ? "stamp" : "stamps")")
                        .font(SQFont.display).foregroundStyle(SQColor.textPrimary)
                    Text("Every number here is counted from your records.").font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: SQSpace.sm), GridItem(.flexible(), spacing: SQSpace.sm)], spacing: SQSpace.sm) {
                    StatTile(value: stats.collectedStamps, label: "Stamps collected", systemImage: "checkmark.seal")
                    StatTile(value: stats.verifiedVisits, label: "Verified visits", systemImage: "location.circle")
                    StatTile(value: stats.countriesCollected, label: "Countries", systemImage: "flag")
                    StatTile(value: stats.regionsExplored, label: "Regions explored", systemImage: "globe")
                    StatTile(value: stats.completedCollections, label: "Collections completed", systemImage: "rosette")
                    StatTile(value: stats.wishlistCount, label: "On your wishlist", systemImage: "heart")
                    StatTile(value: stats.memories, label: "Memories", systemImage: "heart.text.square")
                    StatTile(value: stats.trips, label: "Trips", systemImage: "suitcase")
                }
                .accessibilityIdentifier("statistics-grid")
                timeline
                countries
                definitions
            }
            .padding(.horizontal, SQSpace.screenMargin)
            .padding(.bottom, SQSpace.xxl)
            .sqReadableWidth()
        }
        .sqScreenBackground()
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var timeline: some View {
        let months = ActivityTimeline.monthlyCounts(of: passport.snapshot.stamps)
        let total = months.reduce(0) { $0 + $1.stamps }
        return VStack(alignment: .leading, spacing: SQSpace.sm) {
            SectionHeader(title: "Collecting over time", subtitle: "Stamps per month, last 12 months")
            if passport.snapshot.stamps.count < 2 || total == 0 {
                Text("Your timeline will appear here once you’ve collected a couple of stamps.")
                    .font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
                    .padding(SQSpace.md).frame(maxWidth: .infinity, alignment: .leading)
                    .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
            } else {
                Chart(months) { month in
                    BarMark(x: .value("Month", month.monthStart, unit: .month), y: .value("Stamps", month.stamps))
                        .foregroundStyle(SQColor.accent)
                        .cornerRadius(3)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .month, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.narrow)) } }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 160)
                .padding(SQSpace.md)
                .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Stamps collected per month over the last 12 months")
                .accessibilityValue(months.filter { $0.stamps > 0 }.map { "\($0.monthStart.formatted(.dateTime.month(.wide))): \($0.stamps)" }.joined(separator: ", "))
            }
        }
    }

    @ViewBuilder
    private var countries: some View {
        let grouped = Dictionary(grouping: passport.snapshot.stamps, by: \.countryCode)
            .map { (code: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : CountryInfo.name(for: $0.code) < CountryInfo.name(for: $1.code) }
        if !grouped.isEmpty {
            VStack(alignment: .leading, spacing: SQSpace.sm) {
                SectionHeader(title: "Countries")
                VStack(spacing: 0) {
                    ForEach(Array(grouped.enumerated()), id: \.element.code) { index, entry in
                        Button { env.router.push(.country(entry.code)) } label: {
                            HStack {
                                Text("\(CountryInfo.flag(for: entry.code)) \(CountryInfo.name(for: entry.code))").font(SQFont.body).foregroundStyle(SQColor.textPrimary)
                                Spacer()
                                Text("\(entry.count)").font(SQFont.body.monospacedDigit()).foregroundStyle(SQColor.textSecondary)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(SQColor.textTertiary)
                            }
                            .padding(.horizontal, SQSpace.md)
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < grouped.count - 1 { Divider().overlay(SQColor.separator).padding(.leading, SQSpace.md) }
                    }
                }
                .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
            }
        }
    }

    private var definitions: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            Text("How we count").font(SQFont.headline)
            Group {
                Text("**Stamps** are unique stamps in your passport. **Verified visits** are stamps where a location check succeeded at the time; collecting manually is never counted as a verified visit.")
                Text("**Countries** and **Regions** come from the stamps you’ve collected. Wishlisted places are never counted as visited.")
            }
            .font(SQFont.caption).foregroundStyle(SQColor.textSecondary)
        }
        .padding(.top, SQSpace.xs)
    }
}

struct AchievementsView: View {
    @Environment(\.passport) private var passport

    var body: some View {
        let unlocked = passport.achievements.filter(\.isUnlocked).count
        ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.lg) {
                VStack(alignment: .leading, spacing: SQSpace.xxs) {
                    Text("\(unlocked) of \(passport.achievements.count) unlocked").font(SQFont.display).foregroundStyle(SQColor.textPrimary)
                    Text("Milestones come from your real records and unlock quietly, at your own pace.")
                        .font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: SQSpace.sm)], spacing: SQSpace.sm) {
                    ForEach(passport.achievements) { AchievementCard(achievement: $0) }
                }
            }
            .padding(.horizontal, SQSpace.screenMargin)
            .padding(.bottom, SQSpace.xxl)
            .sqReadableWidth()
        }
        .sqScreenBackground()
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
