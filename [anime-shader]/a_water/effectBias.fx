//
// taken from shader_soft_particles
//

//-----------------------------------------------------------------------------
// Effect Settings
//-----------------------------------------------------------------------------
float fDepthSpread = 1.0;
float fDistMult = 1.0;
float fDistAdd = -1.5;
texture gTexture0 < string textureState="0,Texture"; >;

//-----------------------------------------------------------------------------
// Include some common stuff
//-----------------------------------------------------------------------------

float4x4 gWorld : WORLD;
float4x4 gView : VIEW;
float4x4 gProjection : PROJECTION;
float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;
texture gDepthBuffer : DEPTHBUFFER;
matrix gProjectionMainScene : PROJECTION_MAIN_SCENE;
float3 gCameraPosition : CAMERAPOSITION;

//-----------------------------------------------------------------------------
// Sampler Inputs
//-----------------------------------------------------------------------------

sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
};

sampler SamplerDepth = sampler_state
{
    Texture     = (gDepthBuffer);
    AddressU    = Clamp;
    AddressV    = Clamp;
};

//-----------------------------------------------------------------------------
// Structure of data sent to the vertex shader
//-----------------------------------------------------------------------------
struct VSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

//-----------------------------------------------------------------------------
// Structure of data sent to the pixel shader ( from the vertex shader )
//-----------------------------------------------------------------------------
struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
    float3 TexCoordProj : TEXCOORD1;
    float2 DistFromCam : TEXCOORD2;
};

//-----------------------------------------------------------------------------
//-- Get value from the depth buffer
//-- Uses define set at compile time to handle RAWZ special case (which will use up a few more slots)
//-----------------------------------------------------------------------------
float FetchDepthBufferValue( float2 uv )
{
    float4 texel = tex2D(SamplerDepth, uv);
#if IS_DEPTHBUFFER_RAWZ
    float3 rawval = floor(255.0 * texel.arg + 0.5);
    float3 valueScaler = float3(0.996093809371817670572857294849, 0.0038909914428586627756752238080039, 1.5199185323666651467481343000015e-5);
    return dot(rawval, valueScaler / 255.0);
#else
    return texel.r;
#endif
}
 
//-----------------------------------------------------------------------------
//-- Use the last scene projecion matrix to linearize the depth value a bit more
//-----------------------------------------------------------------------------
float Linearize(float posZ)
{
    return gProjectionMainScene[3][2] / (posZ - gProjectionMainScene[2][2]);
}

//-----------------------------------------------------------------------------
// VertexShaderFunction
//  1. Read from VS structure
//  2. Process
//  3. Write to PS structure
//-----------------------------------------------------------------------------
PSInput VertexShaderFunctionDB(VSInput VS)
{
    PSInput PS = (PSInput)0;

    float4 worldPosition = mul(float4(VS.Position.xyz, 1.0),gWorld);
    float4 worldViewPosition = mul(worldPosition,gView);

    PS.DistFromCam = worldViewPosition.z/worldViewPosition.w;
	
    PS.Position = mul(worldViewPosition,gProjection);
    PS.TexCoord = VS.TexCoord;
    PS.Diffuse = VS.Diffuse;

    float4 pPos = mul( VS.Position, gWorldViewProjection ); 
    float projectedX = (0.5 * ( pPos.w + pPos.x ) );
    float projectedY = (0.5 * ( pPos.w - pPos.y ) );
    PS.TexCoordProj.xy = float2( projectedX, projectedY );
    PS.TexCoordProj.z = pPos.w;
    return PS;
}

//-----------------------------------------------------------------------------
//-- PixelShaderExample
//--  1. Read from PS structure
//--  2. Process
//--  3. Return pixel color
//-----------------------------------------------------------------------------
float4 PixelShaderFunctionDB(PSInput PS) : COLOR0
{
    float2 TexCoordProj = PS.TexCoordProj.xy / PS.TexCoordProj.z;
    TexCoordProj += float2( 0.0006, 0.0009 );
    float BufferValue = FetchDepthBufferValue( TexCoordProj );
    float depth = Linearize( BufferValue );
    float fade = saturate( ( depth - ( PS.DistFromCam + fDistAdd ) * fDistMult ) * fDepthSpread);
    float4 color = tex2D(Sampler0, PS.TexCoord);
    color *= PS.Diffuse;
    color.a *= fade;
    return color;
}

//-----------------------------------------------------------------------------
// Techniques
//-----------------------------------------------------------------------------
technique soft_particles_replace
{
    pass P0
    {
        AlphaBlendEnable = TRUE;
        AlphaRef = 1;
        ZEnable = FALSE;
        VertexShader = compile vs_2_0 VertexShaderFunctionDB();
        PixelShader = compile ps_2_0 PixelShaderFunctionDB();
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
