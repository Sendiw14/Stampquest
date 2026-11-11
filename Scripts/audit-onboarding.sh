#!/bin/zsh
# Static checks for the onboarding module (Docs/Onboarding/AUDIT.md section 13). Exits non-zero on any hit.
# Run from anywhere: scripts/audit-onboarding.sh
set -u
cd "$(dirname "$0")/.." || exit 2
DIR=StampQuest/Features/Onboarding
fail=0

# check <title> <grep -E pattern> [allow-regex applied to "path:line:text"]
check() {
    local title=$1 pattern=$2 allow=${3:-}
    local hits
    hits=$(grep -rnE --include='*.swift' --include='*.metal' "$pattern" "$DIR" || true)
    [[ -n $allow && -n $hits ]] && hits=$(print -r -- "$hits" | grep -vE "$allow" || true)
    if [[ -n $hits ]]; then
        print "FAIL: $title"; print -r -- "$hits" | sed 's/^/    /'; fail=1
    else
        print "ok:   $title"
    fi
}

check "no hard-coded colours outside the theme" 'Color\(red:|UIColor\(red:|#colorLiteral|Color\(hex|"#[0-9A-Fa-f]{6}"'
# Fixed point sizes are allowed only for glyphs inside fixed-size art (badges, icons, stamp and passport artwork);
# text that reads as copy must scale (@ScaledMetric). Image(systemName:) glyphs and art files are exempt.
check "no unscaled numeric font sizes on copy" 'system\(size: [0-9.]+' \
    'audit:fixed-glyph|systemName:|PassportHolderPage|PlusSeal|StarterStampButton|ReadySummary|SwatchDock|PlanPicker|StatusBanner|TrialRoute|InterestSlotView|OnboardingTopBar|InterestPresentation|VerificationBullets'
check "no leftovers or unsafe code" 'print\(|TODO|FIXME|HACK|try!|as!|AnyView'
check "no timer or asyncAfter sequencing, no UIScreen.main" 'DispatchQueue\.main\.asyncAfter|Timer\.scheduledTimer|UIScreen\.main'
check "no literal money, dates or placeholder names" '"\$[0-9]|"[0-9]+\.[0-9]{2}"|OCT 2026|Alex Rivera|Alex' '^\S+:[0-9]+:\s*///|FakePackStoreClient|static let standard'
# Gold means a Verified stamp. Allowed: the Verification module, and the shader and cover art that are not UI state.
check "gold only in the Verified component" '[Gg]old' 'Features/Onboarding/Verification/|FoilSheen'
check "no literal user-facing strings in views" 'Text\("[A-Za-z]|accessibilityLabel\("[A-Za-z]' '(Text|accessibilityLabel)\("[a-z]+(\.[A-Za-z0-9]+)+[" ]'
if emoji=$(grep -rn --include='*.swift' -e $'\xF0\x9F' -e $'\xE2\x9C' -e $'\xE2\x98' "$DIR"); then
    print "FAIL: no emoji"; print -r -- "$emoji" | sed 's/^/    /'; fail=1
else
    print "ok:   no emoji"
fi

exit $fail
