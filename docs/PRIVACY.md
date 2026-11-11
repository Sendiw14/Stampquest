# Privacy & data

## Principles
- No account, no sign-in, no network dependency for any core action.
- No analytics, advertising, attribution or crash-reporting SDKs. No third-party code at all.
- Nothing leaves the device. There is no backend.

## What is stored (on device only)
| Data | Where | Notes |
|---|---|---|
| Stamps, wishlist, trips, memory text | SwiftData store (`Application Support/StampQuest/Passport.store`) | |
| Verification result | In the stamp record | Distance (m, rounded), accuracy (m), radius, policy version, time. **Never coordinates** |
| Memory photos | `Application Support/StampQuest/MemoryPhotos/*.jpg` | Downsampled to ≤2048 px and re-encoded, which strips EXIF/GPS |
| Preferences, recently viewed ids | `UserDefaults` | |

## Location
- Permission: **When In Use** only (`NSLocationWhenInUseUsageDescription`). Never "Always". No background modes.
- Requested **only** after the person taps *Verify my visit* and reads the explanation; onboarding requests nothing.
- One foreground fix per attempt, then discarded. No continuous updates, no history.
- Manual collection works without any permission. Denial, restriction, disabled services, timeout, stale or inaccurate readings, and "too far" are each reported honestly and never shown as success.
- UI copy states that location can be inaccurate or spoofed; verification is a convenience, not proof.

## Photos
`PhotosPicker` runs out-of-process: StampQuest receives only the photos the person selects and requests **no** photo-library permission. (`NSPhotoLibraryUsageDescription` is present only as a safeguard.)

## Sharing & export
- Share images contain only the artwork, public place name and (optionally) the collection date. Notes, photos, captions, trip names and coordinates are never passed to the renderer.
- *Export my data* produces JSON. Journal text, captions and trip notes are **excluded unless the person turns on "Include private notes"**. Photos are never exported.

## Deletion
Settings → *Delete all my data* removes every record and photo file after confirmation. Catalog content is not user data and is unaffected.

## App Store privacy disclosure (to verify at submission)
"Data Not Collected" is accurate for the app as built: no data is transmitted off device. Re-verify if any networking, sync, analytics or purchases are added.

## Release blockers owned by the publisher
- A hosted **privacy policy URL** (set `AppConfiguration.privacyPolicyURL`; App Store Connect requires one).
- A support contact (`AppConfiguration.supportEmail`); the Send-feedback row is hidden until set.
