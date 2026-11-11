#!/usr/bin/env python3
"""Generates the onboarding and Welcome Color Sets (Any + Dark, plus Increase Contrast where the spec needs it).

Source of truth: StampQuest-Onboarding-00-Foundation.md section 4.1.
Usage: python3 -I Tools/make_onboarding_colors.py StampQuest/Resources/Assets.xcassets
"""
import json
import os
import shutil
import sys

# name: (light, dark). A value is "RRGGBB" or (R, G, B, alpha 0...1).
TOKENS = {
    "paper": ("F7F2E8", "1B1C1A"),
    "ink": ("252724", "F2EDE3"),
    "accent": ("A05A38", "D98B66"),
    "hole": ("948E82", "6A6B64"),
    "page": ("FFFCF5", "E6DFCE"),
}

# Increase Contrast overrides (spec section 8): hairline rings at 2x strength, unfilled holes one step darker.
# Dark mode goes the other way (lighter) because "darker" would reduce contrast on a dark paper.
HIGH_CONTRAST = {
    "hole": ("7A7467", "8C8D86"),
}


# Welcome screen tokens (written to the "Welcome" folder as welcome.<name>).
# The stamp-word frames are identical in both appearances.
WELCOME_TOKENS = {
    "bgTop": ("B96A44", "1C1B19"),
    "bgMid": ("A25A38", "1C1B19"),
    "bgBottom": ("86452A", "1C1B19"),
    "glow": ((255, 205, 150, .30), (226, 150, 84, .32)),
    "textPrimary": ("FFF9F1", "F6F0E5"),
    "highlight": ("F4C783", "DB8D66"),
    "textSecondary": ((255, 249, 241, .90), "BDB6A8"),
    "textTertiary": ((255, 249, 241, .74), "8F897D"),
    "ctaFill": ("F6F1E7", "DB8D66"),
    "ctaLabel": ("8A4A2D", "221A14"),
    "ctaShadow": ((40, 12, 0, .50), (219, 141, 102, .32)),
    "stampShadow": ((50, 16, 0, .46), (0, 0, 0, .60)),
    "stampShadowHero": ((50, 16, 0, .55), (0, 0, 0, .72)),
    "postmark": ("F6F1E7", "E8A27C"),
    "progressOn": ("FFF9F1", "DB8D66"),
    "progressOff": ((255, 249, 241, .50), (246, 240, 229, .34)),
    "wordWorldFill": ("F4C783", "F4C783"),
    "wordWorldText": ("8A4A2D", "8A4A2D"),
    "wordStampFill": ("F6F1E7", "F6F1E7"),
    "wordStampText": ("A25A38", "A25A38"),
}

# Interests screen tokens (written to the "Colors" folder under their own names). Pastel stamp borders are the same
# in both appearances.
COLORS_TOKENS = {
    "onbBackground": ("F6F1E7", "1C1B19"),
    "inkPrimary": ("211E1A", "F6F0E5"),
    "inkSecondary": ("5F5A51", "BDB6A8"),
    "inkTertiary": ("6F695D", "8F897D"),
    "onbAccent": ("B15B35", "DB8D66"),
    "accentText": ("A25A38", "DB8D66"),
    "ctaFill": ("A25A38", "DB8D66"),
    "ctaLabel": ("FFF9F1", "221A14"),
    "ctaShadow": ((162, 90, 56, .55), (219, 141, 102, .30)),
    "stampWordFill": ("A25A38", "DB8D66"),
    "stampWordLabel": ("FFF9F1", "221A14"),
    "postmark": ("A4502F", "E8A27C"),
    "passportPaper": ("FBF7EE", "2B2927"),
    "passportHairline": ((70, 42, 20, .14), (246, 240, 229, .12)),
    "passportShadow": ((70, 42, 20, .28), (0, 0, 0, .55)),
    "passportSpine": ((58, 36, 16, .18), (58, 36, 16, .45)),
    "passportRings": ((177, 91, 53, .08), (219, 141, 102, .10)),
    "passportDash": ((177, 91, 53, .28), (219, 141, 102, .28)),
    "passportHeader": ((177, 91, 53, .70), (219, 141, 102, .70)),
    "screenGlow": ((245, 190, 120, .55), (226, 150, 84, .32)),
    "shadowSoft": ((70, 42, 20, .34), (0, 0, 0, .60)),
    "shadowDeep": ((70, 42, 20, .46), (0, 0, 0, .72)),
    "ctaDisabledFill": ("E7DFCF", "353330"),
    "ctaDisabledLabel": ("6F695D", "8F897D"),
    "slotFill": ((70, 42, 20, .04), (246, 240, 229, .045)),
    "slotOutline": ((120, 100, 80, .40), (246, 240, 229, .34)),
    "pillFill": ("211E1A", "F6F1E7"),
    "pillLabel": ("FFF9F1", "211E1A"),
    "pillSublabel": ((255, 249, 241, .70), (33, 30, 26, .70)),
    "goldWordFill": ("E9BE62", "E9BE62"),
    "goldWordLabel": ("4A2F0A", "4A2F0A"),
    "goldGlow": ((240, 190, 90, .62), (232, 168, 60, .40)),
    "segTrack": ("E8E1D6", "2A2826"),
    "segThumb": ("FFF9F1", "444240"),
    "segLabelOff": ("5F5A51", "9A9488"),
    "sealInk": ("5A3A0C", "5A3A0C"),
    "sealRingShadow": ("7A4E0E", "7A4E0E"),
    "stampCities": ("F4C783", "F4C783"),
    "stampCoasts": ("A8D0F2", "A8D0F2"),
    "stampMountains": ("A5D3B5", "A5D3B5"),
    "stampFood": ("EFA8B3", "EFA8B3"),
    "stampHistory": ("CDB8EC", "CDB8EC"),
    "stampHiddenGems": ("E6A4C8", "E6A4C8"),
    # Plus paywall: unselected plan edge, tile hairline, radio ring, close-button fill, and the selected plan / success
    # banner tint (ctaFill at 10% light, 17% dark).
    "stampEdge": ("E3D8C2", "403D3A"),
    "cardHairline": ((70, 42, 20, .18), (246, 240, 229, .16)),
    "radioRing": ((70, 42, 20, .60), (246, 240, 229, .50)),
    "closeFill": ((33, 30, 26, .07), (246, 240, 229, .11)),
    "selectedTint": ((162, 90, 56, .10), (219, 141, 102, .17)),
    # Exit sheet: the free-feature card fill.
    "freeCardFill": ((70, 42, 20, .045), (246, 240, 229, .05)),
}

# Increase Contrast: the empty slot outline goes to full strength.
COLORS_HIGH_CONTRAST = {
    "slotOutline": ((120, 100, 80, 1.0), (246, 240, 229, 1.0)),
    "goldGlow": ((240, 190, 90, 0.0), (232, 168, 60, 0.0)),
}

# Increase Contrast: the body text goes opaque and the glow behind it dims, which the default values cannot do
# without changing the poster (the default light subtitle measures 3.6 to 4.0 over the glow).
WELCOME_HIGH_CONTRAST = {
    "progressOff": ((255, 249, 241, .80), (246, 240, 229, .60)),
    "textSecondary": ((255, 249, 241, 1.0), "E4DED0"),
    "textTertiary": ((255, 249, 241, 1.0), "BDB6A8"),
    "glow": ((255, 205, 150, .12), (226, 150, 84, .12)),
}


def components(value):
    if isinstance(value, str):
        r, g, b = (int(value[i:i + 2], 16) for i in (0, 2, 4))
        a = 1.0
    else:
        r, g, b, a = value
    return {
        "color-space": "srgb",
        "components": {
            "red": f"{r / 255:.4f}", "green": f"{g / 255:.4f}", "blue": f"{b / 255:.4f}", "alpha": f"{a:.3f}",
        },
    }


def entry(value, dark=False, high=False):
    item = {"color": components(value), "idiom": "universal"}
    appearances = []
    if dark:
        appearances.append({"appearance": "luminosity", "value": "dark"})
    if high:
        appearances.append({"appearance": "contrast", "value": "high"})
    if appearances:
        item["appearances"] = appearances
    return item


def write_group(catalog, folder_name, prefix, tokens, high_contrast):
    root = os.path.join(catalog, folder_name)
    shutil.rmtree(root, ignore_errors=True)
    os.makedirs(root)
    with open(os.path.join(root, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    for name, (light, dark) in tokens.items():
        colors = [entry(light), entry(dark, dark=True)]
        if name in high_contrast:
            hc_light, hc_dark = high_contrast[name]
            colors += [entry(hc_light, high=True), entry(hc_dark, dark=True, high=True)]
        folder = os.path.join(root, f"{prefix}.{name}.colorset" if prefix else f"{name}.colorset")
        os.makedirs(folder)
        with open(os.path.join(folder, "Contents.json"), "w") as f:
            json.dump({"colors": colors, "info": {"author": "xcode", "version": 1}}, f, indent=2)
    print(f"wrote {len(tokens)} color sets to {root}")


def main(catalog):
    write_group(catalog, "Onboarding", "ob", TOKENS, HIGH_CONTRAST)
    write_group(catalog, "Welcome", "welcome", WELCOME_TOKENS, WELCOME_HIGH_CONTRAST)
    write_group(catalog, "Colors", None, COLORS_TOKENS, COLORS_HIGH_CONTRAST)


if __name__ == "__main__":
    main(sys.argv[1])
