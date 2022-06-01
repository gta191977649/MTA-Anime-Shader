// Author: Ren712/AngerMAN
// Water_refract 1.7
//

//---------------------------------------------------------------------
//-- settings
//---------------------------------------------------------------------
float fWatLevel = 0;
bool bInvert = false;
bool fFogEnable = false;
int fCull = 1;

//---------------------------------------------------------------------
// Include some common stuff
//---------------------------------------------------------------------
#define GENERATE_NORMALS      // Uncomment for normals to be generated
#include "mta-helper.fx"
float4 gFogColor                   < string renderState="FOGCOLOR"; >;
float gFogStart                    < string renderState="FOGSTART"; >;
float gFogEnd                      < string renderState="FOGEND"; >;
int gFogEnable                     < string renderState="FOGENABLE"; >;

//---------------------------------------------------------------------
// Sampler for the main texture
//---------------------------------------------------------------------
sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
};


//---------------------------------------------------------------------
// Structure of data sent to the vertex shader
//---------------------------------------------------------------------
struct VSInput
{
  float4 Position : POSITION0;
  float3 Normal : NORMAL0;
  float4 Diffuse : COLOR0;
  float2 TexCoord : TEXCOORD0;
};

//---------------------------------------------------------------------
// Structure of data sent to the pixel shader ( from the vertex shader )
//---------------------------------------------------------------------
struct PSInput
{
  float4 Position : POSITION0;
  float4 Diffuse : COLOR0;
  float2 TexCoord : TEXCOORD0;
  float3 Normal : TEXCOORD1;
  float4 PostInvWPos : TEXCOORD2;
};

//------------------------------------------------------------------------------------------
// VertexShaderFunction
//------------------------------------------------------------------------------------------
PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    // Make sure normal is valid
    MTAFixUpNormal( VS.Normal );
	
    // Calculate screen pos of vertex
    float4 wPos = mul( VS.Position, gWorld );
    if (bInvert)
    { 
        wPos.z = - wPos.z;
        wPos.z += 2 * fWatLevel;
    }
	
    PS.PostInvWPos = wPos;
    float4 vPos = mul ( wPos, gView );
    float4 pPos = mul ( vPos, gProjection );
	
    PS.Position = pPos;

    // Pass through tex coord
    PS.TexCoord = VS.TexCoord;

    // Calculate GTA lighting buildings and peds
    PS.Normal = mul( VS.Normal, gWorld ).xyz;
    //PS.Diffuse = MTACalcGTACompleteDiffuse( PS.Normal.xyz, VS.Diffuse );
    PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );
    PS.Diffuse.rgb += MTACalcGTADynamicDiffuse( PS.Normal.xyz );
    return PS;
}

//---------------------------------------------------------------------
// FarFade
//---------------------------------------------------------------------
float farFade( float texap, float3 worldPos )
{
    if ( !gFogEnable )
        return texap;
 
    float DistanceFromCamera = distance( gCameraPosition, worldPos );
    float FogAmount = ( DistanceFromCamera - gFogStart )/( gFogEnd - gFogStart );
    texap = lerp(texap, 0, saturate( FogAmount ) );
    return texap;
}

//------------------------------------------------------------------------------------------
// PixelShaderFunction
//------------------------------------------------------------------------------------------
float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    if (( PS.PostInvWPos.z > fWatLevel ) && ( bInvert )) return 0;

    // Get texture pixel
    float4 texel = tex2D(Sampler0, PS.TexCoord);
	
    if ( !fFogEnable ) texel.a = farFade( texel.a, PS.PostInvWPos );
	
    // Apply diffuse lighting
    float4 finalColor = texel * PS.Diffuse;    
    return finalColor;
}

//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique flip_world
{
    pass P0
    {
        CullMode = fCull;
        AlphaBlendEnable = true;
        FogEnable = fFogEnable;
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
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
