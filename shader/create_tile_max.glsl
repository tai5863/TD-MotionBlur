layout(local_size_x = 16, local_size_y = 16) in;

shared vec2 sharedMax[16 * 16];
const vec2 ENCODED_ZERO_VELOCITY = vec2(0.5);
const float ENCODE_SCALE = 2.0;

vec2 decodeVelocity(const in vec2 e) {
    vec2 t = (e - ENCODED_ZERO_VELOCITY) * ENCODE_SCALE; // -1..1

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

void main()
{
    ivec2 globalId = ivec2(gl_GlobalInvocationID.xy);
    ivec2 localId = ivec2(gl_LocalInvocationID.xy);
    ivec2 groupId = ivec2(gl_WorkGroupID.xy);
    int totalSize = int(gl_WorkGroupSize.x * gl_WorkGroupSize.y);
    int idx = int(localId.x + localId.y * gl_WorkGroupSize.x);

    ivec2 inputSize = textureSize(sTD2DInputs[0], 0);
    bool inBounds = (globalId.x >= 0 && globalId.x < inputSize.x &&
                     globalId.y >= 0 && globalId.y < inputSize.y);
    vec2 v = inBounds ? texelFetch(sTD2DInputs[0], globalId, 0).xy : ENCODED_ZERO_VELOCITY;

    sharedMax[idx] = v;
    memoryBarrierShared();
    barrier();

    // parallel reduction
    // 16 → 8 → 4 → 2 → 1
    // stride >>=1 means divide by 2
    for (int stride = totalSize / 2; stride > 0; stride >>= 1) {
        if (idx < stride) {
            vec2 a = sharedMax[idx];
            vec2 b = sharedMax[idx + stride];
            sharedMax[idx] = velocityMetric(a) > velocityMetric(b) ? a : b;
        }
        memoryBarrierShared();
        barrier();
    }

    if (idx == 0) {
        imageStore(mTDComputeOutputs[0], groupId, TDOutputSwizzle(vec4(sharedMax[0], 0, 1)));
    }
}
