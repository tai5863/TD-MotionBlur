uniform float uAlphaFront;
uniform float uShadowStrength;
uniform vec3 uShadowColor;
uniform vec3 uDiffuseColor;
uniform vec3 uAmbientColor;
uniform vec3 uSpecularColor;
uniform float uShininess;

uniform mat4 uPrevMVP;

out Vertex
{
    vec4 color;
    vec3 worldSpacePos;
    vec3 worldSpaceNorm;
    flat int cameraIndex;
    vec4 currClipPos;
    vec4 prevClipPos;
} oVert;

void main()
{
    gl_PointSize = 1.0;
    vec3 pos = TDPos();
    vec4 localPos = vec4(pos, 1.0);
    vec3 normal = TDNormal();
    // First deform the vertex and normal
    // TDDeform always returns values in world space
    vec4 worldSpacePos = TDDeform(pos);
    vec3 uvUnwrapCoord = TDInstanceTexCoord(TDUVUnwrapCoord());

    int instanceId = TDInstanceID();

    mat4 instanceMatrix = TDInstanceMat(instanceId);
    vec4 worldFromInstance = instanceMatrix * localPos;

    vec4 currClipPos = TDWorldToProj(worldSpacePos, uvUnwrapCoord);
    gl_Position = currClipPos;

    oVert.currClipPos = currClipPos;
    oVert.prevClipPos = uPrevMVP * worldFromInstance;

    // This is here to ensure we only execute lighting etc. code
    // when we need it. If picking is active we don't need lighting, so
    // this entire block of code will be ommited from the compile.
    // The TD_PICKING_ACTIVE define will be set automatically when
    // picking is active.
    #ifndef TD_PICKING_ACTIVE

    int cameraIndex = TDCameraIndex();
    oVert.cameraIndex = cameraIndex;
    oVert.worldSpacePos.xyz = worldSpacePos.xyz;
    oVert.color = TDInstanceColor(TDColor());
    vec3 worldSpaceNorm = normalize(TDDeformNorm(normal));
    oVert.worldSpaceNorm.xyz = worldSpaceNorm;

    #else // TD_PICKING_ACTIVE

    // This will automatically write out the nessessary values
    // for this shader to work with picking.
    // See the documentation if you want to write custom values for picking.
    TDWritePickingValues();

    #endif // TD_PICKING_ACTIVE
}
