uniform float k; // tile size
uniform float sampleCount;
uniform vec2 viewport;
uniform float exposureTime;
uniform float fps;
float cameraFar;

const float SOFT_Z_EXTENT = 0.01;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// 8bit → -1..1 velocity decoding
vec2 decodeVelocity(const in vec2 e) {
    vec2 t = (e - vec2(127.0 / 255.0)) * (255.0 / 127.0); // ≒ -1..1
    
    vec2 v = t * abs(t);
    v.y = -v.y;
    return v;
}


float readDepth(sampler2D depthMap, vec2 uv) {
    return texture(depthMap, uv).r;
}

float rand(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

float softDepthCompare(float currentDepth, float sampleDepth) {
    return clamp(1.0 - (currentDepth - sampleDepth) / SOFT_Z_EXTENT, 0.0, 1.0);
}

// -----------------------------------------------------------------------------
// MAIN
// -----------------------------------------------------------------------------

out vec4 fragColor;

void main() {
    ivec2 resI = ivec2(uTD2DInfos[0].res);
    vec2 res = vec2(resI);
    vec2 uv = vUV.st;

    float velocityScale = exposureTime * fps;
    
    vec2 vScale = decodeVelocity(texture(sTD2DInputs[1], uv).xy);
    vec2 vmaxScale = decodeVelocity(texture(sTD2DInputs[2], uv).xy);
 
    float vLen = length(vScale);
    float vmaxLen = length(vmaxScale);
 
    vec2 blurDir;
    if (vLen > 1e-4) {
        blurDir = vScale / vLen;
    } else {
        blurDir = vmaxScale / vmaxLen;
    }
    
    float blurLen = clamp(vLen * velocityScale, 0.0, vmaxLen * velocityScale);
    
    vec2 blurVecUV = blurDir * blurLen;
    
    // -----------------------------
    // 2. depth を見つつサンプル
    // -----------------------------
    
    float currentDepth = readDepth(sTD2DInputs[3], uv);
    
    vec4 sum = vec4(0.0);
    float totalWeight = 0.0;
    
    int N = int(sampleCount);
    
    for (int i = 0; i < N; ++i) {
        float t = (float(i) / float(N - 1)) * 2.0 - 1.0;
        // Jitter
        t += (rand(uv + vec2(i)) - 0.5) * 2.0 / float(N);
        
        vec2 offsetUV = blurVecUV * t * 0.5;
        vec2 sampUV = clamp(uv + offsetUV, 0.0, 1.0);
        
        // Fetch color and depth
        vec4 c = texture(sTD2DInputs[0], sampUV);
        float sampleDepth = readDepth(sTD2DInputs[3], sampUV);

        // Avoid blending background onto foreground
        float dWeight = softDepthCompare(currentDepth, sampleDepth);  

        float dist = abs(t);
        float cWeight = clamp(1.0 - dist, 0.0, 1.0);

        float weight = cWeight * dWeight;
        weight = pow(weight, 2.0);
     
        sum += c * weight;
        totalWeight += weight;
    }

    vec4 color = texture(sTD2DInputs[0], uv);

    if (totalWeight < 1e-4)
    {
        fragColor = TDOutputSwizzle(color);
    }
    else
    {
        fragColor = TDOutputSwizzle(sum / totalWeight);
    }
    
}

