//---------------------------------------------------------------------
// Include some common stuff
//---------------------------------------------------------------------
#include "mta-helper.fx"
//-- These two are set by MTA
texture gDepthBuffer : DEPTHBUFFER;
matrix gProjectionMainScene : PROJECTION_MAIN_SCENE;

sampler SamplerDepth = sampler_state
{
    Texture     = (gDepthBuffer);
    AddressU    = Clamp;
    AddressV    = Clamp;
};


struct VSInput
{
    float3 Position : POSITION;
    float4 Diffuse  : COLOR0;
    float3 TexCoord : TEXCOORD0;
};
struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse  : COLOR0;
    float3 TexCoord : TEXCOORD0;
    float4 ScreenPos : TEXCOORD1;
    float DistFade : TEXCOORD3;
};

float fetchDepthBufferValue( float2 uv )
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

float linearize(float posZ)
{
    return gProjectionMainScene[3][2] / (posZ - gProjectionMainScene[2][2]);
}
float4 cosine_gradient(float x,  float4 phase, float4 amp, float4 freq, float4 offset)
{
    float TAU = 2. * 3.14159265;
    phase *= TAU;
    x *= TAU;

    return float4(
        offset.r + amp.r * 0.5 * cos(x * freq.r + phase.r) + 0.5,
        offset.g + amp.g * 0.5 * cos(x * freq.g + phase.g) + 0.5,
        offset.b + amp.b * 0.5 * cos(x * freq.b + phase.b) + 0.5,
        offset.a + amp.a * 0.5 * cos(x * freq.a + phase.a) + 0.5
    );
}
float2 rand(float2 st, int seed)
{
    float2 s = float2(dot(st, float2(127.1, 311.7)) + seed, dot(st, float2(269.5, 183.3)) + seed);
    return -1 + 2 * frac(sin(s) * 43758.5453123);
}
    
float noise(float2 st, int seed)
{
    st.y += gTime;

    float2 p = floor(st);
    float2 f = frac(st);

    float w00 = dot(rand(p, seed), f);
    float w10 = dot(rand(p + float2(1, 0), seed), f - float2(1, 0));
    float w01 = dot(rand(p + float2(0, 1), seed), f - float2(0, 1));
    float w11 = dot(rand(p + float2(1, 1), seed), f - float2(1, 1));
    
    float2 u = f * f * (3 - 2 * f);

    return lerp(lerp(w00, w10, u.x), lerp(w01, w11, u.x), u.y);
}

float3 swell(float3 normal , float3 pos , float anisotropy)
{
    float height = noise(pos.xz * 0.1,0);
    height *= anisotropy ;
    normal = normalize(
        cross ( 
            float3(0,ddy(height),1),
            float3(1,ddx(height),0)
        )
    );
    return normal;
}



PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    //-- Calculate screen pos of vertex
    PS.Position = mul(float4(VS.Position.xyz,1), gWorldViewProjection);

    //-- Pass through tex coord
    //PS.TexCoord = VS.TexCoord;
    // compute the eye vector 
    float4 pPos = mul(VS.Position, gWorldViewProjection); 
	PS.TexCoord.x = (0.5 * (pPos.w + pPos.x));
	PS.TexCoord.y = (0.5 * (pPos.w - pPos.y));
	PS.TexCoord.z = pPos.w;


    //-- Calculate GTA lighting for buildings
    PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );
    //--
    //-- NOTE: The above line is for GTA buildings.
    //-- If you are replacing a vehicle texture, do this instead:
    //--
    //--      // Calculate GTA lighting for vehicles
    //--      float3 WorldNormal = MTACalcWorldNormal( VS.Normal );
    //--      PS.Diffuse = MTACalcGTAVehicleDiffuse( WorldNormal, VS.Diffuse );
    PS.ScreenPos = MTACalcScreenPosition(VS.Position);

    float DistanceFromCamera = MTACalcCameraDistance( gCameraPosition,MTACalcWorldPosition( VS.Position.xyz ) );
    PS.DistFade = DistanceFromCamera;
    return PS;
}



float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    // Get Screen space normals
    //float4 normalInput = tex2D(NormalSampler,PS.TexCoord.xy);
    
    //float sceneZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)));
    float gDepthFactor =0.03f;

    float3 projcoord = float3((PS.TexCoord.xy / PS.TexCoord.z),0) ;
    float bufferValue= linearize(fetchDepthBufferValue(PS.TexCoord))*gDepthFactor;
    
    float sceneZ = bufferValue;
    float partZ = PS.ScreenPos.z;
    float diffZ = saturate( (sceneZ - partZ)/5.0f);//片元深度与场景深度的差值
    const float4 phases = float4(0.28, 0.50, 0.07, 0);//周期
    const float4 amplitudes = float4(4.02, 0.34, 0.65, 0);//振幅
    const float4 frequencies = float4(0.00, 0.48, 0.08, 0);//频率
    const float4 offsets = float4(0.00, 0.16, 0.00, 0);//相位
    //按照距离海滩远近叠加渐变色
    float4 cos_grad = cosine_gradient(saturate(1.5-bufferValue), phases, amplitudes, frequencies, offsets);
    cos_grad = clamp(cos_grad, 0, 1);


    PS.Diffuse = cos_grad;
    return PS.Diffuse;
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
