// Author: Ren712/AngerMAN
// Water_refract 1.7
//

//---------------------------------------------------------------------
//-- settings
//---------------------------------------------------------------------
texture sReflectionTexture;
texture sRandomTexture;

float3 sCameraPosition = float3(0,0,0);
float3 sCameraDirection = float3(0,0,0);

float4 sWaterColor = float4(90 / 255.0, 170 / 255.0, 170 / 255.0, 240 / 255.0 );
float2 gDistFade = float2(320,130);

float gAlpha = 0;
float normalMult =0.5;

float xval = 0.0;
float yval = 0.0;
float xzoom = 1;
float yzoom = 1;

//---------------------------------------------------------------------
// Include some common stuff
//---------------------------------------------------------------------
#include "mta-helper.fx"
float4 gFogColor                   < string renderState="FOGCOLOR"; >;
int gFogEnable                     < string renderState="FOGENABLE"; >;

//---------------------------------------------------------------------
//-- Sampler for the main texture (needed for pixel shaders)
//---------------------------------------------------------------------

sampler2D RandomSampler = sampler_state
{
   Texture = (sRandomTexture);
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
   MIPMAPLODBIAS = 0.000000;
};

sampler2D envMapSampler = sampler_state
{
    Texture = (sReflectionTexture);
    AddressU = Mirror;
    AddressV = Mirror;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
};

//---------------------------------------------------------------------
//-- Structure of data sent to the vertex shader
//--------------------------------------------------------------------- 
 
 struct VSInput
{
    float4 Position : POSITION; 
    float3 TexCoord : TEXCOORD0;
	float4 Diff : COLOR0;
};

//---------------------------------------------------------------------
//-- Structure of data sent to the pixel shader ( from the vertex shader )
//---------------------------------------------------------------------

struct PSInput
{
    float4 Position : POSITION; 
    float3 TexCoord : TEXCOORD0; 
	float4 Diff : COLOR0;
	float4 SparkleTex : TEXCOORD1;
	float3 WorldPos : TEXCOORD2;
	float DistFade : TEXCOORD3;
};

//------------------------------------------------------------------------------------------
// VertexShaderFunction
//------------------------------------------------------------------------------------------
PSInput VertexShaderSB(VSInput VS)
{
    PSInput PS = (PSInput)0;
 
    // Position in screen space.
	PS.Position = mul(float4(VS.Position.xyz , 1.0), gWorldViewProjection);

    float4 wPos = mul(VS.Position, gWorld);
    float4 vPos = mul(wPos, gView);	
    float4 pPos = mul(vPos, gProjection);

    // compute the eye vector 
    PS.TexCoord.x = (0.5 * (pPos.w + pPos.x));
    PS.TexCoord.y = (0.5 * (pPos.w - pPos.y));
    PS.TexCoord.z = pPos.w;
	
    // Convert regular water color to what we want
    float4 waterColorBase = float4(90 / 255.0, 170 / 255.0, 170 / 255.0, 240 / 255.0 );
    float4 conv           = float4(30 / 255.0,  58 / 255.0,  58 / 255.0, 200 / 255.0 );
    PS.Diff = saturate( sWaterColor * conv / waterColorBase );
	
    // Set information to do calculations in pixel shader
    PS.WorldPos = MTACalcWorldPosition( VS.Position.xyz );


    // Scroll noise texture
    float2 uvpos1 = 0;
    float2 uvpos2 = 0;

    uvpos1.x = sin(gTime/40);
    uvpos1.y = fmod(gTime/50,1);

    uvpos2.x = fmod(gTime/10,1);
    uvpos2.y = sin(gTime/12);

    PS.SparkleTex.x = VS.TexCoord.x * 1 + uvpos1.x;
    PS.SparkleTex.y = VS.TexCoord.y * 1 + uvpos1.y;
    PS.SparkleTex.z = VS.TexCoord.x * 2 + uvpos2.x;
    PS.SparkleTex.w = VS.TexCoord.y * 2 + uvpos2.y;
	
	
    float DistanceFromCamera = MTACalcCameraDistance( gCameraPosition,MTACalcWorldPosition( VS.Position.xyz ) );
    PS.DistFade = MTAUnlerp ( gDistFade.x, gDistFade.y, DistanceFromCamera );
 
    return PS;
}

//------------------------------------------------------------------------------------------
// PixelShaderFunction
//------------------------------------------------------------------------------------------
float4 PixelShaderSB(PSInput PS) : COLOR0
{
    float brightnessFactor = 0.20;
	
    float3 vFlakesNormal = tex2D(RandomSampler,PS.SparkleTex.xy).rgb;
    float3 vFlakesNormal2 = tex2D(RandomSampler,PS.SparkleTex.zw).rgb;

    vFlakesNormal = (vFlakesNormal + vFlakesNormal2 ) /2 ;
    vFlakesNormal = 2 * vFlakesNormal-1.0;

    float3 fvNormal = normalize(float3(vFlakesNormal.x * normalMult, vFlakesNormal.y * normalMult, vFlakesNormal.z)); 	

	float3 projcoord = float3((PS.TexCoord.xy / PS.TexCoord.z),0) ;
    float3 norNor = (fvNormal.x * float3(1,0,0) + fvNormal.y * float3(0,1,0));	
    projcoord.xy += norNor.xy;	
    projcoord.xy += float2(xval,yval);
    projcoord.xy *= float2(xzoom,yzoom);

    float4 reflection = tex2D(envMapSampler,projcoord.xy);
    reflection.rgb *= reflection.a;
    if (gFogEnable) reflection.rgb += gFogColor.rgb * 0.5;
    reflection.rgb *= brightnessFactor;
    reflection.rgb = saturate(reflection.rgb);
    reflection *=saturate(PS.DistFade);
	
    float4 finalColor = 1;
    finalColor = saturate(reflection + PS.Diff * 0.5);
    finalColor += reflection * PS.Diff;
    finalColor.a = PS.Diff.a;
    if (gAlpha !=1) {finalColor.a = (gAlpha);}
    return finalColor;
}

//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique Water_refract_v1_7
{
    pass P0
    {
        AlphaBlendEnable = TRUE;
        AlphaRef = 1;
        VertexShader = compile vs_2_0 VertexShaderSB();
        PixelShader = compile ps_2_0 PixelShaderSB();
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
