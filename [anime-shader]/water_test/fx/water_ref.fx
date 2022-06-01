// Author: Ren712/AngerMAN
// Water_refract 2.6

texture sReflectionTexture;
texture sRandomTexture;
float4 sWaterColor = float4(90 / 255.0, 170 / 255.0, 170 / 255.0, 240 / 255.0 );
float3 sSkyColorTop = float3(0,0,0);
float3 sSkyColorBott = float3(0,0,0);

float gBuffAlpha = 0.26;
float normalMult =0.5;
float flowSpeed = 0.5;
float xval = 0.0;
float yval = 0.0;
float xzoom = 1;
float yzoom = 1;

float gDepthFactor =0.03f;
#include "mta-helper.fx"
texture gDepthBuffer : DEPTHBUFFER;
matrix gProjectionMainScene : PROJECTION_MAIN_SCENE;

//---------------------------------------------------------------------
//-- Sampler for the main texture (needed for pixel shaders)
//---------------------------------------------------------------------

sampler2D colorMapSampler = sampler_state
{
    Texture = (gTexture0);
	MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
};

sampler2D RandomSampler = sampler_state
{
   Texture = (sRandomTexture);
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
   MIPMAPLODBIAS = 0.000000;
};

sampler SamplerDepth = sampler_state
{
    Texture     = (gDepthBuffer);
    AddressU    = Clamp;
    AddressV    = Clamp;
};

samplerCUBE ReflectionSampler = sampler_state
{
   Texture = (sReflectionTexture);
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
   MIPMAPLODBIAS = 0.000000;
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
	float4 Diffuse : COLOR1;
	float4 SparkleTex : TEXCOORD1;
	float3 WorldPos : TEXCOORD2;
	float DistFade : TEXCOORD3;
};

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
    st.y += gTime*flowSpeed;

    float2 p = floor(st);
    float2 f = frac(st);

    float w00 = dot(rand(p, seed), f);
    float w10 = dot(rand(p + float2(1, 0), seed), f - float2(1, 0));
    float w01 = dot(rand(p + float2(0, 1), seed), f - float2(0, 1));
    float w11 = dot(rand(p + float2(1, 1), seed), f - float2(1, 1));

    float2 u = f * f * (3 - 2 * f);

    return lerp(lerp(w00, w10, u.x), lerp(w01, w11, u.x), u.y);
}
//海浪的涌起法线计算
float3 swell( float3 pos , float anisotropy){
    float3 normal;
    float height = noise(pos.xz * 0.1,0);
    height *= anisotropy ;//使距离地平线近的区域的海浪高度降低
    normal = normalize(
        cross ( 
            float3(0,ddy(height),1),
            float3(1,ddx(height),0)
        )//两片元间高度差值得到梯度
    );
    return normal;
}

//-----------------------------------------------------------------------------
//-- VertexShader
//-----------------------------------------------------------------------------
PSInput VertexShaderSB(VSInput VS)
{
    PSInput PS = (PSInput)0;
 
    // Position in screen space.
	PS.Position = mul(float4(VS.Position.xyz , 1.0), gWorldViewProjection);

	float4 pPos = mul(VS.Position, gWorldViewProjection); 
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
	
	// Calculate GTA lighting for buildings
    PS.Diffuse =MTACalcGTABuildingDiffuse( VS.Diff );

 	float DistanceFromCamera = MTACalcCameraDistance( gCameraPosition,MTACalcWorldPosition( VS.Position.xyz ) );
    PS.DistFade = MTAUnlerp ( 580, 0, DistanceFromCamera );
 
    return PS;
}


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
//-- PixelShader
//-----------------------------------------------------------------------------
float4 PixelShaderSB(PSInput PS) : COLOR0
{
    float brightnessFactor = 10;

    float3 vFlakesNormal = tex2D(RandomSampler, PS.SparkleTex.xy);
    //float3 v =PS.WorldPos.xyz - gCameraPosition;
   // float anisotropy = saturate(1/ddy(length(v.xz))/10);//通过临近像素点间摄像机到片元位置差值来计算哪里是接近地平线的部分

    //float3 vFlakesNormal = swell(PS.WorldPos,anisotropy).rgb;
    float3 vFlakesNormal2 = tex2D(RandomSampler, PS.SparkleTex.zw);

    vFlakesNormal = (vFlakesNormal + vFlakesNormal2 ) /2 ;
    vFlakesNormal = 2 * vFlakesNormal-1.0;
    float3 fvNormal = normalize(float3(vFlakesNormal.x * normalMult, vFlakesNormal.y * normalMult, vFlakesNormal.z)); 	

	float3 projcoord = float3((PS.TexCoord.xy / PS.TexCoord.z),0) ;
    float3 norNor = (fvNormal.x * float3(1,0,0) + fvNormal.y * float3(0,1,0));	
    projcoord.xy += norNor.xy;	
    projcoord.xy += float2(xval,yval);
    projcoord.xy *= float2(xzoom,yzoom);
    
   



	float BufferValue= Linearize(FetchDepthBufferValue(projcoord.xy))*gDepthFactor;
	float diffZ =  (PS.DistFade - BufferValue);//片元深度与场景深度的差值

    const float4 phases = float4(0.28, 0.50, 0.07, 0);//周期
    const float4 amplitudes = float4(4.02, 0.34, 0.65, 0);//振幅
    const float4 frequencies = float4(0.00, 0.48, 0.08, 0);//频率
    const float4 offsets = float4(0.00, 0.16, 0.00, 0);//相位

    //按照距离海滩远近叠加渐变色
    float4 cos_grad = cosine_gradient(saturate(1-BufferValue), phases, amplitudes, frequencies, offsets);

    
    
    float3 refracColor = cos_grad.rgb;
	float4 reflection=float4(refracColor,1)*gBuffAlpha;
	reflection.rgb*=reflection.a;
	reflection.rgb*= brightnessFactor;
    reflection *=saturate(PS.DistFade);
	reflection *=pow(PS.Diffuse,0.3)/4;

     
   

    // Calc Sky color reflection
    float3 cameraDirection = float3(gCameraDirection.xy,saturate(gCameraDirection.z));
    float3 h = normalize(normalize(gCameraPosition - PS.WorldPos.xyz) - normalize(cameraDirection));
    float vdn = saturate(pow(saturate(dot(h,vFlakesNormal)), 1));
    float3 skyColorTop = lerp(0,sSkyColorTop,vdn);	
    float3 skyColorBott = lerp(0,sSkyColorBott,vdn);
    float3 skyColor = lerp(skyColorBott,skyColorTop,saturate(PS.DistFade));	
	
	float4 finalColor =1;
    finalColor = saturate(reflection + cos_grad * 0.6) ;
    finalColor.rgb += skyColor *0.18;
    //finalColor += reflection;
    finalColor.a = PS.Diff.a * 0.5;

    return finalColor;
	
}

float4 PixelShaderNonB(PSInput PS) : COLOR0
{


    float brightnessFactor = 0.10;
    float glossLevel = 0.00;

    // Get the surface normal
    float3 vNormal = float3(0,0,1);

    // Micro-flakes normal map is a high frequency normalized
    // vector noise map which is repeated across the surface.
    // Fetching the value from it for each pixel allows us to
    // compute perturbed normal for the surface to simulate
    // appearance of micro-flakes suspended in the coat of paint:
    float3 vFlakesNormal = tex2D(RandomSampler, PS.SparkleTex.xy).rgb;
    float3 vFlakesNormal2 = tex2D(RandomSampler, PS.SparkleTex.zw).rgb;

    vFlakesNormal = (vFlakesNormal + vFlakesNormal2 ) / 2;

    // Don't forget to bias and scale to shift color into [-1.0, 1.0] range:
    vFlakesNormal = 2 * vFlakesNormal - 1.0;

    // To compute the surface normal for the second layer of micro-flakes, which
    // is shifted with respect to the first layer of micro-flakes, we use this formula:
    // Np2 = ( c * Np + d * N ) / || c * Np + d * N || where c == d
    float3 vNp2 = ( vFlakesNormal + vNormal ) ;

    // The view vector (which is currently in world space) needs to be normalized.
    // This vector is normalized in the pixel shader to ensure higher precision of
    // the resulting view vector. For this highly detailed visual effect normalizing
    // the view vector in the vertex shader and simply interpolating it is insufficient
    // and produces artifacts.
    float3 vView = normalize( gCameraPosition - PS.WorldPos.xyz );

    // Transform the surface normal into world space (in order to compute reflection
    // vector to perform environment map look-up):
    float3 vNormalWorld = vNormal;

    // Compute reflection vector resulted from the clear coat of paint on the metallic
    // surface:
    float fNdotV = saturate(dot( vNormalWorld, vView));
    float3 vReflection = 2 * vNormalWorld * fNdotV - vView;

    // Hack in some bumpyness
    vReflection += vNp2;

    // Calc Sky color reflection
    float3 cameraDirection = float3(gCameraDirection.xy,saturate(gCameraDirection.z));
    float3 h = normalize(normalize(gCameraPosition - PS.WorldPos.xyz) - normalize(cameraDirection));
    float vdn = saturate(pow(saturate(dot(h,vNp2)), 1));
    float3 skyColorTop = lerp(0,sSkyColorTop,vdn);	
    float3 skyColorBott = lerp(0,sSkyColorBott,vdn);
    float3 skyColor = lerp(skyColorBott,skyColorTop,saturate(PS.DistFade));	
	
    // Sample environment map using this reflection vector:
    float4 envMap = texCUBE( ReflectionSampler, vReflection );
    float envGray = (envMap.r + envMap.g + envMap.b)/3;
    envMap.rgb = float3(envGray,envGray,envGray);
    envMap.rgb = envMap.rgb * envMap.a;	
	
    // Brighten the environment map sampling result:
    envMap.rgb *= envMap.rgb;
    envMap.rgb *= brightnessFactor;
    envMap.rgb = saturate(envMap.rgb);
    float4 finalColor = 1;

    // Bodge in the water color
    finalColor =  PS.Diff * 0.5;
    finalColor += PS.Diff;
    finalColor.rgb += skyColor *0.18;
    finalColor.a = PS.Diffuse.a;
    return finalColor;
}

////////////////////////////////////////////////////////////
//////////////////////////////// TECHNIQUES ////////////////
////////////////////////////////////////////////////////////
technique Water_refract_2_1
{
    pass P0
    {
        AlphaBlendEnable = TRUE;
        AlphaRef = 1;
        VertexShader = compile vs_3_0 VertexShaderSB();
        PixelShader = compile ps_3_0 PixelShaderSB();
    }
}

technique Water_simple
{
    pass P0
    {
        AlphaBlendEnable = TRUE;
        AlphaRef = 1;
        VertexShader = compile vs_2_0 VertexShaderSB();
        PixelShader = compile ps_2_0 PixelShaderNonB();
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
