//
// image3d_drawSky.fx
//

//------------------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------------------
int iFaceNr = 0;

float3 sCameraPosition = float3(0,0,0);
float3 sCameraForward = float3(0,0,0);
float3 sCameraUp = float3(0,0,0);
float sFov = 0;
float2 sClip = float2(0.3,300);

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
  float4 UvToView : TEXCOORD1;
};

//------------------------------------------------------------------------------------------
// Usefull stuff 
//------------------------------------------------------------------------------------------
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

float4x4 createViewMatrix( float3 pos, float3 fwVec, float3 upVec )
{
    float3 zaxis = normalize( fwVec );    // The "forward" vector.
    float3 xaxis = normalize( cross( -upVec, zaxis ));// The "right" vector.
    float3 yaxis = cross( xaxis, zaxis );     // The "up" vector.

    // Create a 4x4 view matrix from the right, up, forward and eye position vectors
    float4x4 viewMatrix = {
        float4(      xaxis.x,            yaxis.x,            zaxis.x,       0 ),
        float4(      xaxis.y,            yaxis.y,            zaxis.y,       0 ),
        float4(      xaxis.z,            yaxis.z,            zaxis.z,       0 ),
        float4(-dot( xaxis, pos ), -dot( yaxis, pos ), -dot( zaxis, pos ),  1 )
    };
    return viewMatrix;
}

float3 GetFarClipPosition(float2 coords, float4 uvToView, float farClip)
{
    return float3(coords.x * uvToView.x + uvToView.z, (1 - coords.y) * uvToView.y + uvToView.w, 1.0) * farClip;
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
    float2 uvToViewADD = - tan(sFov * 0.5);	
    float2 uvToViewMUL = -2.0 * uvToViewADD.xy;
    PS.UvToView = float4(uvToViewMUL, uvToViewADD);
	
    return PS;
}

//------------------------------------------------------------------------------------------
// PixelShaderFunction
//  1. Read from PS structure
//  2. Process
//  3. Return pixel color
//------------------------------------------------------------------------------------------
float4 PixelShaderFunctionPre(PSInput PS) : COLOR0
{
    // Normalize vectors
    float3 cameraForward = normalize(sCameraForward);
    float3 cameraUp = normalize(sCameraUp);
	
    // Create ViewMatrix
    float4x4 sView = createViewMatrix(sCameraPosition, cameraForward, cameraUp);
	
    float4x4 sViewInverse = inverseMatrix(sView);

    float3 viewPos = GetFarClipPosition(PS.TexCoord, PS.UvToView, sClip.y);
	
    float3 worldPos = mul(float4(viewPos, 1), sViewInverse).xyz;
	float3 worldNormal = normalize(worldPos - sViewInverse[3].xyz); 
    float3 lightDir = float3(0,0,1);
	
    // dot product
    float NdotL = pow(saturate(2.5 * dot(worldNormal, lightDir)), 1.5);
	
    return float4(lerp(fSkyBot, fSkyTop, NdotL), 1);
}

//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique image3d_drawSky
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
        PixelShader = compile ps_3_0 PixelShaderFunctionPre();
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
