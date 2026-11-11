#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// A diagonal band of light that travels across a layer. `progress` runs 0...1 while the band moves and is
/// negative while it rests. `peak` is the band's strength; `warmth` 0 is white, 1 shifts it from gold to pink like foil. The band is added in proportion to the layer's own alpha, so it never leaves the stamp's
/// perforated outline.
[[ stitchable ]] half4 foilSheen(float2 position, half4 color, float2 size, float progress, float peak, float warmth) {
    if (progress < 0.0 || color.a < 0.001h) {
        return color;
    }
    float2 uv = position / size;
    float diagonal = uv.x * 0.8 + uv.y * 0.6;
    float center = mix(-0.3, 1.7, progress);
    float d = (diagonal - center) / 0.2;
    float band = exp(-d * d);
    // A faint shift from gold to pink across the band, like foil.
    float shift = clamp((diagonal - center) / 0.4 + 0.5, 0.0, 1.0);
    half3 foil = mix(half3(1.0h), mix(half3(1.0h, 0.90h, 0.62h), half3(1.0h, 0.78h, 0.86h), half(shift)), half(warmth));
    half3 added = foil * half(band * peak);
    return half4(color.rgb + added * color.a, color.a);
}
