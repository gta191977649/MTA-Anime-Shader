//-----------------------------------------------------------------------
//-- Settings
//-----------------------------------------------------------------------


//---------------------------------------------------------------------
// Include some common stuff
//---------------------------------------------------------------------
#include "mta-helper.fx"

float RimMin = 0.5;
float RimMax = 1;
float RimSmooth = 1;
//-----------------------------------------------------------------------
//-- Sampler for the new texture
//-----------------------------------------------------------------------
sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
};


//-----------------------------------------------------------------------
//-- Structure of data sent to the vertex shader
//-----------------------------------------------------------------------
struct VSInput
{
    float3 Position : POSITION0;
    float3 Normal : NORMAL0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

//-----------------------------------------------------------------------
//-- Structure of data sent to the pixel shader ( from the vertex shader )
//-----------------------------------------------------------------------
struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};


//--------------------------------------------------------------------------------------------
//-- VertexShaderFunction
//--  1. Read from VS structure
//--  2. Process
//--  3. Write to PS structure
//--------------------------------------------------------------------------------------------
PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    PS.Position = mul(float4(VS.Position, 1), gWorldViewProjection);

    PS.TexCoord = VS.TexCoord;

    PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );


    float3 worldPos =MTACalcWorldPosition(VS.Position);
    float3 viewDir = MTACalculateCameraDirection(gCameraPosition, worldPos);
    float3 worldNormal = MTACalcWorldNormal(VS.Normal);

    float f =  1- saturate(dot(viewDir,VS.Normal));
    float4 RimColor = float4(1,1,1,0.5);
    //float4 LightColor = float4(1,1,1,1);
    float rim = smoothstep(RimMin,RimMax,f);
    rim = smoothstep(0, RimSmooth, rim);
    float3 rimColor = rim * RimColor.rgb *  RimColor.a;
    PS.Diffuse.rgb = rimColor + PS.Diffuse.rgb;
    //PS.Diffuse.rgb = rimC;
    return PS;
}


//--------------------------------------------------------------------------------------------
//-- PixelShaderFunction
//--  1. Read from PS structure
//--  2. Process
//--  3. Return pixel color
//--------------------------------------------------------------------------------------------
float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    //-- Get texture pixel
    float4 texel = tex2D(Sampler0, PS.TexCoord);

    //-- Apply diffuse lighting
    float4 finalColor = texel * PS.Diffuse;
    //float4 finalColor =  PS.Diffuse;


    return finalColor;
}


//--------------------------------------------------------------------------------------------
//-- Techniques
//--------------------------------------------------------------------------------------------
technique tec
{
    pass P0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}
