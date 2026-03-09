layout(location = 0) out vec4 fragColor;

void main() {
    ivec2 uv = ivec2(gl_FragCoord.xy);

    float maxLen = -1.0;
    vec2 maxVelocity = vec2(0.5, 0.5); // velocity 0 state

    // check neighboring tiles
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 sampleUV = uv + ivec2(x, y);

            vec2 v = texelFetch(sTD2DInputs[0], sampleUV, 0).xy;

            vec2 vDec = (v - vec2(127.0/255.0));
            float len = dot(vDec, vDec);

            if (len > maxLen) {
                maxLen = len;
                maxVelocity = v;
            }
        }
    }

    fragColor = vec4(maxVelocity, 0.0, 1.0);
}
