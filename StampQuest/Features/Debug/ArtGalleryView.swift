#if DEBUG
import SwiftUI

/// Developer tool: shows every motif (and notable variants) as a stamp and can
/// export contact sheets as PNGs for visual QA. Launch with `-art-gallery`.
struct ArtGalleryView: View {
    struct Entry: Identifiable {
        let id: String
        let design: StampDesign
    }

    static let plan: [(ArtMotif, Int, String, Bool)] = [
        (.eiffel, 0, "goldenHour", false), (.tokyoTower, 0, "dusk", false), (.towerBridge, 0, "oceanDay", false),
        (.colosseum, 0, "terracotta", false), (.sagrada, 0, "ochre", false), (.hillTown, 0, "oceanDay", false),
        (.hillTown, 1, "coral", false), (.hillTown, 2, "lagoon", false), (.canals, 0, "rose", false),
        (.canals, 1, "haze", false), (.stoneBridge, 0, "goldenHour", false), (.parthenon, 0, "ochre", false),
        (.towerFort, 0, "coral", false), (.castleHill, 0, "blueHour", false), (.fairyCastle, 0, "alpine", false),
        (.hallgrimskirkja, 0, "aurora", true), (.fjord, 0, "emerald", false), (.peaks, 0, "alpine", false),
        (.peaks, 1, "haze", false), (.duomo, 0, "terracotta", false), (.parliament, 0, "dusk", false),
        (.parliament, 1, "night", true), (.alpineVillage, 0, "alpine", false), (.meteora, 0, "desert", false),
        (.cappadocia, 0, "coral", false), (.maidenTower, 0, "rose", false), (.torii, 0, "vermilion", false),
        (.fuji, 0, "haze", false), (.tajMahal, 0, "rose", false), (.angkor, 0, "jungle", false),
        (.greatWall, 0, "ochre", false), (.marinaBay, 0, "dusk", false), (.pagoda, 0, "rose", false),
        (.burj, 0, "desert", false), (.petra, 0, "terracotta", false), (.halong, 0, "emerald", false),
        (.hanokPalace, 0, "haze", false), (.prang, 0, "dusk", false), (.sigiriya, 0, "jungle", false),
        (.lighthouseFort, 0, "lagoon", false), (.pyramids, 0, "desert", false), (.tableMountain, 0, "oceanDay", false),
        (.savanna, 0, "ochre", false), (.minaret, 0, "terracotta", false), (.waterfall, 0, "jungle", false),
        (.waterfall, 1, "haze", false), (.waterfall, 2, "emerald", false), (.statueOfLiberty, 0, "goldenHour", false),
        (.suspensionBridge, 0, "coral", false), (.canyon, 0, "terracotta", false), (.lakeReflection, 0, "alpine", false),
        (.lakeReflection, 1, "emerald", false), (.mayanPyramid, 0, "jungle", false), (.geyser, 0, "haze", false),
        (.balconyRow, 0, "ochre", false), (.palmBeach, 0, "lagoon", false), (.palmBeach, 1, "lagoon", false),
        (.palmBeach, 2, "coral", false), (.machuPicchu, 0, "emerald", false), (.christRedeemer, 0, "jungle", false),
        (.operaHouse, 0, "oceanDay", false), (.monolith, 0, "terracotta", false), (.louvre, 0, "dusk", false),
    ]

    static var entries: [Entry] {
        plan.map { motif, variant, palette, night in
            var spec = ArtworkSpec.preset(motif, palette: palette, variant: variant)
            spec.night = night
            spec.aurora = motif == .hallgrimskirkja
            spec.clouds = night ? 0 : 0.4
            let title = "\(motif.rawValue)\(variant == 0 ? "" : " \(variant)")"
            return Entry(id: "\(motif.rawValue)-\(variant)",
                         design: StampDesign(id: "gallery.\(motif.rawValue).\(variant)", destinationID: motif.rawValue,
                                             title: title, edition: "Series I", artwork: spec,
                                             accessibilityDescription: title))
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 20) {
                ForEach(Self.entries) { entry in
                    VStack(spacing: 6) {
                        PerforatedStampView(design: entry.design)
                        Text(entry.id).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(SQColor.background)
    }

    /// Writes PNG contact sheets (3 × 3 stamps each) to the app's Documents directory.
    @MainActor
    static func exportSheets() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let all = entries
        let reportURL = docs.appendingPathComponent("report.txt")
        try? "".write(to: reportURL, atomically: true, encoding: .utf8)
        func log(_ line: String) {
            guard let handle = try? FileHandle(forWritingTo: reportURL) else { return }
            handle.seekToEndOfFile()
            handle.write(Data((line + "\n").utf8))
            try? handle.close()
        }
        for entry in all {
            log("start \(entry.id)")
            let r = ImageRenderer(content: PerforatedStampView(design: entry.design).frame(width: 200))
            r.scale = 1
            log("\(entry.id): \(r.uiImage == nil ? "FAILED" : "ok")")
        }
        let perSheet = 9
        for (n, start) in stride(from: 0, to: all.count, by: perSheet).enumerated() {
            let slice = Array(all[start..<min(start + perSheet, all.count)])
            let sheet = VStack(spacing: 24) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(alignment: .top, spacing: 24) {
                        ForEach(0..<3, id: \.self) { col in
                            let i = row * 3 + col
                            if i < slice.count {
                                VStack(spacing: 6) {
                                    PerforatedStampView(design: slice[i].design)
                                        .frame(width: 300)
                                    Text(slice[i].id).font(.system(size: 14)).foregroundStyle(.black)
                                }
                            } else {
                                Color.clear.frame(width: 300, height: 400)
                            }
                        }
                    }
                }
            }
            .padding(32)
            .background(Color(red: 0.97, green: 0.95, blue: 0.91))
            .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: sheet)
            renderer.scale = 1
            if let image = renderer.uiImage, let data = image.pngData() {
                try? data.write(to: docs.appendingPathComponent("gallery-\(n + 1).png"))
            }
        }
    }
}
#endif
