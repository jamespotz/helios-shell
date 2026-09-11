#version 440
precision highp float;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 iResolution;
    float iTime;
    float uLightMode;
    vec3 uBackground;
};

// Ported from https://openshaders.com/@jamespotz — original ran per-pixel
// off gl_FragCoord on a WebGL2 canvas; qt_TexCoord0 * iResolution is the
// Qt Quick equivalent. ECHO was 0.0 in every preset seen, so the doubled
// glow term it drove has been dropped rather than costed every iteration.

const float HUE = 0.965183675;
const float HUE_SPREAD = -0.234984949;
const float HUE_TRAVEL = 1.44218802;
const float CHROMA = 0.114240803;
const float LIGHTNESS = 0.612543881;
const float COLOUR_CYCLE = 0.217758432;
const float THETA = 2.14437842;
const float SHEAR = 0.964543879;
const float SHRINK = 0.949214935;
const float LAYERS = 74.0;
const float WARP_FREQ_X = 0.477745593;
const float WARP_FREQ_Y = 2.09256911;
const float WARP_AMP_X = 0.151804715;
const float WARP_AMP_Y = 0.0239288546;
const float ASPECT_X = 1.98424435;
const float ASPECT_Y = 0.195023641;
const float OFFSET_X = 0.322043896;
const float OFFSET_Y = 0.031076476;
const float TILT = -0.28283152;
const float ZOOM = 1.06807697;
const float CENTRE_X = -0.747402549;
const float CENTRE_Y = 0.172257394;
const float GLOW_SIZE = 0.00193295442;
const float FALLOFF = 0.35557282;
const float VIGNETTE = 0.017595537;
const float FLOW_SPEED = 0.472421438;
const float FLOW_DIRECTION = -1.0;
const float BREATH_RATE = 0.50761658;
const float BREATH_AMOUNT = 0.0849612802;
const float PHASE = 63.2617722;
const float SOFTNESS = 0.00140995474;
const float LIGHT_SWING = 0.133538812;

const float TAU = 6.28318530718;

vec3 oklchToLinear(float L, float C, float h) {
    float a = C * cos(h), b = C * sin(h);
    float l_ = L + 0.3963377774 * a + 0.2158037573 * b;
    float m_ = L - 0.1055613458 * a - 0.0638541728 * b;
    float s_ = L - 0.0894841775 * a - 1.2914855480 * b;
    vec3 lms = vec3(l_, m_, s_);
    lms = lms * lms * lms;
    return mat3(4.0767416621, -1.2684380046, -0.0041960863,
                -3.3077115913, 2.6097574011, -0.7034186147,
                0.2309699292, -0.3413193965, 1.7076147010) * lms;
}

float blueNoise(vec2 p, float frame) {
    p += 5.588238 * mod(frame, 64.0);
    return fract(52.9829189 * fract(0.06711056 * p.x + 0.00583715 * p.y));
}

void main() {
    vec2 R = iResolution;
    vec2 fragCoord = qt_TexCoord0 * R;
    vec2 pos = (fragCoord - 0.5 * R) / R.y;
    float t = iTime * FLOW_SPEED * FLOW_DIRECTION + PHASE;
    float breath = (-sin(iTime * BREATH_RATE * 1.5) + sin(iTime * BREATH_RATE + 1.0)) * 0.25 + 0.5;

    vec2 u = (pos - vec2(CENTRE_X, CENTRE_Y)) * (ZOOM - breath * BREATH_AMOUNT);
    float ct = cos(TILT), st = sin(TILT);
    u = mat2(ct, st, -st, ct) * u;

    mat2 fold = mat2(cos(THETA), sin(THETA), -SHEAR, cos(THETA));

    float hue0 = HUE * TAU;
    float hue1 = hue0 + HUE_SPREAD * TAU;
    vec3 color = vec3(0.0);

    for (float i = 1.0; i <= 96.0; i += 1.0) {
        if (i > LAYERS) break;
        u.x += -sin(u.y * WARP_FREQ_X + t + i * 0.007) * WARP_AMP_X;
        u.y += -sin(u.x * WARP_FREQ_Y - t + i * 0.02) * WARP_AMP_Y;
        u = fold * u * SHRINK;

        vec2 q = u - vec2(OFFSET_X + breath * 0.1, OFFSET_Y);
        vec2 s = vec2(q.x * ASPECT_X, q.y * ASPECT_Y);
        float glow = GLOW_SIZE / (dot(s, s) + SOFTNESS);
        glow *= 0.25 + breath * 0.4;

        float r = length(u);
        float k = sin(i * COLOUR_CYCLE + t * 1.2 + r * HUE_TRAVEL) * 0.5 + 0.5;
        vec3 tint = clamp(oklchToLinear(LIGHTNESS + LIGHT_SWING * k, CHROMA * (0.75 + 0.35 * k), mix(hue0, hue1, k)), 0.0, 1.0);
        color += glow * tint * exp2(-r * FALLOFF);
    }

    vec3 x = max(color, 0.0);
    color = (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14);
    color = pow(clamp(color, 0.0, 1.0), vec3(0.85, 0.92, 0.98));

    float edge = smoothstep(0.5, 1.6, length(pos));
    color *= 1.0 - edge * VIGNETTE;

    vec3 dark = uBackground + color * (1.0 - uBackground);
    float strength = max(color.r, max(color.g, color.b));
    vec3 light = uBackground * (1.0 - strength) + color * 0.96;
    color = mix(dark, light, uLightMode);

    color += (blueNoise(fragCoord, floor(iTime * 24.0)) - 0.5) / 255.0;
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0) * qt_Opacity;
}
