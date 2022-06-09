//
// file: image4D_lightBall.fx
// version: v1.5
// author: Ren712
//

//--------------------------------------------------------------------------------------
// Settings
//--------------------------------------------------------------------------------------
float3 sElementPosition = float3(0, 0, 0);
float3 sElementRotation = float3(0, 0, 0);
float3 sElementSize = float3(1,1,1);
float2 sSubdivUnit = float2(0.08,0.08);

float2 gDistFade = float2(250, 150);

//--------------------------------------------------------------------------------------
// Textures
//--------------------------------------------------------------------------------------
texture sRefTexture;

//--------------------------------------------------------------------------------------
// Variables set by MTA
//--------------------------------------------------------------------------------------
static const float PI = 3.14159265f;
float4x4 gProjectionMainScene : PROJECTION_MAIN_SCENE;
float4x4 gViewMainScene : VIEW_MAIN_SCENE;
float4 gFogColor < string renderState="FOGCOLOR"; >;
int gCapsMaxAnisotropy < string deviceCaps="MaxAnisotropy"; >;
int CUSTOMFLAGS < string skipUnusedParameters = "yes"; >;

//--------------------------------------------------------------------------------------
// Sampler 
//--------------------------------------------------------------------------------------
sampler2D SamplerRef = sampler_state
{
    Texture = (sRefTexture);
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU = Clamp;
    AddressV = Clamp;
};

//--------------------------------------------------------------------------------------
// Structures
//--------------------------------------------------------------------------------------
struct VSInput
{
    float3 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
    float4 Diffuse : COLOR0;
};

struct PSInput
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
    float3 Normal : TEXCOORD1;
    float3 CameraPosition : TEXCOORD2;
    float3 WorldPos : TEXCOORD3;
    float DistFade : TEXCOORD4;
    float4 Diffuse : COLOR0;
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

//--------------------------------------------------------------------------------------
// Create world matrix with world position and euler rotation
//--------------------------------------------------------------------------------------
float4x4 createWorldMatrix(float3 pos, float3 rot)
{
    float4x4 eleMatrix = {
        float4(cos(rot.z) * cos(rot.y) - sin(rot.z) * sin(rot.x) * sin(rot.y), 
                cos(rot.y) * sin(rot.z) + cos(rot.z) * sin(rot.x) * sin(rot.y), -cos(rot.x) * sin(rot.y), 0),
        float4(-cos(rot.x) * sin(rot.z), cos(rot.z) * cos(rot.x), sin(rot.x), 0),
        float4(cos(rot.z) * sin(rot.y) + cos(rot.y) * sin(rot.z) * sin(rot.x), sin(rot.z) * sin(rot.y) - 
                cos(rot.z) * cos(rot.y) * sin(rot.x), cos(rot.x) * cos(rot.y), 0),
        float4(pos.x,pos.y,pos.z, 1),
    };
    return eleMatrix;
}

//--------------------------------------------------------------------------------------
// Transform quad into sphere 
//--------------------------------------------------------------------------------------
float3 getSpherePosition(float3 inPosition, float3 scale)
{
    float3 outPosition;
    outPosition.z = cos(2 * inPosition.x * PI) / 2;
    outPosition.x = sin(2 * inPosition.x * PI) / 2;
    outPosition.xz *= cos(inPosition.y * PI);
    outPosition.y = sin(inPosition.y * PI) / 2;
    return outPosition * scale;
}

//--------------------------------------------------------------------------------------
// Vertex Shader 
//--------------------------------------------------------------------------------------
PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    // get view Matrix
    float4x4 sViewInverse = inverseMatrix(gViewMainScene);
    PS.CameraPosition = sViewInverse[3].xyz;

    // set proper position and scale of the quad
    VS.Position.xy = VS.TexCoord;
    VS.Position.xy = - 0.5 + VS.Position.xy;
	
    // shape the sphere
    float3 scaleNorm = normalize(sElementSize);
    float3 resultPos = getSpherePosition(VS.Position.xyz, scaleNorm);
	
    float3 Normal = normalize(resultPos);
	
    // scale the sphere
    VS.Position.xyz = resultPos * length(sElementSize);
	
    VS.TexCoord.y = 1 - VS.TexCoord.y;
	
    // create WorldMatrix for the quad
    float4x4 sWorld = createWorldMatrix(sElementPosition, sElementRotation);

    // calculate screen position of the vertex
    float4 wPos = mul(float4( VS.Position, 1), sWorld);
    PS.WorldPos = wPos.xyz;
    float4 vPos = mul(wPos, gViewMainScene);
    PS.Position = mul(vPos, gProjectionMainScene);
	
    // get world normal
    PS.Normal = mul(Normal, (float3x3)sWorld).xyz;
	
    // get clip values
    float nearClip = - gProjectionMainScene[3][2] / gProjectionMainScene[2][2];
    float farClip = (gProjectionMainScene[3][2] / (1 - gProjectionMainScene[2][2]));
	
    // fade
    float DistFromCam = distance(PS.CameraPosition, sElementPosition.xyz);
    float elementSize = max(max(sElementSize.x, sElementSize.y), sElementSize.z);
    float2 DistFade = float2(min(gDistFade.x, farClip - elementSize / 2), min(gDistFade.y, farClip - elementSize /2 - (gDistFade.x - gDistFade.y)));
    PS.DistFade = saturate((DistFromCam - DistFade.x)/(DistFade.y - DistFade.x));

    // pass texCoords and vertex color to PS
    PS.TexCoord = VS.TexCoord;
	
    // Pass Diffuse
    PS.Diffuse = VS.Diffuse;

    return PS;
}

float2 getReflectionCoords2(float3 dir, float2 div)
{
    return float2(((atan2(dir.x, dir.z) / (PI * div.x)) + 1) / 2,  (acos(- dir.y) / (PI * div.y)));
}

//--------------------------------------------------------------------------------------
// Pixel shaders 
//--------------------------------------------------------------------------------------
float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    // compute the direction to the light
    float3 vLight = normalize(sElementPosition - PS.WorldPos);

    float3 viewDir = normalize(PS.WorldPos - PS.CameraPosition);
    float3 refVec = reflect(viewDir, PS.Normal);
	
    float2 texCoord = getReflectionCoords2(-refVec.xzy,float2(1,1));
    float4 texel = tex2D(SamplerRef, texCoord);	

    float4 finalColor = texel;
	
    // multiply by vertex color
    finalColor *= PS.Diffuse;
	
    // add a light specular (to both sides)
    float NdotL = dot(normalize(PS.Normal), -viewDir);
    NdotL = pow(abs(NdotL), 1.5);
    float fAttenuation = saturate(NdotL);
	
    // apply attenuation
    finalColor.rgb *= saturate(0.2 + fAttenuation);
	
    // apply distFade
    finalColor.a *= saturate(PS.DistFade);

    return saturate(finalColor);
}

//--------------------------------------------------------------------------------------
// Techniques
//--------------------------------------------------------------------------------------
technique dxDrawImage4D_lightBall
{
  pass P0
  {
    ZEnable = true;
    ZFunc = LessEqual;
    ZWriteEnable = false;
    CullMode = 2;
    ShadeMode = Gouraud;
    AlphaBlendEnable = true;
    SrcBlend = SrcAlpha;
    DestBlend = InvSrcAlpha;
    AlphaTestEnable = true;
    AlphaRef = 1;
    AlphaFunc = GreaterEqual;
    Lighting = false;
    FogEnable = false;
    VertexShader = compile vs_2_0 VertexShaderFunction();
    PixelShader  = compile ps_2_0 PixelShaderFunction();
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
