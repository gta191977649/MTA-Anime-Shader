//
// image3d_equirectangular2view.fx
//

//---------------------------------------------------------------------
// Settings
//---------------------------------------------------------------------
texture sTexture_ref;
float2 fScreenSize = float2(800,600);

//---------------------------------------------------------------------
// Include some common stuff
//---------------------------------------------------------------------
float4x4 gProjection : PROJECTION;
float4x4 gView : VIEW;
float4x4 gWorld: WORLD;
static const float PI = 3.14159265f;
float4x4 gProjectionMainScene : PROJECTION_MAIN_SCENE;
float4x4 gViewMainScene : VIEW_MAIN_SCENE;
int CUSTOMFLAGS < string skipUnusedParameters = "yes"; >;

//---------------------------------------------------------------------
// Sampler for the main texture
//---------------------------------------------------------------------
sampler2D SamplerTex = sampler_state
{
    Texture = (sTexture_ref);
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU = Clamp;
    AddressV = Clamp;
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
};

//---------------------------------------------------------------------
// Structure of data sent to the pixel shader ( from the vertex shader )
//---------------------------------------------------------------------
struct PSInput
{
  float4 Position : POSITION0;
  float4 Diffuse : COLOR0;
  float2 TexCoord : TEXCOORD0;
  float4 UvToView : TEXCOORD1;
};

//--------------------------------------------------------------------------------------
// Inverse matrix
//--------------------------------------------------------------------------------------
float4x4 inverseMatrix(float4x4 input)
{
     #define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
     
     float4x4 cofactors = float4x4(
          minor(_22_23_24, _32_33_34, _42_43_44), 
         -minor(_21_23_24, _31_33_34, _41_43_44),
          minor(_21_22_24, _31_32_34, _41_42_44),
         -minor(_21_22_23, _31_32_33, _41_42_43),
         
         -minor(_12_13_14, _32_33_34, _42_43_44),
          minor(_11_13_14, _31_33_34, _41_43_44),
         -minor(_11_12_14, _31_32_34, _41_42_44),
          minor(_11_12_13, _31_32_33, _41_42_43),
         
          minor(_12_13_14, _22_23_24, _42_43_44),
         -minor(_11_13_14, _21_23_24, _41_43_44),
          minor(_11_12_14, _21_22_24, _41_42_44),
         -minor(_11_12_13, _21_22_23, _41_42_43),
         
         -minor(_12_13_14, _22_23_24, _32_33_34),
          minor(_11_13_14, _21_23_24, _31_33_34),
         -minor(_11_12_14, _21_22_24, _31_32_34),
          minor(_11_12_13, _21_22_23, _31_32_33)
     );
     #undef minor
     return transpose(cofactors) / determinant(input);
}

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
	
    // calculations for perspective-correct position recontruction
    float2 uvToViewADD = - tan(radians(90) * 0.5);
    float2 uvToViewMUL = -2.0 * uvToViewADD.xy;
    PS.UvToView = float4(uvToViewMUL, uvToViewADD);

    return PS;
}

float3 GetFarClipPosition(float2 coords, float4 uvToView, float farClip)
{
    return float3(coords.x * uvToView.x + uvToView.z, (1 - coords.y) * uvToView.y + uvToView.w, 1.0) * farClip;
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
float4 PixelShaderFunctionA(PSInput PS) : COLOR0
{  
    float4x4 sViewInverse = inverseMatrix(gViewMainScene);
    float3 viewPos = GetFarClipPosition(PS.TexCoord, PS.UvToView, 300);
    float3 worldPos = mul(float4(viewPos, 1), sViewInverse).xyz;
	
    float3 viewDir = normalize(worldPos - sViewInverse[3].xyz);
	
    float2 texCoord = getReflectionCoords2(-viewDir.xzy,float2(1,1));
    float4 texel = tex2D(SamplerTex, texCoord);
	
    float2 fillMode;
    fillMode.x = sin((max(0, fmod((texCoord.x - 0.002) * 8, 1) - 0.95) / 0.05) * PI);
    fillMode.y = sin((max(0, fmod((texCoord.y - 0.002) * 8, 1) - 0.95) / 0.05) * PI);
	
    // Apply diffuse lighting
    float4 finalColor = texel * PS.Diffuse;
    finalColor.rgb -= (fillMode.x + fillMode.y) * 0.25;
    finalColor.rgb = saturate(finalColor.rgb);

    return finalColor;
}

//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique image3d_equirectangular2view
{
    pass P0
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunctionA();
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
