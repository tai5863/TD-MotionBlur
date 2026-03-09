uniform float uAlphaFront;
uniform float uShadowStrength;
uniform vec3 uShadowColor;
uniform vec3 uDiffuseColor;
uniform vec3 uAmbientColor;
uniform vec3 uSpecularColor;
uniform float uShininess;

in Vertex
{
    vec4 color;
    vec3 worldSpacePos;
    vec3 worldSpaceNorm;
    flat int cameraIndex;
    vec4 currClipPos;
    vec4 prevClipPos;
} iVert;

// Output variable for the color
layout(location = 0) out vec4 oFragColor[TD_NUM_COLOR_BUFFERS];
const float CLIP_W_EPS = 1e-6;

void main()
{
    // This allows things such as order independent transparency
    // and Dual-Paraboloid rendering to work properly
    TDCheckDiscard();

    // This will hold the combined color value of all light sources
    vec3 lightingColor = vec3(0.0, 0.0, 0.0);
    vec3 diffuseSum = vec3(0.0, 0.0, 0.0);
    vec3 specularSum = vec3(0.0, 0.0, 0.0);

    vec3 worldSpaceNorm = normalize(iVert.worldSpaceNorm.xyz);
    vec3 normal = normalize(worldSpaceNorm.xyz);
    vec3 viewVec = normalize(uTDMats[iVert.cameraIndex].camInverse[3].xyz - iVert.worldSpacePos.xyz);

    vec4 color = TDPixelColor(iVert.color);

    // Flip the normals on backfaces
    // On most GPUs this function just return gl_FrontFacing.
    // However, some Intel GPUs on macOS have broken gl_FrontFacing behavior.
    // When one of those GPUs is detected, an alternative way
    // of determing front-facing is done using the position
    // and normal for this pixel.
    if (!TDFrontFacing(iVert.worldSpacePos.xyz, worldSpaceNorm.xyz))
    {
        normal = -normal;
    }

    // Your shader will be recompiled based on the number
    // of lights in your scene, so this continues to work
    // even if you change your lighting setup after the shader
    // has been exported from the Phong MAT
    for (int i = 0; i < TD_NUM_LIGHTS; i++)
    {
        TDPhongResult res;
        res = TDLighting(
                i,
                iVert.worldSpacePos.xyz,
                normal,
                uShadowStrength, uShadowColor,
                viewVec,
                uShininess,
                1.0); // unused, specular2 is not active
        diffuseSum += res.diffuse;
        specularSum += res.specular;
    }

    // Final Diffuse Contribution
    diffuseSum *= uDiffuseColor.rgb;
    vec3 finalDiffuse = diffuseSum;
    lightingColor += finalDiffuse;

    // Final Specular Contribution
    vec3 finalSpecular = vec3(0.0);
    specularSum *= uSpecularColor;
    finalSpecular += specularSum;

    lightingColor += finalSpecular;

    // Ambient Light Contribution
    lightingColor += vec3(uTDGeneral.ambientColor.rgb * uAmbientColor.rgb);
    // Alpha Calculation
    float alpha = uAlphaFront;

    vec4 finalColor = vec4(lightingColor, alpha);
    finalColor.rgb *= finalColor.a;
    finalColor *= color;

    // Apply fog, this does nothing if fog is disabled
    finalColor = TDFog(finalColor, iVert.worldSpacePos.xyz, iVert.cameraIndex);

    // Dithering, does nothing if dithering is disabled
    finalColor = TDDither(finalColor);

    // Modern GL removed the implicit alpha test, so we need to apply
    // it manually here. This function does nothing if alpha test is disabled.
    TDAlphaTest(finalColor.a);

    oFragColor[0] = TDOutputSwizzle(finalColor);

    // TD_NUM_COLOR_BUFFERS will be set to the number of color buffers
    // active in the render. By default we want to output zero to every
    // buffer except the first one.
    for (int i = 1; i < TD_NUM_COLOR_BUFFERS; i++) {
        if (i == 1) {
            // half spread velocity
            vec2 velocity;
            vec4 currClipPos = iVert.currClipPos;
            vec4 prevClipPos = iVert.prevClipPos;
            bool invalidW = abs(currClipPos.w) < CLIP_W_EPS || abs(prevClipPos.w) < CLIP_W_EPS;
            if (finalColor.a < 0.1 || invalidW) {
                velocity = vec2(0.5);
            } else {
                // clip -> NDC (-1 ~ 1)
                vec2 currNDC = currClipPos.xy / currClipPos.w;
                vec2 prevNDC = prevClipPos.xy / prevClipPos.w;
                velocity = (currNDC.xy - prevNDC.xy) * 0.5;
                velocity.y = -velocity.y;
                // velocity encoding :
                // http://www.crytek.com/download/Sousa_Graphics_Gems_CryENGINE3.pdf
                velocity = sign(velocity) * sqrt(abs(velocity)) * 0.5 + vec2(0.5);
            }

            oFragColor[i] = vec4(velocity.x, velocity.y, 0.0, 1.0);
        } else {
            oFragColor[i] = vec4(0.0);
        }
    }
}
