#include "mta-helper.fx"

// Cell related
float3 LightColor = float3(0.7, 0.7, 0.8);

//float3 ShadowColor = float3(0.7, 0.7, 0.8);
float LightStrength =0.8;
//float ShadowStrength = 0.74;
float ShadowRange = 0.1;
float ShadowSmooth = 0.1;
float ShadowMutiplier = 0.9;
float3 sunDirection = float3(1,0,0);
float sunSize = 1;
float4 LineColor = float4(1,1,1,1);
// Outline related
float LineThickness = 0.0012;
float LineDepth = 0.2;
// Rim Lighting
float RimMin = 0.8;
float RimMax = 1;
float RimSmooth =0.01;
float RimLightInten = 1;
bool isClear = true;
sampler MainTex  = sampler_state
{
    Texture = <gTexture0>;
};

struct VSInput
{
    float4 Position : POSITION0;
    float3 Normal : NORMAL;
    float4 Diffuse : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float4 Rim : COLOR1;
    float2 TexCoord : TEXCOORD0;
    float3 Normal : TEXCOORD1;
};

float map(float value, float min1, float max1, float min2, float max2) {
    float perc = (value - min1) / (max1 - min1);
    float v = perc * (max2 - min2) + min2;
    v = v > max2 ? max2 : v;
    v = v < min2 ? min2 : v;
    return v;
}

float4 RimLightVertexColorShader(VSInput VS)
{
    // rim
    MTAFixUpNormal( VS.Normal );
    float4 worldPosition = mul(VS.Position, gWorld);
    float4 viewPosition = mul(worldPosition, gView);
    float4 Position = mul(viewPosition, gProjection);

    // Fake tangent and binormal
    float3 Tangent = VS.Normal.yxz;
    Tangent.xz = VS.TexCoord.xy;
    float3 Binormal = normalize( cross(Tangent, VS.Normal) );
    Tangent = normalize( cross(Binormal, VS.Normal) );
	
    Tangent = mul(Tangent, gWorldInverseTranspose);
    Binormal = mul(-Binormal, gWorldInverseTranspose);
    float3 Normal = mul(VS.Normal, gWorldInverseTranspose);
    
    float3 CamInWorld = normalize(gCameraPosition - worldPosition.xyz);
    float3 WorldPos = worldPosition.xyz;
    float3 View = normalize(CamInWorld - normalize(gCameraDirection));
    //float3 View = normalize(-sunDirection - normalize(gCameraDirection));
    float4 Diffuse = MTACalcGTABuildingDiffuse( VS.Diffuse );
    //float4 RimLightColor  =float4(1,1,1,1);
    float4 RimLightColor  = float4(LightColor,1);
  
    // Use static rim
    //float4 Fresnel = (1-saturate(pow(saturate(dot(Normal,View )),RimLightInten)))*RimLightColor*RimLightInten;

    float4 Fresnel = (1-saturate(pow(saturate(dot(Normal,View )),RimLightInten)));
    Fresnel = smoothstep(RimMin,RimMax, Fresnel);
    Fresnel = smoothstep(0, RimSmooth, Fresnel );

    //bloom
    float interp = isClear ? map(sunSize, 1, 8,0,1) : 0;
    float3 worldNormal = normalize(View);
    float3 worldLightDir = normalize(-sunDirection.xyz);
    float NdotL = max(0, dot(worldNormal, worldLightDir));
    float rimBloom = pow (Fresnel, 1)  * NdotL;
    Fresnel *= rimBloom *RimLightColor*RimLightInten * interp;
    return Fresnel;
}

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS; 
    MTAFixUpNormal( VS.Normal );
    float4 worldPos = mul(float4(VS.Position.xyz,1), gWorld );	
    float4 viewPos = mul( worldPos , gView );
    float4 projPos = mul( viewPos, gProjection);
    PS.Position = projPos;


    PS.TexCoord = VS.TexCoord;


   
    PS.Normal = mul(VS.Normal, (float3x3)gWorld);
    PS.Diffuse =MTACalcGTACompleteDiffuse(PS.Normal, VS.Diffuse);

    // add rim light
    PS.Rim = RimLightVertexColorShader(VS);
    return PS;
}


float4 PixelShaderFunction(PSInput PS): COLOR
{
 
    float4 col = 1;
    float4 mainTex  = tex2D(MainTex, PS.TexCoord) ;
    //float3 worldNormal = normalize(PS.Position);
    float3 worldLightDir = normalize(-sunDirection.xyz);
    //float3 worldLightDir = sunDirection;
    float halfLambert = dot(PS.Normal, -worldLightDir);
    halfLambert += pow(halfLambert * 0.5 + 0.5,1.5);

    
    
    //float light = sunSize < 1 ? 0.5 : sunSize > 1 ? 1 : sunSize;
    //float light = map(sunSize, 1, 3,0,1);
    float rampInterp = isClear ? map(sunSize, 1, 5,0,1) : 0;
    float ramp = smoothstep(0, ShadowSmooth, halfLambert - ShadowRange);

    float3 Color =  LightColor *  LightStrength;
    float ShadowStrength =   LightStrength  * ShadowMutiplier;
    float3 diffuse = lerp(Color * ShadowStrength,Color, ramp * rampInterp) ;

    //col.rgba = PS.Rim ;

    col.rgb = mainTex.rgb * diffuse;
    //col.a = PS.Diffuse.a;
    col.a = mainTex.a == 0 ? 0 : PS.Diffuse.a;
    col.rgba += PS.Rim;
    
    return col;
}


float3 TransformViewToProjection (float3 v) {
    return mul((float3x3)gProjection, v);
}
float2 TransformViewToProjection (float2 v) {
    return mul((float2x2)gProjection, v);
}

PSInput OutlineVertexShader(VSInput input)
{
    PSInput output = (PSInput)0;
    float4 original = mul(mul(mul(input.Position, gWorld), gView), gProjection);
    float4 normal = mul(mul(mul(input.Normal, gWorld), gView), gProjection);


    //float3 extendDir = mul(MTACalcWorldPosition(input.Position), normal);
    float2 extendDir = normalize(TransformViewToProjection(original.xy));

    output.Position = original + (mul(LineThickness, normal));
    output.Position.xy += extendDir * (output.Position.w * LineThickness ); 

    return output;
}

float4 OutlinePixelShader(PSInput input) : COLOR0
{
    float4 color = tex2D(MainTex, input.TexCoord) * LineColor * LineDepth;
    
    return color;
}

technique tec{

    pass P1
    {
        MultiSampleAntialias = 1;
        //FillMode = 2;
        CullMode = 2;
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
        
    }

    pass P2
    {

        VertexShader = compile vs_2_0 OutlineVertexShader();
        PixelShader = compile ps_2_0 OutlinePixelShader();
        CullMode = 3;

    }
}

technique fallback
{
    pass P0
    {
        // Just draw normally
    }
}