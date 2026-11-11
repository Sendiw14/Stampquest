# Motion specification

Motion in StampQuest evokes paper, ink and the small ritual of collecting. It is purposeful, quick for frequent actions, and never blocks the person. No sound, particles or confetti.

Tokens live in `Core/DesignSystem/Tokens/SQMotion.swift`.

| Moment | Purpose | Duration / curve | Reduced-motion form |
|---|---|---|---|
| **Stamp reveal** (`RevealView`) | Make collecting feel like pressing a real stamp | ≈ 1.4 s total; see timeline below | One 0.25 s crossfade straight to the final state |
| Wishlist toggle | Acknowledge a light action | `quick` 0.18 s ease-out; symbol replace | Same (no movement) |
| Collection state change | Avoid layout jumps | `standard` 0.28 s ease-in-out | 0.12 s fade |
| Progress / counters | Show change after data changed | numeric text transition | Instant |
| Passport filter/sort | Keep your place | `standard` on the grid's id list | Fade |
| Onboarding page change | Direction | 0.28 s slide + fade | Crossfade |
| Map selection | Context | `considered` 0.42 s camera move | Same (system map) |
| Undo banner | Offer recovery | 0.28 s slide/fade, auto-hides at 7 s | Fade |

## Reveal timeline

| t (s) | Phase | What happens |
|---|---|---|
| 0.00 | Recede | Scrim (material + paper tint) fades in over the previous screen (0.22 s) |
| 0.12 | Outline | A dashed perforated outline marks where the stamp will land |
| 0.30 | Stamped | Stamp scales 1.32 → 1.0, rotates −9° → −2°, drops 36 pt, with a gentle spring (`settle`); shadow tightens. **Success haptic fires here** |
| 0.78 | Inked | Postmark presses in (0.28 s) |
| 0.95 | Named | Destination name and location fade up |
| 1.20 | Confirmed | "Added to your passport" (or "· Visit verified"), completed-collection note, next actions |

Rules:
- Presented **only after** the record is saved (`AppEnvironment.collect` returns an error otherwise and nothing animates).
- Interruptible: **tap anywhere** skips to the final state; **Close** is always visible; the next-action buttons appear at the end and are focus-reachable immediately for VoiceOver.
- Reduce Motion (system, or the in-app "Always reduce" setting) **or** VoiceOver running → crossfade only, with an accessibility announcement ("Stamp collected: Paris").
- Haptics are subject to the in-app haptics toggle and are used only for confirmed events.
- The cover transition itself is suppressed (`Transaction.disablesAnimations`) because the reveal choreographs its own entrance.

## Don'ts
- No animation on every state change; no looping or decorative motion.
- No animation before the underlying action has succeeded.
- No motion that cannot be skipped.
