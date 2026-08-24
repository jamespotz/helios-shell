#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
};

layout(binding = 1) uniform sampler2D oldSource;
layout(binding = 2) uniform sampler2D newSource;

// Organic ink-wipe: a left-to-right reveal edge whose boundary is warped by
// a sine wave (varying with both y and progress) so it flows and undulates
// like liquid instead of sweeping as a hard straight line.
void main() {
    vec2 uv = qt_TexCoord0;

    float wave = sin(uv.y * 12.0 + progress * 6.0) * 0.05
               + sin(uv.y * 27.0 - progress * 3.0) * 0.02;
    float edge = progress * 1.2 - 0.1;
    float mask = smoothstep(edge - 0.09, edge + 0.09, uv.x + wave);

    vec4 oldColor = texture(oldSource, uv);
    vec4 newColor = texture(newSource, uv);
    fragColor = mix(newColor, oldColor, mask) * qt_Opacity;
}
