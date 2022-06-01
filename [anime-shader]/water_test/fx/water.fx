//---------------------------------------------------------------------
// Include some common stuff
//---------------------------------------------------------------------
#include "mta-helper.fx"
//-- These two are set by MTA
texture gDepthBuffer : DEPTHBUFFER;
texture screenInput;
matrix gProjectionMainScene : PROJECTION_MAIN_SCENE;

sampler2D ScreenSampler = sampler_state
{
	Texture = <screenInput>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Mirror;
	AddressV = Mirror;
};


sampler SamplerDepth = sampler_state
{
    Texture     = (gDepthBuffer);
    AddressU    = Clamp;
    AddressV    = Clamp;
};


struct VSInput
{
    float4 Position : POSITION;
    float4 Diffuse  : COLOR0;
    float3 TexCoord : TEXCOORD0;
    float3 Normal : NORMAL0;
};
struct PSInput
{
    float4 Position : POSITION;
    float4 Diffuse  : COLOR0;
    float3 TexCoord : TEXCOORD0;
    float4 ScreenPos : TEXCOORD1;
    float4 WorldPosition : TEXCOORD2;
    float DistFade : TEXCOORD3;
    float4 ViewPosition: TEXCOORD4;
    float3 WorldNormal : TEXCOORD5;
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
float4 blendSeaColor(float4 col1,float4 col2)
{
    float4 col = min(1,1.5-col2.a)*col1+col2.a*col2;
    return col;
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

float3 swell( float3 pos,float anisotropy){
    float3 normal;
    float height = noise(pos.xy,0);
    height *= anisotropy ;//使距离地平线近的区域的海浪高度降低
    normal = normalize(
        cross (
            float3(0,ddy(height),1),
            float3(1,ddx(height),0)
        )//两片元间高度差值得到梯度
    );
    return normal;
}



PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    //-- Calculate screen pos of vertex
    /*
    matrix projection = mul(gWorldViewProjection, gWorld);
	projection = mul(gWorld, projection);
    */

    PS.WorldPosition = mul(VS.Position, gWorld);
	float4 viewPos = mul(PS.WorldPosition , gView);

    PS.Position = mul(viewPos, gProjection);


	PS.TexCoord = VS.TexCoord;

    PS.Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );

    PS.ScreenPos = MTACalcScreenPosition(VS.Position.xyz);


    float DistanceFromCamera = MTACalcCameraDistance( gCameraPosition,PS.WorldPosition );
    PS.DistFade = DistanceFromCamera;
    //PS.DistFade = MTAUnlerp ( 500, 0, DistanceFromCamera );


    PS.ViewPosition = mul(VS.Position, gWorldViewProjection);
    PS.WorldNormal = MTACalcWorldNormal(VS.Normal);
    return PS;
}


float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float4 col = float4(1,1,1,1);

    const float4 phases = float4(0.28, 0.50, 0.07, 0);//周期
    const float4 amplitudes = float4(4.02, 0.34, 0.65, 0);//振幅
    const float4 frequencies = float4(0.00, 0.48, 0.08, 0);//频率
    const float4 offsets = float4(0.00, 0.16, 0.00, 0);//相位
    //Water Depth
    float depth = PS.ViewPosition.z / PS.ViewPosition.w;
    float2 txcoord = (PS.ViewPosition.xy / PS.ViewPosition.w) * float2(0.5, -0.5) + 0.5;
    float cameraDepth = max(0.915, fetchDepthBufferValue(txcoord));
    depth = 1.0 / (1 - depth);
    float planardepth = 1.0 / (1 - cameraDepth);
	float waterDepth = min(20, planardepth - depth);
    //Generate Base Color
    float diffZ = (planardepth - depth)/30;
    float4 waterBaseColor = cosine_gradient(saturate(1-diffZ), phases, amplitudes, frequencies, offsets);

    col = waterBaseColor;
    //Generate Wave Nosie Normal
    float3 worldViewDir = normalize(gCameraPosition.xyz-PS.WorldPosition.xyz);
    //通过临近像素点间摄像机到片元位置差值来计算哪里是接近地平线的部分
    float3 v = PS.WorldPosition.xyz - gCameraPosition;
    float anisotropy = saturate(1/ddy(length(v.xz))  );
    
    float3 swelledNormal = swell( PS.WorldPosition.xyz,50);

    //Generate Reflection ..
    //float screenColor = tex2D(ScreenSampler,PS.TexCoord);
    //nuv = nuv + normalMap.xy
    float3 reflDir = reflect(-worldViewDir, swelledNormal);
    float4 reflectionColor = float4(1,1,1,1);
    


    //Do Fresnel
    float vReflect =  pow( 1-dot(worldViewDir,swelledNormal),5);
    vReflect = saturate(vReflect) ;

    col = lerp(col , reflectionColor , vReflect) ;
    col.a = saturate(diffZ);

    //col.rgb = swelledNormal;
    return col;
}


//--------------------------------------------------------------------------------------------
//-- Techniques
//--------------------------------------------------------------------------------------------
technique tec
{
    pass P0
    {
  
        SrcBlend = SRCALPHA; 
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}
