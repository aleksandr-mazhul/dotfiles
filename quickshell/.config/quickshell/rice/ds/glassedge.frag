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
    float r = min(radius, min(size.x, size.y) * 0.5);
    // Keep the band on the frosted plate, not on the ignore_alpha fringe.
    float d = roundedBox(p, size * 0.5 - vec2(1.5), max(r - 1.5, 1.0));
    float inside = 1.0 - smoothstep(-0.5, 0.8, d);
    float inward = max(-d, 0.0);

    // One lobe only: bright perimeter that decays inward. A second dark ring
    // reads as a stacked frame, which is exactly the garbage to avoid.
    float rim = exp(-inward * 0.22);
    float a = rim * 0.12 * inside * qt_Opacity;
    fragColor = vec4(vec3(a), a);
}
