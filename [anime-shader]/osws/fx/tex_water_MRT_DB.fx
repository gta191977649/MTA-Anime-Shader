//
// file: tex_water_MRT_DB.fx
// version: v1.5
// author: Ren712
//

//--------------------------------------------------------------------------------------
// Variables set by MTA
//--------------------------------------------------------------------------------------
float4x4 gWorld : WORLD;
float4x4 gView : VIEW;
float4x4 gProjection : PROJECTION;
int CUSTOMFLAGS < string skipUnusedParameters = "yes"; >;
texture secondRT < string renderTarget = "yes"; >;

//---------------------------------------------------------------------
// Structure of data sent to the vertex shader
//---------------------------------------------------------------------
struct VSInput
{
    float4 Position : POSITION0;
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
    float2 Depth : TEXCOORD1;
};


//------------------------------------------------------------------------------------------
// VertexShaderFunction
//------------------------------------------------------------------------------------------
PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    // Calculate screen pos of vertex
    float4 worldPos = mul(float4(VS.Position.xyz, 1), gWorld);
    float4 viewPos = mul(worldPos, gView);

    // pass Depth
    PS.Depth = float2(viewPos.z, viewPos.w);

    // calculate screen pos of vertex
    PS.Position = mul(viewPos, gProjection);

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
//-- Use the last scene projecion matrix to inverse linearization
//------------------------------------------------------------------------------------------
float invLinearizeDepth(float linDepth)
{
    return ( gProjection[3][2] / linDepth ) + gProjection[2][2];
}

//---------------------------------------------------------------------
// Structure of color data sent to the renderer ( from the pixel shader  )
//---------------------------------------------------------------------
struct Pixel
{
    float4 Color : COLOR0;      // Render target #0
    float4 Extra : COLOR1;      // Render target #1
};

//------------------------------------------------------------------------------------------
// PixelShaderFunction
//------------------------------------------------------------------------------------------
Pixel PixelShaderFunctionSM3(PSInput PS)
{
    Pixel output;
	
    // Main render target (water effect that is rendered to world texture)
    output.Color = float4(0,0,0,0.005);

    // Secondary render target - mask
    float depth = invLinearizeDepth(PS.Depth.x / PS.Depth.y);
    output.Extra = float4(UnitToColor24New(depth), 1);
	
    return(output);
}

//------------------------------------------------------------------------------------------
// Techniques
//------------------------------------------------------------------------------------------
technique water_PS3_MRT_DB
{
    pass P0
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader  = compile ps_3_0 PixelShaderFunctionSM3();
    }
}

technique fallback
{
    pass P0
    {
    }
}