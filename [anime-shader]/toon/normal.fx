//---------------------------------------------------------------------
// Include some common stuff
//---------------------------------------------------------------------
#include "mta-helper.fx"


//-----------------------------------------------------------------------
//-- Sampler for the new texture
//-----------------------------------------------------------------------
sampler Sampler0 = sampler_state
{
    Texture         = (gTexture0);
    MinFilter       = Linear;
    MagFilter       = Linear;
    MipFilter       = Linear;
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

    //-- Calculate screen pos of vertex
    PS.Position = mul(float4(VS.Position, 1), gWorldViewProjection);

    //-- Pass through tex coord
    PS.TexCoord = VS.TexCoord;

    //-- Calculate GTA lighting for buildings
    //PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );
    PS.Diffuse = float4(abs(VS.Normal),1);
    
    //--
    //-- NOTE: The above line is for GTA buildings.
    //-- If you are replacing a vehicle texture, do this instead:
    //--
    //--      // Calculate GTA lighting for vehicles
    //--      float3 WorldNormal = MTACalcWorldNormal( VS.Normal );
    //--      PS.Diffuse = MTACalcGTAVehicleDiffuse( WorldNormal, VS.Diffuse );

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
    float4 finalColor = PS.Diffuse;
    //float4 finalColor = texel * PS.Diffuse;

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
        CullMode = 3;
        
    }
}
