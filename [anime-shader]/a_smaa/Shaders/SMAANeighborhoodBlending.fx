#include "SMAAUtils.fx"

texture ScnMap;
sampler ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};

texture SMAABlendMap;
sampler SMAABlendMapSamp = sampler_state {
	texture = <SMAABlendMap>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
	AddressU  = CLAMP;  AddressV = CLAMP; MaxMipLevel = 0; MipMapLodBias = 0;
};

struct InputSMAANWCalculationVS
{
	float4 Position : POSITION0;
	float3 TexCoord : TEXCOORD0;
};

struct OutputSMAANWCalculationVS
{
	float4 Position  : POSITION0;
	float3 TexCoord  : TEXCOORD0;
	
	float2 oTexcoord0  : TEXCOORD1;
	float4 oTexcoord1  : TEXCOORD2;
};

OutputSMAANWCalculationVS SMAANeighborhoodBlendingVS(InputSMAANWCalculationVS input)
{   
	OutputSMAANWCalculationVS output = (OutputSMAANWCalculationVS)0;
	
	output.Position  = mul(input.Position, gWorldViewProjection);
	output.TexCoord  = input.TexCoord;

	float2 coord = input.TexCoord + ViewportOffset;
	
	output.oTexcoord0 = coord.xyxy;
	output.oTexcoord1 = coord.xyxy + ViewportOffset2.xyxy * float4(1.0, 0.0, 0.0, 1.0);
	
	return output;
}

float4 SMAANeighborhoodBlendingPS(OutputSMAANWCalculationVS input) : COLOR0
{
	float4 a;
	a.x = tex2Dlod(SMAABlendMapSamp, float4(input.oTexcoord1.xy, 0, 0)).a;
	a.y = tex2Dlod(SMAABlendMapSamp, float4(input.oTexcoord1.zw, 0, 0)).g;
	a.wz = tex2Dlod(SMAABlendMapSamp, float4(input.oTexcoord0, 0, 0)).xz;

	[branch]
	if (dot(a, 1) < 1e-5) 
	{
		float4 color = tex2Dlod(ScnSamp, float4(input.oTexcoord0, 0, 0));
		return float4(color.rgb, 1);
	}
	else 
	{
		bool h = max(a.x, a.z) > max(a.y, a.w);

		float4 blendingOffset = float4(0.0, a.y, 0.0, a.w);
		float2 blendingWeight = a.yw;
		SMAAMovc(bool4(h, h, h, h), blendingOffset, float4(a.x, 0.0, a.z, 0.0));
		SMAAMovc(bool2(h, h), blendingWeight, a.xz);
		blendingWeight /= dot(blendingWeight, 1);

		float4 color = 0;
		color += blendingWeight.x * tex2Dlod(ScnSamp, float4(input.oTexcoord0 + ViewportOffset2 * blendingOffset.xy, 0, 0));
		color += blendingWeight.y * tex2Dlod(ScnSamp, float4(input.oTexcoord0 - ViewportOffset2 * blendingOffset.zw, 0, 0));

		return float4(color.rgb, 1);
	}
}

technique SMAA
{
	pass SMAANeighborhoodBlending
	{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;

		VertexShader = compile vs_3_0 SMAANeighborhoodBlendingVS();
		PixelShader  = compile ps_3_0 SMAANeighborhoodBlendingPS();
	}
}