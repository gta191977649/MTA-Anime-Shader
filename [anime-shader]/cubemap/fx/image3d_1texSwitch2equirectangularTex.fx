//
// image3d_1texSwicth2equirectangularTex.fx
//

//------------------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------------------
texture sTexture_wrdFace;
int iFaceNr = 0;

//------------------------------------------------------------------------------------------
// Include some common stuff
//------------------------------------------------------------------------------------------
float4x4 gProjection : PROJECTION;
float4x4 gView : VIEW;
float4x4 gWorld: WORLD;
static const float PI = 3.14159265f;
float4x4 gProjectionMainScene : PROJECTION_MAIN_SCENE;
float4x4 gViewMainScene : VIEW_MAIN_SCENE;
float4 gFogColor < string renderState="FOGCOLOR"; >;
int CUSTOMFLAGS < string skipUnusedParameters = "yes"; >;

//------------------------------------------------------------------------------------------
// Sampler for the main texture
//------------------------------------------------------------------------------------------
sampler2D Sampler_wrdFace = sampler_state
{
    Texture = (sTexture_wrdFace);
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU = Border;
    AddressV = Border;
    SRGBTexture = false;
    BorderColor = float4(0,0,0,0);
    MaxMipLevel = 0;
    MipMapLodBias = 0;
};

//------------------------------------------------------------------------------------------
// Structure of data sent to the vertex shader
//------------------------------------------------------------------------------------------
struct VSInput
{
  float3 Position : POSITION0;
  float3 Normal : NORMAL0;
  float4 Diffuse : COLOR0;
  float2 TexCoord : TEXCOORD0;
};

//------------------------------------------------------------------------------------------
// Structure of data sent to the pixel shader ( from the vertex shader )
//------------------------------------------------------------------------------------------
struct PSInput
{
  float4 Position : POSITION0;
  float4 Diffuse : COLOR0;
  float2 TexCoord : TEXCOORD0;
};

//------------------------------------------------------------------------------------------
// VertexShaderFunction
//  1. Read from VS structure
//  2. Process
//  3. Write to PS structure
//------------------------------------------------------------------------------------------
PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    // Calculate screen pos of vertex
    float4 worldPos = mul(float4(VS.Position.xyz, 1), gWorld);
    float4 viewPos = mul(worldPos, gView);
    PS.Position = mul(viewPos, gProjection);
	
    // Pass through tex coord
    PS.TexCoord = VS.TexCoord;

    // Pass diffuse color
    PS.Diffuse = VS.Diffuse;
	
    return PS;
}

float2 view2uv(in float3 viewDir, bool2 uvSet)
{
    viewDir.z *= 1 / (0.5 * PI);

    float2 uv = float2(0.5, 0.5) + (viewDir.xy / viewDir.z) / PI;
    if (uvSet.x) uv.x = (1 - uv.x);
    if (uvSet.y) uv.y = (1 - uv.y);
    return uv;
}

float3 sphericalToWorld(float2 sphCoord, float r)
{
    return float3(
    	r * sin(sphCoord.y) * cos(sphCoord.x),
        r * sin(sphCoord.y) * sin(sphCoord.x),
		r * cos(sphCoord.y)
    );
}

//------------------------------------------------------------------------------------------
// PixelShaderFunction
//  1. Read from PS structure
//  2. Process
//  3. Return pixel color
//------------------------------------------------------------------------------------------
float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float2 inTexCoord = float2(0.25 - PS.TexCoord.x, PS.TexCoord.y) * float2(2.0 * PI, PI);
    float3 viewDir = sphericalToWorld(inTexCoord, 1.0);
	
    float2 texCoord = 0;

    if (viewDir.x >= 0) {if (iFaceNr == 1) texCoord = view2uv(viewDir.yzx, float2(true, true));}
	    else {if (iFaceNr == 2) texCoord = view2uv(viewDir.yzx, float2(true, false));} // right left		
    if (viewDir.z >= 0) {if (iFaceNr == 3) texCoord = view2uv(viewDir, float2(false, false));}
	    else {if (iFaceNr == 4) texCoord = view2uv(viewDir, float2(true, false));} // up bottom
    if (viewDir.y >= 0) {if (iFaceNr == 5) texCoord = view2uv(viewDir.xzy, float2(false, true));}
	    else {if (iFaceNr == 6) texCoord = view2uv(viewDir.xzy, float2(false, false));} // front back

    float4 texel = tex2D(Sampler_wrdFace, texCoord);
		
    // Apply diffuse lighting
    float4 finalColor = texel * PS.Diffuse;

    return finalColor;
}

//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique image3d_1texSwich2equirectangularTex
{
    pass P0
    {
        AlphaTestEnable = false;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        SeparateAlphaBlendEnable = true;
        SrcBlendAlpha = SrcAlpha;
        DestBlendAlpha = One;
        SRGBWriteEnable = false;
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}

// Fallback
technique fallback
{
    pass P0
    {
        // Just draw normally
    }
}
