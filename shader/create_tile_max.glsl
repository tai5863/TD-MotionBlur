layout(local_size_x = 16, local_size_y = 16) in;

shared vec2 sharedMax[16 * 16];

void main()
{
    ivec2 globalId = ivec2(gl_GlobalInvocationID.xy);
    ivec2 localId = ivec2(gl_LocalInvocationID.xy);
    ivec2 groupId = ivec2(gl_WorkGroupID.xy);
    int totalSize = int(gl_WorkGroupSize.x * gl_WorkGroupSize.y);
    int idx = int(localId.x + localId.y * gl_WorkGroupSize.x);

    vec4 raw = texelFetch(sTD2DInputs[0], globalId, 0);
    vec2 v = raw.xy;

    sharedMax[idx] = v;
    memoryBarrierShared();
    barrier();

    // parallel reduction
    // 16 → 8 → 4 → 2 → 1
    // stride >>=1 means divide by 2
    for(int stride = totalSize / 2; stride > 0; stride >>= 1) {
        if (idx < stride) {
            vec2 a = sharedMax[idx];
            vec2 b = sharedMax[idx + stride];
            sharedMax[idx] = dot(a, a) > dot(b, b) ? a : b;
        }
        memoryBarrierShared();
        barrier();
    }

    if (idx == 0) {
        imageStore(mTDComputeOutputs[0], groupId, TDOutputSwizzle(vec4(sharedMax[0], 0, 1)));
    }

}
