# Onboarding audit

## 1. Verdict

NOT READY. This pass was cut short and is a partial audit. Blockers: OB-007 (runtime fault on every pushed screen, cause unknown), OB-008 (one StoreKit pack test fails on the default simulator, 2 issues, not diagnosed), and most of the audit not run (section 8).

## 2. Counts

| severity | found | fixed | open |
|---|---|---|---|
| P0 | 0 | 0 | 0 |
| P1 | 2 | 2 | 0 |
| P2 | 6 | 2 | 4 (OB-007, OB-008 open; OB-010 and OB-011 are decisions) |
| P3 | 3 | 2 | 1 (OB-009) |

Details in BUGS.md. "0 P0" means none found in the parts checked, not that none exist.

## 3. Route graph (read from `OnboardingRoute` and `OnboardingModel`)

```
Welcome (root, step 1)
  -> interests (2) -> firstStamp (3) -> verification (4) -> cover (5) -> passportReady (5, all done)
  -> flag off: finish
  -> flag on:  plus (no strip) -> finish (purchase, or Offer "free passport")
                              -> plusExit (modal exit sheet, no strip) -> finish, or back to plus
Skip: interests -> firstStamp, firstStamp -> verification, verification -> cover, cover -> next like Continue.
Back: every route except plus. passportReady and plus have no Skip.
```

- The route enum is exhaustive; every `switch` over it compiles.
- Progress steps match the mapping in the brief (taken from `OnboardingRoute.progressStep`). I did not re-open the original prompts to confirm.
- Resume: the furthest route reached is stored and the stack is rebuilt on launch. Not run as a kill-and-relaunch scenario.

## 4. Screen matrix

NOT VERIFIED for every cell except where noted. In this pass I did not re-tick the original prompts, shoot the core set, run `performAccessibilityAudit()`, recompute contrast, or run snapshot sets.

| screen | prompt items ticked | states shot | a11y | contrast | tests |
|---|---|---|---|---|---|
| Welcome | not re-done | not re-done | not run | spec tokens fail (OB-010) | in the unit run (section 8) |
| Interests | not re-done | not re-done | not run | not run | in the unit run |
| First stamp | not re-done | not re-done | not run | not run | in the unit run |
| Verification | not re-done | not re-done | not run | not run | unit run; UI tests not rerun since their fixes |
| Cover | not re-done | one shot, light (Evidence) | not run | not run | 7 Cover UI tests passed earlier in this session |
| Passport ready | not re-done | none | not run | not run | UI tests not rerun since their fixes |
| Plus | not audited here | none | not run | not run | snapshots pass on rerun; 2 StoreKit issues (OB-008) |
| Exit sheet | not audited here | none | not run | not run | snapshots pass on rerun; pack StoreKit test fails (OB-008) |

## 5. Scenarios A to N

None run as scenarios. Scenario L (double taps) is covered at model level only by OB-001 and OB-002 tests; no UI-level rapid-tap run.

## 6. Truth audit

| claim | result | notes |
|---|---|---|
| Cover name "kept on this device" | TRUE as of the code | no URLSession, URLRequest, analytics or CloudKit use in the app target (grep); SwiftData store uses `cloudKitDatabase: .none`; no logger prints the name. Becomes false if sync ships |
| Plus perks (four) | NOT TRACED | the Plus flag must stay off until all four exist |
| Exit sheet lines | NOT TRACED | |
| Collected vs Verified | NOT TRACED | |
| Passport ready rows | NOT TRACED | |
| Network calls in onboarding | none found besides StoreKit | static grep only |

## 7. Decisions needed

1. Raw `.font(.system(size:))` ban: the screen prompts specified point sizes scaled with `@ScaledMetric`. The script flags only fixed sizes on copy; glyphs inside fixed badges carry an `audit:fixed-glyph` marker. Recommend keeping this.
2. OB-011: success banner timing with Switch Control (VoiceOver gets 4 s, others 2 s). Recommend a Continue button when VoiceOver or Switch Control is on.
3. OB-010: contrast gaps come from the spec's own token values. Recommend darkening the Welcome light subtitle and the dark tertiary ink in the colour generator.

## 8. NOT VERIFIED

Anything needing a device or sandbox: haptics, CoreMotion tilt, the Metal shader (toolchain missing; gradient fallback in use), real frame rate, VoiceOver and keyboard on hardware, real purchases, other iOS versions, Instruments profiling, cold-start time, Thread and Address Sanitizer runs, SE and Pro Max runs, Increase Contrast, Smart Invert, RTL and pseudo-localization, locale and currency checks, Low Power and Airplane Mode.

Unit suite, iPhone 18 Pro, iOS 27, final rerun: 391 tests in 64 suites, 8 issues including 6 known issues; the 2 others are in `PlusStoreKitTests` (OB-008). The Plus session reports 391 passing on its own simulator; I did not reproduce that. The first run had 390 tests and 36 issues. `Scripts/audit-onboarding.sh` exits 0 on the current tree.

## 9. Files created or changed

Created: `Scripts/audit-onboarding.sh` (all eight checks pass), `.github/workflows/onboarding-audit.yml` (never run on a runner), `StampQuest/Resources/PrivacyInfo.xcprivacy`, `StampQuestTests/OnboardingAuditRegressionTests.swift`, `docs/Onboarding/{AUDIT,BUGS}.md`, `docs/Onboarding/Evidence/`.
Changed: `OnboardingModel.swift` (guards), `WelcomeView.swift`, `VerificationView.swift`, `LocationExplainerSheet.swift` (scaled fonts), `TrialRoute.swift`, `PlusPaywallView.swift`, `CoverView.swift`, `PackStack.swift`, `FreeFeatureCard.swift`, `SheetCloseButton.swift` (markers), `ReadyHeadline.swift`, `SwatchDock.swift` (comments), `docs/ARCHITECTURE.md` (short Onboarding section appended).
