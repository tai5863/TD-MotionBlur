uniform float sampleCount;
uniform float exposure;
uniform bool useVmax;
const float SOFT_Z_EXTENT = 0.01;
const vec2 ENCODED_ZERO_VELOCITY = vec2(0.5);
const float ENCODE_SCALE = 2.0;
const float MAX_BLUR_PIXELS = 32.0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
vec2 decodeVelocity(const in vec2 e) {
    vec2 t = (e - ENCODED_ZERO_VELOCITY) * ENCODE_SCALE;
    vec2 v = t * abs(t);
    v.y = -v.y;
    return v;
}

ivec2 uvToTexel(vec2 uv, ivec2 size) {
    return clamp(ivec2(uv * vec2(size)), ivec2(0), size - ivec2(1));
}

vec2 readVelocityPoint(sampler2D velocityMap, vec2 uv) {
    ivec2 size = textureSize(velocityMap, 0);
    return texelFetch(velocityMap, uvToTexel(uv, size), 0).xy;
}

float readDepthPoint(sampler2D depthMap, vec2 uv) {
    ivec2 size = textureSize(depthMap, 0);
    return texelFetch(depthMap, uvToTexel(uv, size), 0).r;
}

float rand(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

float depthWeight(float depthA, float depthB) {
    return clamp(1.0 - (depthA - depthB) / SOFT_Z_EXTENT, 0.0, 1.0);
}

float cone(float dist_norm, float len_norm) {
    return clamp(1.0 - dist_norm / max(len_norm, 0.001), 0.0, 1.0);
}

float cylinder(float dist_norm, float len_norm) {
    return 1.0 - smoothstep(0.95 * len_norm, 1.05 * len_norm, dist_norm);
}

vec2 chooseBlurVelocity(vec2 v, vec2 vmax, float uvPerPixel, bool enableVmax) {
    if (!enableVmax) {
        return v;
    }

    float vLen = length(v);
    float vmaxLen = length(vmax);
    if (vmaxLen < 1e-6) {
        return v;
    }

    float vPixels = vLen / uvPerPixel;
    float vmaxPixels = vmaxLen / uvPerPixel;
    float speedMix = smoothstep(2.0, 12.0, vPixels);
    float dominance = clamp((vmaxPixels - vPixels) / max(vmaxPixels, 1e-6), 0.0, 1.0);

    vec2 vDir = vLen > 1e-6 ? v / vLen : vec2(0.0);
    vec2 vmaxDir = vmax / vmaxLen;
    float dirAgree = dot(vDir, vmaxDir) * 0.5 + 0.5;
    float directionMix = smoothstep(0.65, 0.95, dirAgree);

    float blend = speedMix * dominance * directionMix;
    return mix(v, vmax, blend);
}

// -----------------------------------------------------------------------------
// MAIN
// -----------------------------------------------------------------------------
out vec4 fragColor;

void main() {
    vec2 uv = vUV.st;
    ivec2 colorSizeI = textureSize(sTD2DInputs[0], 0);
    vec2 colorSize = vec2(colorSizeI);
    vec2 invRes = 1.0 / colorSize;

    vec2 v = decodeVelocity(readVelocityPoint(sTD2DInputs[1], uv)) * exposure;
    // get the neighbor max velocity

    vec2 vmax = v;
    if (useVmax) {
        vmax = decodeVelocity(readVelocityPoint(sTD2DInputs[2], uv)) * exposure;
    }

    float uvPerPixel = max(invRes.x, invRes.y);
    vec2 blurV = chooseBlurVelocity(v, vmax, uvPerPixel, useVmax);
    float max_len = length(blurV);
    float maxLenUV = MAX_BLUR_PIXELS * uvPerPixel;
    if (max_len > maxLenUV) {
        blurV *= maxLenUV / max_len;
        max_len = maxLenUV;
    }

    if (max_len < 1e-4) {
        fragColor = TDOutputSwizzle(texture(sTD2DInputs[0], uv));
        return;
    }

    float v_norm = length(v) / max_len;
    float depthX = readDepthPoint(sTD2DInputs[3], uv);

    float totalWeight = 0.0;
    vec4 sum = vec4(0.0);

    float blurPixels = max_len / uvPerPixel;
    int N = int(clamp(sampleCount * (blurPixels / 8.0), 8.0, 64.0));
    float jitter = (rand(uv) - 0.5) * 0.01;

    for (int i = 0; i < N; ++i) {
        float t = mix(-1.0, 1.0, (float(i) + jitter + 0.5) / float(N));

        vec2 offsetUV = blurV * t * 0.5;
        vec2 sampUV = uv + offsetUV;

        // skip out-of-bounds
        if (sampUV.x < 0.0 || sampUV.x > 1.0 || sampUV.y < 0.0 || sampUV.y > 1.0) continue;

        vec4 colorY = texture(sTD2DInputs[0], sampUV);
        float depthY = readDepthPoint(sTD2DInputs[3], sampUV);

        vec2 vy = decodeVelocity(readVelocityPoint(sTD2DInputs[1], sampUV)) * exposure;

        float vy_norm = length(vy) / max_len;

        float dist_norm = abs(t);

        float f = depthWeight(depthY, depthX);
        float b = depthWeight(depthX, depthY);

        float w_f = f * cone(dist_norm, vy_norm);
        float w_b = b * cone(dist_norm, v_norm);
        float w_c = cylinder(dist_norm, vy_norm) * cylinder(dist_norm, v_norm) * 2.0;

        float weight = w_f + w_b + w_c;

        sum += colorY * weight;
        totalWeight += weight;
    }

    if (totalWeight < 1e-4) {
        fragColor = TDOutputSwizzle(texture(sTD2DInputs[0], uv));
    } else {
        fragColor = TDOutputSwizzle(sum / totalWeight);
    }
}
