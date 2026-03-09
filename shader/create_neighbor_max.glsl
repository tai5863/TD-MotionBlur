layout(location = 0) out vec4 fragColor;
const vec2 ENCODED_ZERO_VELOCITY = vec2(0.5);
const float ENCODE_SCALE = 2.0;

vec2 decodeVelocity(const in vec2 e) {
    vec2 t = (e - ENCODED_ZERO_VELOCITY) * ENCODE_SCALE;
    vec2 v = t * abs(t);
    v.y = -v.y;
    return v;
}

float velocityMetric(const in vec2 encoded) {
    bool looksEncoded = all(greaterThanEqual(encoded, vec2(0.0))) &&
                        all(lessThanEqual(encoded, vec2(1.0)));
    if (!looksEncoded) {
        return dot(encoded, encoded);
    }
    vec2 decoded = decodeVelocity(encoded);
    return dot(decoded, decoded);
}

void main() {
    ivec2 uv = ivec2(gl_FragCoord.xy);
    ivec2 inputSize = textureSize(sTD2DInputs[0], 0);

    float maxLen = -1.0;
    vec2 maxVelocity = ENCODED_ZERO_VELOCITY;

    // check neighboring tiles
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 sampleUV = clamp(uv + ivec2(x, y), ivec2(0), inputSize - ivec2(1));

            vec2 v = texelFetch(sTD2DInputs[0], sampleUV, 0).xy;
            float len = velocityMetric(v);

            if (len > maxLen) {
                maxLen = len;
                maxVelocity = v;
            }
        }
    }

    fragColor = vec4(maxVelocity, 0.0, 1.0);
}
