# Catalog & artwork pipeline

## Files
`StampQuest/Resources/Catalog/`
- `catalog.json`: `schemaVersion`, `version`, the list of destination files, and the collections.
- `destinations-<region>.json`: destination records, each with its stamp.

The catalogue version is `2026.10.1`; 61 destinations, 12 collections.

## Destination record
```json
{
  "id": "paris-eiffel-tower",          // stable, never reused; user data references it
  "name": "Paris", "landmark": "Eiffel Tower",
  "country": "FR", "region": "europe", "category": "landmark",
  "lat": 48.8584, "lon": 2.2945,
  "verificationRadius": 700,           // optional; otherwise per-category default
  "featured": true,
  "summary": "…", "story": "…",
  "keywords": ["…"], "altNames": ["…"],
  "stamp": {
    "motif": "eiffel", "palette": "goldenHour",
    "variant": 0, "sun": [74, 36, 9], "night": false, "aurora": false, "clouds": 0.3,
    "tint": "#E0974F",                  // optional border override
    "title": "Louvre",                  // optional; defaults to name
    "assetName": "…",                   // optional painted artwork in the asset catalog
    "alt": "Accessibility description of the illustration"
  }
}
```

`CatalogLoader` validates every record (unique id, ISO country, known region/category/motif/palette, coordinates in range and not 0,0, radius 50 m–100 km, copy present, accessibility text present). Invalid records are **dropped and reported** (`Catalog.issues`, shown in Settings); a collection reference to a missing destination is dropped. The bundled catalogue is asserted to load with **zero** issues by `BundledCatalogTests`.

## Adding a destination
1. Pick or add a motif (`ArtMotif` + a drawing function in `Core/DesignSystem/Artwork/ArtMotifs*.swift`), or reuse one with a different palette/variant.
2. Add the record to the right `destinations-*.json`. Verify coordinates and every factual claim against a reliable source. **Do not invent facts, coordinates or rankings.**
3. Add it to collections if relevant (`catalog.json`).
4. Run the tests; open the art gallery (`-art-gallery`) to check the illustration.

## Artwork provenance & licensing
All illustrations are **original vector artwork drawn in code for StampQuest**, so there is no third-party licence or attribution. Landmarks are depicted as stylised silhouettes; no photographs, trademarks or third-party illustrations are used. Place descriptions are original text. If painted assets are added later (`assetName`), record their source and licence here before shipping.

## Versioning
`version` identifies the content release. User records never copy catalogue content (other than a title and country snapshot), so a catalogue update cannot invalidate a passport. Removing a destination leaves stamps and memories intact and visible via their snapshots.
