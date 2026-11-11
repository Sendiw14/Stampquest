# Architecture

StampQuest is a feature-first SwiftUI app with a clear split between **catalog** (read-only content), **user data** (SwiftData), **domain rules** (pure and tested), and **platform services**.

## Layers

```
Views (Features/*)          ── display state, send user intent
   │ reads @Environment(\.passport), calls AppEnvironment actions
AppEnvironment / AppRouter  ── wiring, navigation, reveal presentation
   │
Domain                      ── PassportStore (rules), VerificationService, statistics, queries
   │                           value types: PassportSnapshot, PassportStatistics, CollectionProgress
Data                        ── SwiftData models (versioned), PersistenceController, CatalogLoader, exporter
Platform                    ── CoreLocation provider, PhotoStore (ImageIO), HapticsService
```

Concurrency: Swift 6 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and Approachable Concurrency. Pure types (catalog models, art engine, rules) are explicitly `nonisolated` so they can be used from `Canvas`, `ImageRenderer` and tests. The only `@concurrent` work is image decoding/encoding and the `locationServicesEnabled()` check.

## Two kinds of data

**Catalog** (`Resources/Catalog/*.json`, versioned): countries (derived), destinations, stamp designs, collections. Immutable after load, validated by `CatalogLoader` (bad records are dropped and reported, never crash the app). Replaceable by a future remote catalogue without touching user records.

**User records** (SwiftData, `StampQuestSchemaV1`): `UserStamp`, `WishlistItem`, `MemoryEntry`, `Trip`. They reference catalogue items by stable identifier (`destinationID`, `stampID = "stamp." + destinationID`). Only `titleSnapshot` and `countryCodeSnapshot` are copied so a record can still be shown if the catalogue later drops a destination. A successful verification is stored as a small Codable `VisitVerification` (distance, accuracy, radius, policy version, timestamp). **No coordinates are stored.**

Memory photos live as JPEG files in `Application Support/StampQuest/MemoryPhotos/`; the model holds only file names.

## One source of truth for numbers

Every statistic, progress figure and achievement is computed from a `PassportSnapshot` (an immutable value built from `@Query` results). Nothing keeps its own counter. `PassportProvider` builds a `PassportContext` and publishes it through the environment, so a change on one screen appears on all others in the same render pass.

## Business rules (all in `PassportStore`, all tested)

1. Collecting is **idempotent**: one stamp per destination.
2. Manual collection never implies verification; `verification` is separate state.
3. Verifying an existing stamp **upgrades it in place**; a second verification changes nothing.
4. A wishlist entry is not a stamp; collecting clears it; a collected place cannot be wishlisted.
5. A failed `save()` rolls back and throws `PassportError.saveFailed`; success UI only ever follows a successful save.
6. Deleting a memory never deletes stamps; deleting a trip detaches (never deletes) its stamps and memories.
7. Removal returns a `StampBackup` that powers Undo.
8. Export excludes journal text, captions and trip notes unless explicitly included; photos are never exported.

## Verification flow

`VerificationService`: feature on? → Location Services on? → permission (prompt only if undetermined) → one reading → `VerificationPolicy` (≤60 s old, ≤100 m accuracy, within the destination's own radius) → save. `LocationProviding` is a protocol; tests inject `MockLocationProvider`, UI tests inject `ScriptedLocationProvider`. The real provider is one-shot, foreground-only, When-In-Use.

## Navigation

`AppRouter` owns the selected tab, one `[Route]` stack per tab, and the reveal payload. Routes are a typed `Route` enum resolved by `RouteView`. Deep links: `stampquest://home|passport|discover|map|memories`, `…/destination/<id>`, `…/stamp/<id>`, `…/collection/<id>`.

## Artwork engine

Stamp illustrations are original vector art drawn in code (`Core/DesignSystem/Artwork`): a 100 × 130 art space, a scene composer (sky, sun/moon, stars, aurora, clouds, hills, haze, land/water) and 54 hand-built motifs. Catalog entries choose a motif, a named palette and a few parameters. Output is deterministic (seeded by stamp id), resolution-independent, tiny, and renders identically in grids, details, exports and tests. If a catalog entry supplies `assetName` and that image exists in the asset catalog, painted artwork takes precedence, so artwork can be upgraded entry by entry without code changes.

## Schema evolution

`StampQuestSchemaV1` is the first shipped schema; `StampQuestMigrationPlan` has no stages yet. To change the schema add `StampQuestSchemaV2` (copy models, never edit V1), append it to `schemas`, add a stage. If a store fails to open, the app shows a recovery screen: **Retry**, or **Back up and start new**, which *moves* the store to `Application Support/StampQuest/Backups/<timestamp>/`. Data is never deleted automatically.

## Onboarding

Onboarding code is in `StampQuest/Features/Onboarding/<Screen>`; shared components and tokens it imports are in `Core/DesignSystem/Onboarding`. Services (purchases, subscriptions, reminders, location) are in `Platform/` and `Domain/`, not under Onboarding. Static checks: `Scripts/audit-onboarding.sh`. Audit findings: `docs/Onboarding/AUDIT.md` and `BUGS.md`. Add a screen: add a case to `OnboardingRoute`, a view in `OnboardingRouteView`, and a row in `OnboardingModelTests`. Add a string: `Resources/Localizable.xcstrings`.
