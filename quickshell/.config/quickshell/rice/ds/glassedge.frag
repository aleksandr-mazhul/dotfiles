#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;
    float itemWidth;
    float itemHeight;
};

float roundedBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 size = vec2(max(itemWidth, 1.0), max(itemHeight, 1.0));
    vec2 p = qt_TexCoord0 * size - size * 0.5;
    vec2 halfSize = size * 0.5;
    float r = min(radius, min(size.x, size.y) * 0.5);

    float d = roundedBox(p, halfSize - vec2(1.0), max(r - 1.0, 1.0));
    float inside = 1.0 - smoothstep(-0.6, 0.8, d);
    float inward = max(-d, 0.0);

    // Catch-light on the perimeter — decays into the transparent center.
    float rim = exp(-inward * 0.10);
    // Inner reflection, a few pixels in from the lip.
    float inner = exp(-pow(inward - 5.0, 2.0) * 0.10);

    vec2 ap = abs(p);
    float cx = smoothstep(halfSize.x - r - 22.0, halfSize.x - r + 4.0, ap.x);
    float cy = smoothstep(halfSize.y - r - 22.0, halfSize.y - r + 4.0, ap.y);
    float corner = cx * cy;

    float ny = p.y / max(halfSize.y, 1.0);
    float topBottom = smoothstep(0.50, 1.0, abs(ny));

    float a = rim * 0.30;
    a += inner * 0.11;
    a += rim * corner * 0.24;
    a += rim * topBottom * 0.12;
    a *= inside * qt_Opacity;

    fragColor = vec4(vec3(a), a);
}
