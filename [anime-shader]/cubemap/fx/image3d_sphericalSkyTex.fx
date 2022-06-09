//
// image3d_sphericalSkyTex.fx
//

//------------------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------------------
texture sTexture;
bool bFlipView = false;

float3 fSkyTop = float3(0,0,0);
float3 fSkyBot = float3(0,0,0);

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
sampler2D SamplerTex = sampler_state
{
    Texture = (sTexture);
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU = Border;
    AddressV = Clamp;
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

    float2 uv = float2(0.5,0.5) + (viewDir.xy / viewDir.z) / PI;
    if (uvSet.x) uv.x = 1 - uv.x;
    if (uvSet.y) uv.y = 1 - uv.y;
    return uv;
}

float2 getReflectionCoords1(float3 dir)
{
    float m = 2.0 * sqrt(pow( dir.x, 2.0 ) + pow( dir.y, 2.0 ) + pow( dir.z + 1.0, 2.0 ));
    return dir.xy / m + 0.5;
}

//https://www.opengl.org/archives/resources/code/samples/advanced/advanced97/notes/node95.html
float3 getReflectionCoordsInv(float2 uv)
{
    float2 st = 2.0 * (uv.xy / - 0.5);
    float3 p = float3(-st.x, -st.y, sqrt(1.0 - st.x * st.x - st.y * st.y));
    return float3(p.x * p.z * 2, p.y * p.z * 2, p.z * p.z * 2 - 1);
}

//------------------------------------------------------------------------------------------
// PixelShaderFunction
//  1. Read from PS structure
//  2. Process
//  3. Return pixel color
//------------------------------------------------------------------------------------------
float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    if (length(PS.TexCoord - 0.5) > 0.5) return float4(0,0,0,1) * PS.Diffuse;

    float3 viewDir = - getReflectionCoordsInv(0.5 * (PS.TexCoord - 0.5)).xzy;
    if (bFlipView) viewDir = -viewDir.xzy;
	
    float skyGrad = 0;

    if (viewDir.x > 0) skyGrad += tex2D(SamplerTex, view2uv(viewDir.yzx, float2(true, true))).r;
	    else skyGrad += tex2D(SamplerTex, view2uv(viewDir.yzx, float2(true, false))).r; // right left			
    if (viewDir.y > 0) skyGrad += tex2D(SamplerTex, view2uv(viewDir.xzy, float2(false, true))).r;
	    else skyGrad += tex2D(SamplerTex, view2uv(viewDir.xzy, float2(false, false))).r; // front back
		

    float4 texel = float4(lerp(fSkyTop, fSkyBot, 1 - skyGrad), 1);
		
    // Apply diffuse lighting
    float4 finalColor = texel * PS.Diffuse;

    return finalColor;
}

//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique image3d_sphericalSkyTex
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
