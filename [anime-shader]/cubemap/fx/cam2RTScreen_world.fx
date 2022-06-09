// 
// cam2RTScreen_world.fx
// version: v1.2
// author: Ren712
//

//------------------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------------------
float2 sScrRes = float2(800,600);
float3 sCameraPosition = float3(0,0,0);
float3 sCameraForward = float3(0,0,0);
float3 sCameraUp = float3(0,0,0);
float sFov = 0;
float2 sClip = float2(0.3,300);
float2 sScaleRenderTarget = float2(0.5,0.5);
float2 gDistFade = float2(400, 350);
float2 sPixelSize = float2(0.00125,0.00166);

//------------------------------------------------------------------------------------------
// Settings
//------------------------------------------------------------------------------------------
// Secondary render target texture
texture colorRT < string renderTarget = "yes"; >;
texture depthRT < string renderTarget = "yes"; >;
float gAlphaRef < string renderState="ALPHAREF"; >; 

//------------------------------------------------------------------------------------------
// Include some common stuff
//------------------------------------------------------------------------------------------
#include "mta-helper.fx"

//------------------------------------------------------------------------------------------
// Sampler for the main texture
//------------------------------------------------------------------------------------------
sampler2D Sampler0 = sampler_state
{
    Texture = (gTexture0);
};

sampler2D SamplerDepth = sampler_state
{
    Texture = (depthRT);
    AddressU = Clamp;
    AddressV = Clamp;
    MinFilter = Point;
    MagFilter = Point;
    MipFilter = None;
    SRGBTexture = false;
    MaxMipLevel = 0;
    MipMapLodBias = 0;
};

sampler2D SamplerColor = sampler_state
{
    Texture = (colorRT);
    AddressU = Clamp;
    AddressV = Clamp;
    MinFilter = Point;
    MagFilter = Point;
    MipFilter = None;
    SRGBTexture = false;
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
    float3 TexProj : TEXCOORD1;
    float PlaneDist : TEXCOORD2;
    float3 WorldPos : TEXCOORD3;
    float4 Depth : TEXCOORD4;
};

//------------------------------------------------------------------------------------------
// Create view matrix 
//------------------------------------------------------------------------------------------
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

//------------------------------------------------------------------------------------------
// createProjectionMatrix
//------------------------------------------------------------------------------------------
float4x4 createProjectionMatrix(float near_plane, float far_plane, float fov_horiz, float fov_aspect, float2 ss_mov, float2 ss_scale)
{
    float h, w, Q;

    w = 1/tan(fov_horiz * 0.5);
    h = w/fov_aspect;
    Q = far_plane/(far_plane - near_plane);

    // Create a 4x4 projection matrix from given input

    float4x4 projectionMatrix = {
        float4(w * ss_scale.x, 0,              0,             0),
        float4(0,              h * ss_scale.y, 0,             0),
        float4(ss_mov.x,       ss_mov.y,       Q,             1),
        float4(0,              0,             -Q*near_plane,  0)
    };    
    return projectionMatrix;
}

//------------------------------------------------------------------------------------------
// VertexShaderFunction
//------------------------------------------------------------------------------------------
PSInput VertexShaderFunction(VSInput VS )
{
    PSInput PS = (PSInput)0;

    // Calculate screen pos of vertex
    float4 worldPos = mul(float4(VS.Position.xyz, 1), gWorld);
    PS.WorldPos = worldPos.xyz;
	
    float3 Normal = 0;
    if (gDeclNormal == 1) Normal = mul(VS.Normal, (float3x3)gWorld);
	
    // Normalize vectors
    float3 cameraForward = normalize(sCameraForward);
    float3 cameraUp = normalize(sCameraUp);
	
    // Create ViewMatrix
    float4x4 sView = createViewMatrix(sCameraPosition, cameraForward, cameraUp);
	
    // Create ProjectionMatrix
    float sAspect = (sScrRes.y / sScrRes.x);
    float2 moveRT = float2(sScaleRenderTarget.x - 1, 1 - sScaleRenderTarget.y);
    float4x4 sProjection = createProjectionMatrix(sClip[0], sClip[1], sFov, sAspect, moveRT, sScaleRenderTarget);
	
    // Pass vertex position to pixel shader
    float4 viewPos = mul(worldPos, sView);
    PS.Position = mul(viewPos, sProjection);
	
    // Get distance form plane
    PS.PlaneDist = dot(cameraForward, worldPos.xyz - sCameraPosition);

    // Pass through tex coord
    PS.TexCoord = VS.TexCoord;
	
    // Unscaled position
    sProjection = createProjectionMatrix(sClip[0], sClip[1], sFov, sAspect, float2(0, 0), float2(1, 1));
    float4 Position = mul(viewPos, sProjection);

    // Set texCoords for projective texture
    float projectedX = (0.5 * (Position.w + Position.x));
    float projectedY = (0.5 * (Position.w - Position.y));
    PS.TexProj.xyz = float3(projectedX, projectedY, Position.w);
	
    // Calculate GTA lighting
    if (gDeclNormal == 1) PS.Diffuse = MTACalcGTACompleteDiffuse( Normal, VS.Diffuse );
    else PS.Diffuse = MTACalcGTABuildingDiffuse(VS.Diffuse);
	
    // Pass depth
    PS.Depth = float4(PS.Position.z, PS.Position.w, viewPos.z, viewPos.w);
	
    return PS;
}

//------------------------------------------------------------------------------------------
// Pack Unit Float [0,1] into RGB24
//------------------------------------------------------------------------------------------
float3 UnitToColor24New(in float depth) 
{
    // Constants
    const float3 scale	= float3(1.0, 256.0, 65536.0);
    const float2 ogb	= float2(65536.0, 256.0) / 16777215.0;
    const float normal	= 256.0 / 255.0;
	
    // Avoid Precision Errors
    float3 unit	= (float3)depth;
    unit.gb	-= floor(unit.gb / ogb) * ogb;
	
    // Scale Up
    float3 color = unit * scale;
	
    // Use Fraction to emulate Modulo
    color = frac(color);
	
    // Normalize Range
    color *= normal;
	
    // Mask Noise
    color.rg -= color.gb / 256.0;

    return color;
}

//------------------------------------------------------------------------------------------
// Unpack RGB24 into Unit Float [0,1]
//------------------------------------------------------------------------------------------
float ColorToUnit24New(in float3 color) {
    const float3 scale = float3(65536.0, 256.0, 1.0) / 65793.0;
    return dot(color, scale);
}

//------------------------------------------------------------------------------------------
// Pack Unit float [nearClip,farClip] Unit Float [0,1]
//------------------------------------------------------------------------------------------
float DistToUnit(in float dist, in float nearClip, in float farClip) 
{
    float unit = (dist - nearClip) / (farClip - nearClip);
    return unit;
}

//------------------------------------------------------------------------------------------
// Pack Unit Float [0,1] to Unit float [nearClip,farClip]
//------------------------------------------------------------------------------------------
float UnitToDist(in float unit, in float nearClip, in float farClip) 
{
    float dist = (unit * (farClip - nearClip)) + nearClip;
    return dist;
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
    float fogEnd = min(gFogEnd, gDistFade.x);
    float fogStart = min(gFogStart, gDistFade.y);
    float FogAmount = (distFromCam - fogStart )/( fogEnd - fogStart);
    texel.rgb = lerp(texel.rgb, gFogColor.rgb, saturate( FogAmount));
    return texel;
}

//------------------------------------------------------------------------------------------
// Structure of color data sent to the renderer ( from the pixel shader  )
//------------------------------------------------------------------------------------------
struct Pixel
{
    float4 World : COLOR0;      // Render target #0
    float4 Color : COLOR1;      // Render target #1
    float4 Depth : COLOR2;      // Render target #2
};

//------------------------------------------------------------------------------------------
// PixelShaderFunction
//------------------------------------------------------------------------------------------
Pixel PixelShaderFunction(PSInput PS)
{
    Pixel output;

    // Get texture pixel
    float4 texel = tex2D(Sampler0, PS.TexCoord);
	
    // Get projective texture coords	
    float2 TexProj = PS.TexProj.xy / PS.TexProj.z;
    TexProj += sPixelSize.xy * 0.5;

    // Check if pixel is drawn in front of camera plane
	float alphaRef = gAlphaRef / 255;
    if ((PS.PlaneDist > 0) && (TexProj.x > 0) && (TexProj.x <  1) && (TexProj.y > 0) && 
        (TexProj.y < 1) && (texel.a > alphaRef)) 
    {
        output.World = 0;
    }
    else
    {
        // Draw nothing
        discard;
    }
	
    // Get current pixel depth [0 - 1]
    float depth = (PS.Depth.x / PS.Depth.y) * 0.5;

    // Get packed depth texture
    float3 packedDepth = tex2D(SamplerDepth, TexProj).rgb;
	
    // Unpack depth texture
    float depthVal = ColorToUnit24New(packedDepth);
	
    // Compare with current pixel depth
    if ((depthVal >= depth * 0.99998f) && (PS.PlaneDist > 0))
    {
        // Color render target
        output.Color = texel * PS.Diffuse;
        output.Color.rgb = MTAApplyFog( output.Color.rgb, PS.Depth.z / PS.Depth.w );
		
        // Depth render target
        output.Depth.rgb = UnitToColor24New(depth);
        output.Depth.a = 1;
    }
    else
    {
        // Color render target
        output.Color = 0;
		
        // Depth render target
        output.Depth = 0;
    }
    
    return output;
}

//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique cam_screen_world_mrt
{
    pass P0
    {
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        AlphaFunc = GreaterEqual;
        ShadeMode = Gouraud;
        ZEnable = false;
        FogEnable = false;
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
