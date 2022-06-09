//
// texReflection.fx
//


//---------------------------------------------------------------------
// Settings
//---------------------------------------------------------------------
texture sTexture_ref;

//---------------------------------------------------------------------
// Include some common stuff
//---------------------------------------------------------------------
static const float PI = 3.14159265f;
#define GENERATE_NORMALS      // Uncomment for normals to be generated
#include "mta-helper.fx"


//---------------------------------------------------------------------
// Sampler for the main texture
//---------------------------------------------------------------------
sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
};

sampler Sampler1 = sampler_state
{
    Texture = (gTexture1);
};

sampler2D Sampler_ref = sampler_state
{
    Texture = (sTexture_ref);
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Border;
    AddressV = Border;
    BorderColor = float4(0,0,0,0);
};

//---------------------------------------------------------------------
// Structure of data sent to the vertex shader
//---------------------------------------------------------------------
struct VSInput
{
  float3 Position : POSITION0;
  float3 Normal : NORMAL0;
  float4 Diffuse : COLOR0;
  float2 TexCoord : TEXCOORD0;
  float2 TexCoord1 : TEXCOORD1;
};

//---------------------------------------------------------------------
// Structure of data sent to the pixel shader ( from the vertex shader )
//---------------------------------------------------------------------
struct PSInput
{
  float4 Position : POSITION0;
  float4 Diffuse : COLOR0;
  float3 Specular : COLOR1;
  float2 TexCoord : TEXCOORD0;
  float2 TexCoord1 : TEXCOORD1;
  float3 Normal : TEXCOORD2;
  float3 WorldPos : TEXCOORD3;
  float4 Depth : TEXCOORD4;

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

    // Make sure normal is valid
    MTAFixUpNormal( VS.Normal );

    // Calculate screen pos of vertex	
    float4 worldPos = mul( float4(VS.Position.xyz,1) , gWorld );	
    float4 viewPos = mul( worldPos , gView );
    float4 projPos = mul( viewPos, gProjection);
    PS.Position = projPos;
    PS.WorldPos = worldPos.xyz;

    // Pass through tex coord
    PS.TexCoord = VS.TexCoord;
	
    float3 posInWorld = gWorld[3].xyz * 0.02;
    posInWorld.x = ( posInWorld.x  - int(posInWorld.x )) * -gWorld[1].x;
    posInWorld.y = ( posInWorld.y  - int(posInWorld.y )) * -gWorld[1].y;

    float anim = posInWorld.x + posInWorld.y;
    PS.TexCoord1 = VS.TexCoord1 + float2( anim, 0 );

    // Calculate GTA lighting for buildings
    PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );

    // Set information to do specular calculation in pixel shader
    PS.Normal = MTACalcWorldNormal( VS.Normal );
	
    // Pass depth
    PS.Depth = float4(PS.Position.z, PS.Position.w, viewPos.z, viewPos.w);
	
    // Calculate GTA lighting for Vehicles
    PS.Diffuse = MTACalcGTACompleteDiffuse( PS.Normal, VS.Diffuse );
    PS.Specular.rgb = gMaterialSpecular.rgb * MTACalculateSpecular( gCameraDirection, gLight1Direction, PS.Normal, gMaterialSpecPower ) * 0.7;

    return PS;
}

//------------------------------------------------------------------------------------------
// MTAApplyFog
//------------------------------------------------------------------------------------------
int gFogEnable                     < string renderState="FOGENABLE"; >;
float4 gFogColor                   < string renderState="FOGCOLOR"; >;
float gFogStart                    < string renderState="FOGSTART"; >;
float gFogEnd                      < string renderState="FOGEND"; >;
 
float3 MTAApplyFog( float3 texel, float distFromCam )
{
    if ( !gFogEnable )
        return texel;
    float FogAmount = ( distFromCam - gFogStart )/( gFogEnd - gFogStart );
    texel.rgb = lerp(texel.rgb, gFogColor.rgb, saturate( FogAmount) );
    return texel;
}

float2 getReflectionCoords2(float3 dir, float2 div)
{
    return float2(((atan2(dir.x, dir.z) / (PI * div.x)) + 1) / 2,  (acos(- dir.y) / (PI * div.y)));
}

//------------------------------------------------------------------------------------------
// PixelShaderFunction
//  1. Read from PS structure
//  2. Process
//  3. Return pixel color
//------------------------------------------------------------------------------------------
float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    // Get reflection pixel
    float3 viewDir = normalize(PS.WorldPos - gViewInverse[3].xyz);
    float3 refVec = reflect(viewDir, PS.Normal);
	
    float2 texCoord = getReflectionCoords2(-refVec.xzy,float2(1,1));
    float4 refTex = tex2D(Sampler_ref, texCoord);
	
    // Get texture pixel
    float4 texel = tex2D(Sampler0, PS.TexCoord);
    float4 refTex1 = tex2D(Sampler1, PS.TexCoord1);

    // Apply diffuse lighting
    float4 finalColor = texel * PS.Diffuse;

    // Apply specular
    finalColor.rgb += PS.Specular.rgb;

    finalColor.rgb += saturate(refTex1.rgb * gMaterialSpecular.rgb * 0.1);

    finalColor = saturate(finalColor);
	
    if ((PS.Diffuse.a <= 0.85) || (length(texel.rgb) > 1)) finalColor.rgb = lerp(finalColor, refTex.rgb, 0.2);
    finalColor.rgb = MTAApplyFog(finalColor.rgb, PS.Depth.z / PS.Depth.w);

    return saturate(finalColor);
}


//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique texReflection
{
    pass P0
    {
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
