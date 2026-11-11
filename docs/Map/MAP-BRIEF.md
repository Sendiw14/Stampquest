# StampQuest: Map tab (M3 Cover Frame) brief

You are building ONE screen of StampQuest, an iOS app: the Map tab, in the "M3 Cover Frame" design, plus the List screen, the Marker guide and the Location explainer that it opens. Build only these and what they directly need. Do not redesign other screens. Do not change the Onboarding, Home, Passport or Discover work that already exists, except to make shared components reusable.

The four-panel mockup (M3 Cover Frame: light, dark, verified place light, zoomed out light) is at `/private/tmp/claude-501/-Users-sendiwkithnada-Documents-StampQuest/32c55fc9-2763-4877-8c23-bc0bcb5c6077/images/4.webp` (read it with the Read tool). The other mockups and the motion video named in the original brief were not provided; this written spec is the source of truth. Where this prompt and the master product rules disagree on product rules, the master rules win. Where they disagree on layout, this prompt wins.

The shared sheets (marker guide, list, location explainer, states) were drawn for a different full-bleed Map layout. Their content, copy and components are right, but where they show the map behind them, use the M3 frame. Section 14.6 lists what was not drawn inside the M3 frame.

## 0. How to work

0.1 Read the existing codebase first. Reuse what exists: the design tokens, PerforatedStampView, StampCollectionStateBadge, the gold verified seal, DestinationRow, DestinationSearchField, CategoryChip, EmptyStateView, InlineErrorView, OfflineBanner, ConfirmationDialog, PrimaryActionButton, IconActionButton, the toast, the glass tab bar, the Search screen from Discover, the repositories. Do not duplicate them. If a component is missing, create it with the name from the master prompt.
0.2 Work in this order: data and derived state, then the frame and header, then the map surface and markers, then chips and controls, then the preview card, then selection and camera, then clusters, then List, then Marker guide and Location, then empty and error states, then motion, then accessibility, then tests.
0.3 iOS 17 minimum. SwiftUI, SwiftData, @Observable, MapKit, CoreLocation. No third-party map or UI packages. No custom tile server and no custom map overlay that tints or repaints the map.
0.4 The mockups are HTML drawings, not verified on a device. Treat every number as a strong starting point, not gospel. If a value breaks at a real size or in Dynamic Type, fix it and tell me what you changed.
0.5 The map in the mockups is a stylised drawing of a muted map (real coastlines and borders, cream water and land). MapKit cannot be recolored to cream. Use the system muted style (section 5.1) and accept that the map will look different. Do not tint the map to imitate the drawing. Everything above the map (frame, chips, buttons, card, markers) must match this prompt.
0.6 Do not ship any artwork from the mockups. Stamp art comes from the app's own catalog assets. Only eight places have art in the mockups. For any place without art, use the designed placeholder (dot, pin or dashed slot, section 5.3) and list the missing art in your report.
0.7 Finish with a report: what was built, what differs from this prompt and why, what is not verified on a device, and anything you could not do.

## 1. What this screen is

The Map is where the user sees their travels and the places still to collect on a map. It answers: where have I been, where is the next stamp, and what is around the place I am looking at. It is a terracotta cover with the title "Map" and a single line of counts, a rounded window that holds the map, layer chips and two round buttons inside the window, and a preview card that rises over the bottom of the window when a place is selected. The map is never the only way in: a List button is always visible, and every place is reachable from the list and from search.

Tabs, for reference: Home, Passport, Discover, Map, Memories. Map is the fourth tab (index 3) and is selected here.

Product rules this screen must enforce (from the master prompt):
- Collecting by hand is free, works offline and never needs location (rules 1, 2, 14). The Map shows catalog destinations and the user's own collection state. It never needs location to browse, select or collect.
- Location is used only when the user taps Locate (G3, H). No background location, no Always authorization, no persistent trail, no location history stored or uploaded, no continuous tracking. Verification of a visit is optional, lives in the verify flow, and is not started from this screen. Manual collection is never shown as verified (rule 15).
- A wishlist item is never counted as collected (rule 3). Saved, collected and verified are three different states with three different markers.
- Gold is used ONLY for a verified visit: the gold seal on a verified marker, in the Verified chip, in the Verified card state and in the list. Nothing else on this screen is gold.
- No invented popularity, rankings, "trending", "popular near you", streaks, timers, urgency or fake scarcity (D1). No distance ranking and no "nearest" label. Nothing is sorted by popularity.
- Every count is derived from canonical records (rule 12). No separately stored counters.
- A change made anywhere else (collect, remove, wishlist, verify) shows up here without a manual refresh (rule 18).
- Collecting the same place twice never creates a duplicate and repeated taps are idempotent (rules 4, 5). Wishlist saves are idempotent too.
- Every tappable element leads to a working destination (section 9). Nothing is a dead end.
- A success animation only happens after the underlying action succeeds (rule 16). Destructive actions have a confirmation or an Undo (rule 19).
- Search works offline against bundled or cached content (D2). Plus never gates browsing, searching, selecting or collecting by hand.
- A loading, map or location error never blocks browsing the list (G2, G4).

## 2. Design tokens

Reuse the existing tokens. Values used in the mockups, for checking:

Light / Dark
- Page background: #F6F1E7 / #1C1B19
- Card: #FBF7EE / #2B2927
- Card line: rgba(70,42,20,.18) / rgba(246,240,229,.16)
- Ink (primary text): #211E1A / #F6F0E5
- Secondary text: #5F5A51 / #BDB6A8
- Accent (buttons, selected states): #A25A38, text on it #FFF9F1 / #DB8D66, text on it #221A14
- Accent for small text, links and marker outlines: #8A4526 / #F0A982
- Accent tint (selected fill, halos): rgba(162,90,56,.10) / rgba(219,141,102,.17). The marker halo uses rgba(162,90,56,.17) / rgba(240,169,130,.22).
- Quiet control fill: rgba(33,30,26,.07) / rgba(246,240,229,.11)
- Cover (the screen background behind the map window), light: terracotta gradient #A55B3A, #97502F, #82442A. Dark: #262321, #1F1D1B, #1B1A18.
- Gold: the existing verified-seal gold, only for verified.
- Cluster marker: ink #211E1A with a #FBF7EE ring in light, cream #F6F0E5 with a #2B2927 ring in dark.

Glass (system material plus tint, as used by the Discover ticket and tab bar):
- Preview card (glass ticket): tint 0.86 cream light / 0.90 charcoal dark, 22 pt blur, 1 pt card line, an inner top highlight, soft drop shadow.
- Chips, round buttons: tint 0.58 cream light / 0.56 charcoal dark, 26 pt blur and saturation boost, 1 pt light border.
- Tab bar on this screen: tint 0.90 in light (raised from the usual 0.58 so the small labels reach 4.5:1 over the terracotta), 0.55 in dark. Active tab label uses the small-accent text color.

Type (SF Pro; the mockups used Inter as a stand-in, so SF Pro will be slightly narrower):
- Screen title "Map": 38 / 800, tracking -0.04em, cream
- Counts line: 15 / 500, 98% cream
- Preview card name: 22 / 800, tracking -0.03em. Subline 13.5 / 500 secondary. State line 12.5 / 500 (650 for the label). Buttons 14.5 / 700
- Chips: 13.5 / 650 (700 when selected); the count inside a chip is 650 at 80% opacity
- Marker label: 11.5 / 650 with a map-colored halo (four soft text shadows) so it reads on any map
- Cluster count: 15 / 800 (17 / 800 for 13 or more)
- List: title 36 / 800, row name 16.5 / 650, row sub 12.5 / 500, region header 13 / 700 tracking 0.02em
Use Dynamic Type text styles scaled from these, never fixed sizes.

## 3. Data and derived state

3.1 Source: catalog Destination records with coordinates, joined to the user's UserStamp records (collected, with a verified flag from the visit record), wishlist entries, and recent searches. Build one @Observable MapViewModel that exposes:
- places: catalog destinations that have valid coordinates. A destination without coordinates never appears on the map but still appears in the list.
- state(for destination): verified, collected, saved or available. Precedence: verified over collected over saved over available. A collected place that is also wishlisted counts as collected, never saved.
- counts: collectedCount, verifiedCount, savedCount, all derived. collected = destinations with a UserStamp (verified ones included). verified = UserStamps with a verified visit. saved = wishlisted destinations that are not collected. These are totals across the whole catalog, not just what is in view.
- layer: all, collected, verified, saved (section 6.1). visiblePlaces = places filtered by the layer. The map and the list use the same visiblePlaces and the same layer.
- selectedID: the selected destination, or nil.
- camera: the map camera, owned by the view model so selection, search and Locate can move it.
3.2 Counts line: "[C] collected · [V] verified · [S] saved". Use the real numbers and StringCatalog plurals for each part. If C, V and S are all 0 the line reads "Nothing collected yet". The chips show the same three numbers.
3.3 Layer rules:
- All: every place.
- Collected: states collected and verified.
- Verified: state verified only.
- Saved: state saved only (wishlisted and not collected).
- Planned: only if a Trips or Planned feature already exists in the codebase, add it as a fifth chip, and let the chip row scroll horizontally with a trailing fade. If it does not exist, do not build it.
- Switching layer keeps the selection if the selected place is still in the new layer. If it is not, clear the selection and dismiss the card.
- The layer is shared by the map and the list during a session and is not persisted. The Map always opens on All.
3.4 Selection: tapping a marker selects it. Tapping empty map, tapping the selected marker again, or changing to a layer that hides it clears the selection. Selection is not persisted. If the selected place is collected, saved or removed elsewhere, the card updates in place.
3.5 Loading: the catalog is bundled, so there is no spinner. Show the cover, header and window immediately; if places are not ready, show the window with the map and no markers, then add the markers once. Never show "Nothing collected yet" because data has not loaded.
3.6 Search: reuse the Discover Search screen and index (D2). On the Map, choosing a result closes Search and moves the camera to that place and selects it (section 9). If the active layer hides the place, switch the layer to All first.
3.7 Not persisted: layer, selection, camera. A place's state always comes from canonical records.

## 4. Frame and header

Canvas is 402 by 874 pt in the mockups (iPhone 16 Pro class). Scale proportionally to the screen width; measure from the safe area.

4.1 Cover: the whole screen is the cover color (terracotta gradient light, charcoal dark), running behind the status bar. A faint warm glow in the cover is fine. The bottom is not scalloped here. Status bar text is white while the cover is visible, and switches to dark only while the List is fully shown.
4.2 Title "Map" at x 24, top y 64 (safe area top plus 5). Counts line at x 24, y 112, width at most 260 pt. At large Dynamic Type sizes the counts line may wrap to two lines and the window moves down by the extra height.
4.3 Header buttons: two glass circles, 40 pt, at x 290 (Search) and x 338 (List), top y 66, so the last one ends 24 pt from the right edge. Icons are cream: a 19 pt search icon, a 19 pt list icon. Hit areas at least 44 pt. Search opens the Search screen (section 9). List opens the List screen (section 8.3).
4.4 Map window: x 12, y 146, 378 by 626 pt, continuous corner radius 32, clipping its content. A 2 pt border over the map: rgba(255,249,241,.92) in light, rgba(246,240,229,.20) in dark. A soft shadow below: 0 26 36 -16 rgba(40,12,0,.62) light, rgba(0,0,0,.7) dark. The window's bottom edge is 12 pt above the tab bar's top edge. On other screen sizes keep the 12 pt side margins and the 12 pt gap, and let the height flex.
4.5 Tab bar: the existing glass tab bar, 370 by 66, radius 33, x 16, y 784, with Map selected.

## 5. Map surface

5.1 Style: MapKit standard, flat, muted emphasis, points of interest excluded, traffic off (MKStandardMapConfiguration with elevationStyle .flat and emphasisStyle .muted, pointOfInterestFilter .excludingAll). Hide the compass and the scale. Keep the map north-up (no rotation, no pitch). Set a sensible zoom range so the user cannot zoom into empty ocean or past street level for a catalog place. Light and dark follow the system.
5.2 Implementation note: as far as I know, SwiftUI's Map has no annotation clustering. The design needs clusters. Prefer wrapping MKMapView in a UIViewRepresentable with annotation views for markers and MKClusterAnnotation for clusters (clusteringIdentifier on the marker annotation view). If you stay in pure SwiftUI Map, check the current SDK first; if there is no clustering, implement zoom-based decluttering instead and tell me. Either way markers must stay a constant size as the map zooms, as in a real map.
5.3 Markers (all drawn in SwiftUI or Core Graphics from the tokens, centered on the coordinate, hit area at least 44 pt):
- Available (not in the passport, not saved): a ring dot, 17 pt, card-colored fill, 2.4 pt small-accent border, with a small accent dot in the center (30% of the diameter). Selected: 24 pt, 2.8 pt border, plus a 50 pt halo (accent tint fill, 1.6 pt accent border) and the name label.
- Saved (wishlist): a 30 pt circle, card-colored fill, 1.4 pt line, a filled small-accent bookmark (17 pt). Selected: 36 pt with a bookmark of 20 pt, a halo 14 pt larger than the circle, and the name label.
- Collected: the place's stamp art, 33 pt wide (3:4 portrait ratio, so about 44 pt tall), rotated -2 degrees, with the stamp's layered shadow, and a 17 pt accent check badge on its bottom-right corner (badge center 4 pt inside the stamp's right and bottom edges) with a 1.5 pt card-colored ring. The name label sits 4 pt under the stamp. Selected: 40 pt wide, no rotation, drawn above neighbors, with a rounded plate behind it (9 pt radius, 7 pt larger on every side, accent tint fill, 1.6 pt accent border).
- Verified: the same as collected, but the badge is the 26 pt gold seal instead of the check, centered near the same corner.
- A place with no art uses a dashed placeholder in the same slot (1.6 pt dashed outline, pin icon), never a blank space. Collected places without art fall back to the accent-check ring dot (a 17 pt dot with the check).
- Labels: shown for the selected place, and for collected and verified places. Never for available or saved places unless selected. Hide a label if it would collide with another marker.
- Stacking order, back to front: available, saved, collected, verified, selected. Within a group, markers further up the screen are behind.
5.4 Clusters: when markers would overlap, MapKit groups them. A cluster is a circle, 34 pt for fewer than 5 places, 40 pt for 5 to 12, 46 pt for 13 or more, in the cluster color, with a 2.5 pt ring, a translucent ring 4 pt outside it, and the count centered. If at least one place in the cluster is collected or verified, a 19 pt accent check badge sits on its top-right (badge center 3 pt inside the circle's top and right). Gold never appears on a cluster. Tapping a cluster zooms the camera to fit its members (0.5 s), it never selects. A single place that is not clustered shows its normal marker.
5.5 Camera and the free band: the window has a free band between the chips and the preview card, from 66 pt below the window's top to 148 pt above its bottom (screen y 212 to 624 in the mockup). Markers are kept inside this band, 14 pt in from the window's sides, so nothing sits under a chip or the card. Use the map's layout margins or edge padding for that. When a place is selected, ease the camera so the place is at the center of the free band (the mockup puts the selected place at about x 196, y 417), keeping the current zoom unless the map is zoomed out past a regional level, in which case zoom in to a regional level. The ease takes about 0.35 s.
5.6 Initial camera: the mockup opens on the Mediterranean (centered near 13 E, 38.6 N, about 39 degrees of longitude across the window) because the sample catalog is densest there. This is an interpretation, not a rule. Real behavior: if the user has collected places, fit them (with padding, and a minimum regional zoom); otherwise fit the catalog's densest region; never use the user's location unless Locate was tapped. The zoomed-out view in the mockup is about 4.6 times wider (about 177 degrees of longitude).
5.7 Reduce Transparency, Increase Contrast, Dynamic Type: the map itself is not affected; markers and labels keep their sizes (labels may wrap to two lines).

## 6. Controls inside the window

6.1 Layer chips: a single row at x 24, y 158 (12 pt inside the window's left and top), 36 pt tall, 8 pt gaps, fully rounded. Order and labels: All, Collected [C], Verified [V], Saved [S]. Width is content plus 11 pt padding each side (the mockup measured 44, 101, 109, 72 pt, so the row ends at x 374, 16 pt inside the window's right edge). Unselected: glass pill, ink label 13.5 / 650, count at 80% opacity. Selected: accent fill, accent text color, 13.5 / 700, a soft accent shadow and a faint inner top highlight. Verified has a 14 pt gold seal before its label, in both states. Tapping a chip switches the layer (section 3.3). Exactly one chip is selected. If the row cannot fit (large text), it scrolls horizontally with a trailing fade, and the selected chip scrolls into view.
6.2 Side stack: two glass circles, 44 pt, at x 334 (12 pt inside the window's right edge), y 208 and y 262.
- Locate: an outline arrow icon. While the user's position is shown, the circle is accent filled with a filled arrow in the accent text color. Tap behavior is section 8.4.
- Marker guide: an "i" icon. Opens the Marker guide (section 8.2).
6.3 Markers must never sit under the chips or the side stack (the free band takes care of this). The side stack and chips are above the map and do not move when the map moves.

## 7. Preview card

7.1 One glass ticket, 354 by 140, radius 30, x 24 (12 pt inside the window), bottom edge 12 pt above the window's bottom edge (top y 620 in the mockup). It appears only while a place is selected. Contents, with offsets from the card's left and top:
- Stamp: the place's stamp art, 52 pt wide, rotated -2 degrees, centered at (+49, +52). No art: a 46 by 62 dashed placeholder at (+24, +18) with a pin icon.
- Name at (+98, +16), 22 / 800, one line. Below it at +44: "[Country] · [Category]", 13.5 / 500 secondary.
- State line at (+98, +66): see 7.2.
- Buttons at +94: a primary or secondary button 178 by 38 at +98 (radius 19), and a 38 pt round bookmark button at +286 when it applies.
- A chevron at (+314, +20), 18 pt, secondary. The whole card except the two buttons opens Destination detail.
7.2 States (derived from canonical records, section 3.1):
- Available: state line "Not in your passport yet" (secondary). Primary "Collect stamp" with a plus icon. Round outlined bookmark button (quiet fill, 1 pt line, ink icon).
- Saved: state line with a filled accent bookmark and "On your wishlist" (accent, 650). Primary "Collect stamp". Round bookmark button filled (accent icon on the accent tint, with an accent border).
- Collected: state line with an accent check and "In your passport" (accent, 650). Secondary "View stamp" with a chevron (quiet fill, 1 pt line, ink text). No bookmark button.
- Verified: state line with a 17 pt gold seal and "Verified visit" (ink, 650). Secondary "View in passport" with a chevron. No bookmark button.
7.3 Actions:
- Collect stamp starts the existing collect flow (E2) for that destination. It never collects instantly from the card and it never animates a success before the record is saved. The Map does not offer verification; verification belongs to the verify flow.
- Bookmark toggles the wishlist (section 10). The marker, the state line, the round button, the Saved count on the chip and the counts line all update immediately.
- View stamp and View in passport open that stamp in Passport (Stamp detail).
- The card body, name and chevron open Destination detail (D4).
7.4 Dismiss: tap empty map, change to a layer that hides the place, or start Search. Swiping the card down also dismisses it. Dismissing never changes data.
7.5 Large Dynamic Type: the card grows in height, the buttons stack vertically and the round bookmark button moves beside the primary button's row. The card never covers the chips or the side stack; if it would, the window's map area scrolls the selected place into the remaining space.

## 8. Screens opened from the Map

8.1 Search: the existing Discover Search screen (Discover K1 sections 7 and 8), presented over the Map with the keyboard up. The tab bar is hidden while it is open. Cancel returns to the Map exactly as it was.

8.2 Marker guide (opened by the "i" button): a bottom sheet, 36 pt top corners, 36 by 5 grabber, top edge at y 110, black scrim at 44%. Title "Map markers" (24 / 800) at x 24, y 140. "Done" (16 / 650, accent text) right-aligned to x 378, y 146. Five rows from y 200, each with a real sample marker centered at x 54, a title at x 100 (17 / 650) and a subline at x 100 (13.5 / 400 secondary, width 276), dividers 1 pt card line at x 100, 280 wide, 6 pt above each row after the first. Row pitch 72 pt, 90 pt for the two rows with a two-line subline:
- "Place to collect" / "Not in your passport yet."
- "On your wishlist" / "Saved to collect later."
- "In your passport" / "Collected by hand or on a visit."
- "Verified visit" / "Collected and verified on location. Gold appears only here."
- "Several places" / "Tap to zoom in. A check means one is already in your passport."
Footer at 14 pt below the last row, x 24, width 350, 13.5 / 400 secondary: "Your own position shows on the map only after you tap Locate."
The sample markers use the same marker views as the map, so they cannot drift. Done and a swipe down close it.

8.3 List (opened by the List button, or by "Open list" in error states): the same places as a list, in a screen that pushes in from the right over the cover and window (the tab bar stays in place, with Map still selected).
- A "Map" back pill (92 by 36, radius 19, quiet fill, 1 pt line, map icon plus "Map", 14 / 650) at x 20, y 62. It returns to the map.
- Title "Places" (36 / 800, tracking -0.04em) at x 24, y 104.
- A search field, 370 by 46, radius 23, quiet fill with a 1 pt line, at x 16, y 158, placeholder "Search places or landmarks" (16 / 500 secondary). It is a DestinationSearchField that filters this list by the Discover search index (offline), with a Cancel and a clear button as in Discover.
- Layer chips at y 214, 36 pt tall, selected is accent filled: "All", "Collected [C]", "Verified [V]", "Saved [S]". They are the same layer as the map's chips and stay in sync.
- Sections by region, in catalog region order, places A to Z inside a region. Region header at y 270: the region name at x 24 (13 / 700, tracking 0.02em, secondary) and "[N] places" right-aligned to x 378 (13 / 600 secondary).
- Rows (DestinationRow) from y 296, 64 pt pitch, 1 pt dividers from x 82, 300 wide, none above the first row of a section: a 38 pt stamp at x 46 (a 34 by 44 dashed pin placeholder when there is no art), name at x 82 (16.5 / 650), "[Country] · [Category]" below it (12.5 / 500 secondary). Right side, right-aligned to x 382: Verified (17 pt gold seal and "Verified", ink, 12 / 650), In passport (12 pt accent check and "In passport", accent), Saved (accent filled bookmark and "Saved", accent), otherwise a 14 pt chevron at x 362. Tapping a row opens Destination detail.
- A page-colored fade sits behind the tab bar. The status bar text is dark here.
- Empty result (a layer or search with no match): EmptyStateView with the copy in section 11.
- Selecting a row never changes the map; only the back pill and Destination detail's own "Show on map" (if it exists) move the camera.

8.4 Locate: tapping Locate does the following, and nothing else:
- If location permission has not been asked: show the Location explainer (below). It is never shown automatically.
- If permission is When In Use or better: request one location fix (CLLocationManager.requestLocation, one shot). When it arrives, ease the camera to it at a moderate local zoom (start with about 25 km across), show the user's position (the system dot), and set the Locate button to its filled state. Do not use a follow mode and do not start continuous updates. The position is shown only while the button is on. It turns off when the user taps Locate again, leaves the Map tab, or the app goes to the background. Nothing is stored, logged or uploaded. No "near you" ranking, labels or lists.
- If permission is denied or restricted: show the Location-off banner (section 11.3).
Location explainer: a bottom sheet (medium detent), 36 pt top corners, top edge at y 330, scrim at 46%. A 64 pt circle (accent tint) with a filled arrow icon (30 pt, small-accent color), centered horizontally, top at y 372. Title "Use your location?" (26 / 800, centered) at y 450. Three rows from y 506, 46 pt apart: a 28 pt accent icon at x 34 and text at x 78 (15.5 / 500 ink): pin icon "Only when you locate or verify a visit", pin-off icon "Never tracked in the background", map icon "Every place stays browsable without it". Primary "Continue" (354 by 56, accent) at y 672 asks for When In Use permission (never Always). "Not now" (16.5 / 650, secondary, centered) at y 746 dismisses the sheet and changes nothing. The explainer is shown once per install unless the user later taps Locate again and permission is still undetermined.

## 9. Destinations for everything tappable

Nothing may be a dead end.
- Marker (a place): selects it, moves the camera, shows the card (section 7). Marker (cluster): zooms in (5.4).
- Card body, name, chevron: Destination detail (D4). Collect stamp: the collect flow (E2). Bookmark: wishlist toggle. View stamp and View in passport: Stamp detail in Passport.
- Layer chips: switch layer. Locate: section 8.4. "i": the Marker guide. Search circle: Search. List circle: the List.
- Search results opened from the Map: close Search, show the place (the camera moves and the place is selected). If a result is a collection, open Collection detail (F2) or the Results list scoped to it, as in Discover.
- List rows: Destination detail. Back pill: the map. "Open list" in the error state: the List. "Show all places" in the empty-layer state: switches to All.
- Banner "Settings" button: opens the app's page in system Settings (UIApplication.openSettingsURLString).
- Destination detail (D4) and the collect flow (E2, E3): reuse if they exist. If they do not, build only the minimal entry points. Do not build a second collect flow.

## 10. Wishlist, undo and consistency

10.1 Saving: tapping the bookmark on the card saves the place to the wishlist (a WishlistEntry with the destination ID and a saved date). Saving twice does nothing. The marker changes to the saved pin, the Saved chip count and the counts line go up, and a toast appears: "Saved to wishlist" with an "Undo" action, 6 seconds. Undo removes the entry.
10.2 Unsaving: tapping a filled bookmark removes the entry and shows "Removed from wishlist" with "Undo" for 6 seconds. Undo restores it with its original saved date.
10.3 Toast: the existing toast, 354 by 52, radius 26, at x 24, y 556 (12 pt above the card's top edge, over the map). Light mode a #2B2927 pill with #F6F0E5 text (15 / 600) and an accent "Undo" (#F0A982, 15 / 700) right-aligned. Dark mode: a #F6F0E5 pill with #211E1A text and #8A4526 "Undo". Only one toast at a time. If no card is showing, the toast sits 12 pt above the window's bottom edge.
10.4 Collecting a place elsewhere (collect, remove, verify) updates the marker, the card, the chips, the counts line, the list rows and the search labels immediately, without a refresh.

## 11. Empty, first-run and error states

11.1 First run (nothing collected, nothing saved): counts line "Nothing collected yet", chips show 0 for Collected, Verified and Saved, all catalog places are shown as available markers. Everything still works.
11.2 Empty layer (the chosen layer has no places): the map shows no markers, and a glass card, 354 wide and 204 tall, sits 12 pt above the window's bottom edge: a 48 pt dashed circle with a pin icon (accent) centered at +20, a title (20 / 800, centered) at +80, a body (14 / 400 secondary, centered, width 302) at +110, and a 162 by 40 primary "Show all places" at +158. Copy by layer:
- Verified: "No verified visits yet" / "Verify a visit from a place’s page and it appears here."
- Collected: "Nothing collected yet" / "Collect a place and it appears here."
- Saved: "Nothing saved yet" / "Tap the bookmark on a place to save it for later."
The chips stay visible and usable. Only the Verified copy was drawn; the Collected and Saved copy is mine.
11.3 Location off: a glass banner, 354 wide and 92 tall, inside the window at x 24, y 206 (below the chips), appears when Locate is tapped and permission is denied or restricted. A 40 pt accent-tint circle with a pin-off icon at +16, +16. Title "Location is off" (16.5 / 650) at +70, +16. Body "Turn it on in Settings to use Locate. Everything else still works." (13.5 / 400 secondary) at +70, +40, width 264. A "Settings" chip (76 by 28, accent tint fill, accent border, 12.5 / 650) at +266, +12, so it clears the body text. While the banner shows, the side stack moves down to y 310. The banner stays until dismissed by tapping the map or after the user returns from Settings with permission granted. It never blocks the map or list.
11.4 Map unavailable (not drawn in M3, specified from the shared state): if the map cannot load, replace the map inside the window with the page background and a card (370 by 150, radius 24) with a 40 pt warning icon, title "The map can’t load right now" (17 / 650), body "You can still search and browse every place in the list below." (13.5 / 400 secondary), a primary "Try again" (120 by 38) and a secondary "Open list" (150 by 38, with the list icon). Under the card show the A to Z list of all places (the same rows as 8.3). Hide the chips and the side stack while it is shown. MapKit does not report tile failures to SwiftUI. If you wrap MKMapView, mapViewDidFailLoadingMap is the signal. If you cannot detect failure reliably, do not fake it: leave this state out and tell me.
11.5 Offline: browsing, selecting, saving and collecting work offline. MapKit shows cached tiles where it has them. Do not show an offline warning here unless the tiles fail (11.4).
11.6 Missing artwork: show the designed placeholder (5.3) and keep the label. Never show a blank hole or a broken-image icon.
11.7 Everything collected, nothing available: the map shows only collected and verified markers (the "All" layer equals the "Collected" layer). Nothing else changes.

## 12. Accessibility and platform

12.1 Dynamic Type through the accessibility sizes: the counts line wraps, the chip row scrolls horizontally, the card grows (7.5), the list rows wrap. Header buttons keep their 44 pt hit areas.
12.2 VoiceOver:
- The map container is one element labeled "Map, [N] places", hint "Use the List button for a list of places". Markers are exposed as buttons in a sensible order (the selected place first, then collected, then the rest by name) so VoiceOver never needs to explore the map by touch.
- Marker: "Rome, Italy. History. Not in your passport. Button." Saved: "Rome, Italy. On your wishlist." Collected: "Paris, France. In your passport." Verified: "Paris, France. Verified visit."
- Cluster: "6 places. One is in your passport. Double tap to zoom in."
- Chips: "All", "Collected, 3 places, selected" and so on with the selected trait. Locate: "Locate me", with value "On" while shown. Info: "Marker guide". Search: "Search". List: "List of places".
- Card: one grouped element "Rome, Italy, History. Not in your passport yet." with actions Collect stamp, Save to wishlist (or Remove from wishlist), Open details. Announce "Selected Rome" when selection changes by tap, and the layer name and count when the layer changes.
- Title and region headers are headings.
12.3 Reduce Motion: no marker pop-in, no stagger, no card spring, no list slide. Use cross-fades only. Camera moves become instant or a quick fade-and-jump. The system sheets and keyboard still use the system motion.
12.4 Reduce Transparency and Increase Contrast: replace every glass fill (chips, round buttons, card, tab bar, banner) with the solid card color plus a card line, and strengthen the chip and marker outlines.
12.5 Contrast: all text and states meet WCAG AA in light and dark. The mockups were measured over a drawn map (lowest text ratio 4.5:1 on the glass chips, the card and the tab bar). MapKit's real colors differ, so re-check on device in light, dark, and over dense areas. If a chip or label fails, raise its glass tint until it passes. Marker labels use a halo so they read on any map.
12.6 Touch targets are at least 44 by 44 pt everywhere, including the 17 pt dots, the 36 pt chips and the 38 pt card buttons. The visible size stays as drawn.
12.7 Light and dark are both required. Dark uses the dark tokens above and a charcoal cover; stamps keep their colors.
12.8 Haptics: a light selection haptic on layer change and marker selection, a light impact on bookmark, only if the user has haptics on. No success haptic here (the collect reveal belongs to the collect flow). No haptic on Locate.
12.9 All strings in the StringCatalog. No hard-coded user-facing English.
12.10 Privacy: Info.plist contains only NSLocationWhenInUseUsageDescription for this feature, with clear copy ("Used only when you tap Locate or verify a visit."). No Always key, no location background mode.

## 13. Motion (matches the preview video)

Use spring-based, interruptible animations. Nothing loops. Nothing plays on a timer. Reduce Motion replaces all of this with simple fades.
13.1 First appearance in a session (not on every tab switch): the title rises 12 pt and fades in over 0.55 s. The header buttons fade in from 8 pt above. The map window rises 44 pt from 96.5% scale to full over about 0.75 s with an ease-out. Markers pop in west to east, about 38 ms apart, each from 50% scale with a small overshoot over 0.5 s (for more than 30 visible markers, fade them in together instead). The chips and the side stack fade in from 8 pt below. The tab bar rises 30 pt.
13.2 Select: the camera eases to the free-band center (0.35 s). The marker swaps to its selected form with a spring (from 86% scale). The card rises 64 pt and fades in over 0.45 s with an ease-out.
13.3 Save: the bookmark, the state line and the marker cross-fade over about 0.16 s, the marker pops slightly, the Saved count and the counts line cross-fade, and the toast rises 22 pt and fades in. The toast leaves after its time.
13.4 Layer change: markers that leave cross-fade out and markers that join cross-fade in over 0.16 s while the chip fill cross-fades. A card for a place that is not in the new layer slides down 36 pt and fades out over 0.28 s. A card for a place that is still there stays.
13.5 Zoom out and clusters: the camera is a normal MapKit zoom. The video fades single markers out in the first moments and the clusters in at the end of the move; this is an illustration, MapKit's clustering decides the real behavior. A tap on a cluster zooms in the same way.
13.6 Locate and sheets: sheets rise with the scrim fading to 44 to 46%, over about 0.6 s, and lower over 0.55 s.
13.7 List: pushes in from the right over 0.6 s (ease in-out) with the tab bar fixed; the status bar text switches from white to dark around the midpoint. Back reverses it.
13.8 A successful animation only follows a successful action. Collect from the card hands off to the collect flow, which owns the reveal.

## 14. Tests, acceptance and disclosures

14.1 Unit tests (repository and view model):
- state(for:) precedence: verified over collected over saved over available. A collected place that is wishlisted is collected. Manual collection never yields verified.
- The three counts and the counts line derive from records: collect, remove, wishlist, un-wishlist, verify. A collected place leaves the Saved count.
- visiblePlaces for each layer. The map and the list use the same set.
- Selection: kept when the place is in the new layer, cleared when it is not; cleared on tap-empty; updates in place when the place's state changes.
- Wishlist save is idempotent. Unsave then Undo restores the original saved date.
- A duplicate collect from the card creates no second record.
- Initial camera choice (collected places, densest region, never the user's location). The free-band centering math.
- Locate: no location request is made without a tap; one-shot only; the position is not stored; the state turns off when leaving the tab and when the app backgrounds.
- Places without coordinates are excluded from the map and included in the list.
14.2 UI tests: every tappable element reaches its destination (section 9); chips switch layers and counts match; selecting a marker shows the right card for each state; saving shows the toast and Undo restores; Locate with permission undetermined shows the explainer and "Not now" asks nothing; Locate with permission denied shows the banner; the list works with airplane mode on; the empty-layer card; the marker guide; first run with nothing collected.
14.3 Snapshot checks: light and dark; default, selected (each of the four states), each layer, zoomed out with clusters; List; Marker guide; Location explainer; location-off banner; empty layer; map unavailable (if built); Dynamic Type default, XXL and AX3; Reduce Transparency on.
14.4 Performance: panning and zooming stay smooth with 2,000 destinations with clustering on; marker views are reused; the first render under 100 ms of local work; the selection response under 100 ms.
14.5 Acceptance checklist (every box must be true before you say done):
[ ] Hierarchy matches the mockup: cover, title and counts, window with chips and side stack, preview card, tab bar
[ ] Gold appears only for verified (marker seal, Verified chip, Verified card state, list)
[ ] A wishlisted place is never counted or labeled as collected; manual collection is never verified
[ ] Saving and collecting are idempotent and persist across relaunch
[ ] Location is requested only after Locate, never in the background, never stored; denied and Not now both leave the Map fully usable
[ ] A list of every place is always reachable, with search, even with the map unavailable or offline
[ ] The map and the list use the same layer and the same places
[ ] Selecting a place centers it in the free band and never leaves it under a chip or the card
[ ] No popularity ranking, trending, streak, timer, distance ranking or invented number anywhere
[ ] Every tappable element reaches a working destination
[ ] Light, dark, Dynamic Type, VoiceOver, Reduce Motion, Reduce Transparency all pass
14.6 Disclosures you must repeat in your report:
- The mockups and the motion video are HTML renders, not verified on a device, and used Inter in place of SF Pro.
- The map in the mockups is a stylised drawing (real coastlines and borders from public map data, cream colors). MapKit's muted standard style will look different and cannot be tinted cream. Cluster counts and positions in the mockup are artifacts of the drawing and the sample data. MapKit's clustering decides the real result, and markers keep a constant size.
- The sample data is design copy only and must not ship: the 57 sample places and their coordinates; collected Paris, Santorini and Kyoto; verified Paris; saved Machu Picchu and Sydney (and Rome in the video, after the save); the counts 3, 1, 2 (and 3 saved after the save); the first-row names in the list; the Europe region with 28 places; the cluster counts (25, 5, 5, 3, 3, 3).
- Only eight places have art in the mockups (Paris, Rome, Kyoto, Mount Fuji, Santorini, Sydney, Machu Picchu, Grand Canyon). Everything else is drawn as a dot, pin or dashed placeholder. Real art comes from the catalog.
- Not drawn inside the M3 frame, and specified here from the shared sheets and existing components: the Marker guide, the Location explainer, the List, the location-off banner, the empty-layer card, the map-unavailable state, the Search entry from the Map, the toast over the map, the marker fallback for a collected place without art, the Collected and Saved empty-layer copy, the Accessibility-size layouts, the Planned layer (not built).
- Interpretations of mine, keep them unless they fail: the "Saved" chip label for wishlist (the card says "On your wishlist"); the layer shared between map and list and not persisted; selection kept across a layer change only when the place is still in the layer; the initial camera rule (5.6); choosing a Search result closes Search, moves the camera and selects the place; Locate is a one-shot fix with the position shown only while the button is on; the window margins and the free band; the tab bar tint of 0.90 in light.
- Two other Map layouts were drawn (Atlas Float and Ledger Sheet) and are not part of this build.
- If you changed any measurement or behavior from this prompt, say which and why.
