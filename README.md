# StampQuest

*Your world, one stamp at a time.*

A native SwiftUI iPhone app (iPad-capable) where you collect illustrated digital postage stamps from places you visit and build a personal travel passport. Local-first: no account, no network required, no tracking.

## Requirements

| Tool | Version used |
|---|---|
| Xcode | 27.0 (Swift 6.4 toolchain) |
| iOS deployment target | 17.0 |
| XcodeGen | 2.46 (only to regenerate the project) |
| SwiftLint | optional (`brew install swiftlint`) |

The app has **no third-party dependencies**.

## Run it

```bash
open StampQuest.xcodeproj
```

Choose the **StampQuest** scheme and an iPhone simulator, then Run. To run on a device, set your team and a unique bundle identifier under *Signing & Capabilities* (the project ships with `app.stampquest.ios` and no team).

### Regenerating the project

`project.yml` is the source of truth for the Xcode project (the generated `StampQuest.xcodeproj` is committed for convenience). After adding or removing files:

```bash
xcodegen generate
```

### Tests

```bash
# Unit tests (Swift Testing): domain rules, persistence, catalog, search, verification, export, rendering
xcodebuild -project StampQuest.xcodeproj -scheme StampQuest \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:StampQuestTests test

# UI tests (XCUITest): end-to-end journeys
xcodebuild -project StampQuest.xcodeproj -scheme StampQuest \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:StampQuestUITests test
```

### Debug launch arguments (DEBUG builds only; ignored in Release)

| Argument | Effect |
|---|---|
| `-uitest-reset` | Erase the on-disk store, photos and preferences before launch |
| `-uitest-skip-onboarding` | Mark onboarding complete |
| `-uitest-seed few\|many\|islandAlmost` | Fill the passport with sample data |
| `-uitest-location <script>` | Script the device location: `denied`, `restricted`, `disabled`, `timeout`, `undetermined-then-allow`, or `lat,lon[,accuracy[,ageSeconds]]` |
| `-uitest-url stampquest://…` | Open a deep link right after launch |
| `-art-gallery` / `-art-gallery-export` | Show every illustration / export contact-sheet PNGs to Documents |

### Regenerating the app icon

```bash
swift Tools/make_icon.swift StampQuest/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Map of the repository

```
project.yml                      XcodeGen definition (targets, settings)
StampQuest/
  App/            Entry point, environment, router, preferences, root views
  Core/DesignSystem/
    Tokens/       Colour, type, spacing, motion tokens
    Shapes/       PerforatedStampShape
    Artwork/      Procedural illustration engine (54 motifs)
    Components/   Stamp views, buttons, cards, status views
  Domain/         Pure rules: catalog models, statistics, verification policy, PassportStore
  Data/           SwiftData schema, persistence, catalog loader, export
  Platform/       Location, photos, haptics
  Features/       Home, Discovery, Passport, StampDetail, StampReveal, Collections,
                  Map, Memories, Trips, Statistics, Settings, Onboarding, Sharing
  Resources/      Catalog JSON, assets, Info.plist
StampQuestTests/  Swift Testing unit tests
StampQuestUITests/  XCUITest journeys
docs/             Architecture, motion, privacy, catalog, handover
Tools/            Icon generator
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the pieces fit together and [`docs/HANDOVER.md`](docs/HANDOVER.md) for status, test results and known limitations.
