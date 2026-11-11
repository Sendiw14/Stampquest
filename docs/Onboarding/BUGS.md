# Onboarding audit: findings

Status key: fixed (code changed, regression test added), open, decision (needs a product call, not changed).

| id | sev | screen | repro | root cause | fix | regression test | status |
|---|---|---|---|---|---|---|---|
| OB-001 | P1 | Flow | Double-tap a CTA while the next screen is pushing | `OnboardingModel.go(to:)` appended the route without checking `path.last` | guard against the same route twice in a row | `OnboardingAuditRegressionTests.OB001_aDoubleTapOnContinueNavigatesOnce` | fixed, test passes |
| OB-002 | P1 | Flow, Plus, Exit | Double-tap the final CTA, or finish from two paths | `finish()`, `finishFromOffer()`, `finishAfterPurchase()` re-ran: `completedAt` overwritten, `complete` closure called twice, a purchase outcome overwritten by "dismissed" | all three return early once complete | `OnboardingAuditRegressionTests.OB002_finishingTwiceCompletesOnceAndKeepsTheFirstOutcome` | fixed, test passes |
| OB-003 | P2 | App | none | no `PrivacyInfo.xcprivacy`; the app reads `UserDefaults` (required-reason API) | added `StampQuest/Resources/PrivacyInfo.xcprivacy` (no tracking, no collected data, UserDefaults reason CA92.1) | none (manifest; verify in an archive build) | fixed, not verified in an archive |
| OB-004 | P2 | Welcome, Verification | Set text size to Accessibility 3 | wordmark and two text links used a fixed 17 pt font | `@ScaledMetric(relativeTo: .headline)` | static check in `Scripts/audit-onboarding.sh` | fixed, not visually re-checked |
| OB-005 | P3 | Plus | none | `AnyView` in `TrialRoute` | `if/else` inside `Group` | static check | fixed |
| OB-006 | P3 | Cover, Passport ready | none | comments said "gold" outside the Verified component, which trips the gold check | reworded | static check | fixed |
| OB-007 | P2 | all pushed screens | open any screen after Welcome | SwiftUI runtime fault "Invalid frame dimension (negative or non-finite)", once per screen. Reproduced on Interests, First stamp, Verification, Cover, Passport ready, Plus. Not on Welcome. Ruled out by experiment: top bar, swipe-back bridge, the navigation modifiers on the destination, the paper glow. Cause not found | none | none | open |
| OB-008 | P2 | Unit suite | run `StampQuestTests` on iPhone 18 Pro | First run: 30 non-known issues (28 Plus and Exit snapshot, 2 in `PlusStoreKitTests`). Rerun after the Plus session's changes: snapshots pass; `PlusStoreKitTests.thePackLoadsWithTheStoresPriceAndOwnershipFollowsAPurchase` still fails (2 issues, `ownedIDs()` and `model.pack`). The Plus session reports all 391 passing on its private simulator, so the StoreKit test likely depends on shared StoreKit test state. Not diagnosed | none | existing test | open |
| OB-009 | P3 | several | none | files over 200 lines: PlusPaywallView 272, CoverView 259, PlusViewModel 233, WelcomeView 229, OnboardingModel 223, PlusContent 206, FirstStampScreen 200 | none | none | open |
| OB-010 | P2 | Welcome | none | spec tokens: light subtitle over the glow is 3.76:1 (known issue in `WelcomeColorTests`); dark inkTertiary on paper 4.17; slot outline under 3:1; hot star light under 3:1 | none, tokens are the spec's | existing known-issue tests | decision |
| OB-011 | P2 | Plus | VoiceOver on, buy | success banner holds 4 s with VoiceOver (2 s otherwise). Switch Control is not detected | none | none | decision |
