#version 440

// Liquid glass sheet. The refraction is real: the lip samples an actual capture
// of what is behind the surface (GlassBackdrop), so light genuinely bends round
// the round-over instead of being faked with a painted gradient.
//
// The item is PADDED by `pad` px on every side. That ring carries the contact
// shadow, so the sheet needs no RectangularShadow items stacked behind it.
//
// Polarity: every optical term is signed by the QML grade (GlassGrade), so the
// same shader renders dark glass with white ink over a dark scene and light
// glass with dark ink over a bright one. Nothing here decides that — it only
// obeys the uniforms.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemW;      // padded item size, px
    float itemH;
    float srcX;       // padded item origin, in source-texture uv
    float srcY;
    float srcW;       // padded item span, in source-texture uv
    float srcH;
    float pad;        // shadow ring, px
    float radius;
    float corner;     // 2 = circular arc, ~4 = squircle (continuous curvature)
    float bevel;      // refracting round-over width, px
    float lens;       // max sample displacement, px
    float disperse;   // chromatic spread, as a fraction of lens
    float absorb;     // fraction of the backdrop that passes through the glass
    float veil;       // the sheet's own scatter; glass has body, blacks are never 0
    float satur;
    float lipWidth;   // catch-light falloff, px — must survive at 100% zoom
    float bodyTilt;   // light gathers at the top of the sheet, falls off below
    float specA;      // white catch-light on the lip
    float lipDarkA;   // dark hairline on the lip (light glass needs this)
    float causticA;   // bright line where the round-over meets the flat
    float innerA;     // thickness shading
    float shadowA;
    float shadowSize;
    float blurTexelX;  // one texel of the downsampled frost texture
    float blurTexelY;
};

layout(binding = 1) uniform sampler2D sharpTex;
layout(binding = 2) uniform sampler2D blurTex;

// p-norm rounded box. corner = 2 is a plain circular arc; corner ~4 is a
// squircle, whose curvature stays continuous where the bend meets the straight
// edge — that is what reads as "moulded" rather than "rectangle plus fillet".
float sdBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    vec2 qp = max(q, vec2(0.0));
    float n = max(corner, 2.0);
    float m = (qp.x + qp.y > 0.0) ? pow(pow(qp.x, n) + pow(qp.y, n), 1.0 / n) : 0.0;
    return min(max(q.x, q.y), 0.0) + m - r;
}

// Two-ring tent over the downsampled capture. On a 1/N texture this reads as a
// wide, smooth frost for 13 taps; the same spread at full resolution would cost
// hundreds. The outer ring matters: with a single ring the kernel is narrower
// than the source grid and the downsample's own blocks survive into the frost.
vec3 frost(vec2 uv) {
    vec2 t = vec2(blurTexelX, blurTexelY);
    vec3 c  = texture(blurTex, uv).rgb * 0.196;

    c += texture(blurTex, uv + vec2( t.x,  0.0) * 1.2).rgb * 0.094;
    c += texture(blurTex, uv + vec2(-t.x,  0.0) * 1.2).rgb * 0.094;
    c += texture(blurTex, uv + vec2( 0.0,  t.y) * 1.2).rgb * 0.094;
    c += texture(blurTex, uv + vec2( 0.0, -t.y) * 1.2).rgb * 0.094;

    c += texture(blurTex, uv + vec2( t.x,  t.y) * 1.5).rgb * 0.056;
    c += texture(blurTex, uv + vec2(-t.x,  t.y) * 1.5).rgb * 0.056;
    c += texture(blurTex, uv + vec2( t.x, -t.y) * 1.5).rgb * 0.056;
    c += texture(blurTex, uv + vec2(-t.x, -t.y) * 1.5).rgb * 0.056;

    c += texture(blurTex, uv + vec2( t.x,  0.0) * 2.6).rgb * 0.051;
    c += texture(blurTex, uv + vec2(-t.x,  0.0) * 2.6).rgb * 0.051;
    c += texture(blurTex, uv + vec2( 0.0,  t.y) * 2.6).rgb * 0.051;
    c += texture(blurTex, uv + vec2( 0.0, -t.y) * 2.6).rgb * 0.051;
    return c;
}

vec2 toSrc(vec2 px) {
    return vec2(srcX, srcY) + (px / vec2(itemW, itemH)) * vec2(srcW, srcH);
}

void main() {
    vec2 size = vec2(max(itemW, 1.0), max(itemH, 1.0));
    vec2 local = qt_TexCoord0 * size;
    vec2 p = local - size * 0.5;
    vec2 halfSize = size * 0.5 - vec2(pad);
    float r = min(radius, min(halfSize.x, halfSize.y));

    float d = sdBox(p, halfSize, r);

    // ---- contact shadow, in the padding ring --------------------------------
    float shA = 0.0;
    if (d > -2.0) {
        float ds = sdBox(p - vec2(0.0, shadowSize * 0.34), halfSize, r);
        shA = pow(exp(-max(ds, 0.0) / max(shadowSize, 1.0)), 1.5) * shadowA;
    }

    float mask = 1.0 - smoothstep(-0.7, 0.7, d);
    if (mask <= 0.002) {
        fragColor = vec4(0.0, 0.0, 0.0, shA * qt_Opacity);
        return;
    }

    // ---- surface ------------------------------------------------------------
    const float e = 1.0;
    vec2 n = normalize(vec2(
        sdBox(p + vec2(e, 0.0), halfSize, r) - sdBox(p - vec2(e, 0.0), halfSize, r),
        sdBox(p + vec2(0.0, e), halfSize, r) - sdBox(p - vec2(0.0, e), halfSize, r)
    ) + vec2(1e-6));

    float inward = max(-d, 0.0);
    float u = clamp(1.0 - inward / max(bevel, 1.0), 0.0, 1.0); // 1 at the lip -> 0 flat

    // Round-over profile: steep at the lip, flat by the time it reaches the
    // body, so the squeeze reads as a band instead of warping the whole sheet.
    float bend = pow(u, 2.2);
    vec2 disp = n * lens * bend;

    // Dispersion peaks mid-band where the gradient is steepest, and is held off
    // the outermost pixels so the lip never breaks into red/blue fringes.
    float ca = disperse * bend * smoothstep(1.0, 0.72, u);
    vec2 uvG = toSrc(local + disp);

    vec3 blurC = frost(uvG);
    vec3 sharpC = vec3(texture(sharpTex, toSrc(local + disp * (1.0 + ca))).r,
                       texture(sharpTex, uvG).g,
                       texture(sharpTex, toSrc(local + disp * (1.0 - ca))).b);

    // The round-over focuses light, so it resolves a little; the flat centre
    // stays frosted. Held well below 1: a fully sharp lip turns the edge into a
    // magnifying glass that prints readable text from whatever is behind, which
    // reads as a rendering fault rather than as optics. The squeeze comes from
    // the displacement, not from the sharpness.
    vec3 col = mix(blurC, sharpC, pow(u, 1.5) * 0.42);

    // ---- glass body ---------------------------------------------------------
    // Smoked glass: absorb a fixed fraction of whatever passes through, then add
    // the sheet's own scatter.
    //
    // Deliberately NOT a lerp toward some target luminance. Lerping replaces the
    // backdrop with a flat fill wherever the sheet is dense, so the pane reads as
    // a painted rectangle; absorbing SCALES the backdrop, so its structure always
    // survives and you can still see what is behind. It also always darkens,
    // which is what lets one single look carry white type over a white page as
    // well as over a black one — no flipping between two different skins.
    col = col * absorb + vec3(veil);
    col = mix(vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), col, satur);

    // A flat fill never reads as a lit sheet. Tilting the body — brighter at the
    // top where the light falls, falling away below — is most of what makes this
    // look like a pane and not a rectangle of colour, especially over a dull
    // backdrop that gives the refraction nothing to bend.
    float ny = clamp((p.y + halfSize.y) / max(2.0 * halfSize.y, 1.0), 0.0, 1.0);
    col *= 1.0 + bodyTilt * (0.55 - ny);

    // ---- optics -------------------------------------------------------------
    // One crisp catch-light on the lip, keyed top-left with a weaker bounce
    // bottom-right: the way a real sheet sits under a single light.
    // Two terms, because a polished edge is two things at once: a hard specular
    // line where the surface turns over, and a softer bloom just inside it. One
    // wide term alone reads as a glow; one narrow term alone vanishes at native
    // resolution. Together they read as polish.
    float lipSoft = exp(-inward / max(lipWidth, 0.5));
    float lipHard = exp(-inward / 0.9);
    float lip = lipSoft * 0.52 + lipHard * 0.48;
    float key = clamp(dot(n, normalize(vec2(-0.42, -1.0))), 0.0, 1.0);
    float bounce = clamp(dot(n, normalize(vec2(0.42, 1.0))), 0.0, 1.0);
    float spec = lip * (0.14 + 0.86 * pow(key, 1.3)) + lip * 0.44 * pow(bounce, 2.2);

    // The faint bright line where the round-over meets the flat.
    float cw = max(bevel * 0.26, 1.5);
    float caustic = exp(-pow(inward - bevel * 0.92, 2.0) / (cw * cw));

    col += vec3(spec * specA + caustic * causticA * (0.45 + 0.55 * key));

    // Light glass needs the opposite sign at the very edge, or the catch-light
    // merges with the body into a thick white frame.
    col *= 1.0 - lipSoft * lipDarkA * (0.35 + 0.65 * pow(bounce, 1.2));

    // Thickness: a soft dark band just inside the lip.
    float shade = exp(-pow(inward - bevel * 0.34, 2.0) / max(bevel * bevel * 0.07, 1.0));
    col *= 1.0 - shade * innerA * (1.0 - lipSoft);

    float a = mask * qt_Opacity;
    fragColor = vec4(col * a, a + shA * (1.0 - a) * qt_Opacity);
}
