#include "SMAAUtils.fx"

texture ScnMap;
sampler ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};

struct InputSMAAEdgeDetectionVS
{
	float4 Position : POSITION0;
	float3 TexCoord : TEXCOORD0;
};

struct OutputSMAAEdgeDetectionVS
{
	float4 Position  : POSITION0;
	float3 TexCoord  : TEXCOORD0;
	
	float4 oTexcoord0  : TEXCOORD1;
	float4 oTexcoord1  : TEXCOORD2;
	float4 oTexcoord2  : TEXCOORD3;
	float4 oTexcoord3  : TEXCOORD4;
};

OutputSMAAEdgeDetectionVS SMAAEdgeDetectionVS(InputSMAAEdgeDetectionVS input)
{
	OutputSMAAEdgeDetectionVS output = (OutputSMAAEdgeDetectionVS)0;
	
	output.Position  = mul(input.Position, gWorldViewProjection);
	output.TexCoord  = input.TexCoord;
	
	output.oTexcoord0 = input.TexCoord.xyxy + ViewportOffset.xyxy;
	output.oTexcoord1 = output.oTexcoord0 + ViewportOffset2.xyxy * float4(-1.0, 0.0, 0.0, -1.0);
	output.oTexcoord2 = output.oTexcoord0 + ViewportOffset2.xyxy * float4( 1.0, 0.0, 0.0,  1.0);
	output.oTexcoord3 = output.oTexcoord0 + ViewportOffset2.xyxy * float4(-2.0, 0.0, 0.0, -2.0);
	
	return output;
}

float4 SMAALumaEdgeDetectionPS(OutputSMAAEdgeDetectionVS input) : COLOR0
{
	float4 offset[3] = { input.oTexcoord1, input.oTexcoord2, input.oTexcoord3 };
	float2 threshold = float2(SMAA_THRESHOLD, SMAA_THRESHOLD);

	float Lcenter   = luminance(tex2Dlod(ScnSamp, float4(input.oTexcoord0.xy, 0, 0)).rgb);
	float Lleft     = luminance(tex2Dlod(ScnSamp, float4(offset[0].xy, 0, 0)).rgb);
	float Ltop      = luminance(tex2Dlod(ScnSamp, float4(offset[0].zw, 0, 0)).rgb);
	float Lright    = luminance(tex2Dlod(ScnSamp, float4(offset[1].xy, 0, 0)).rgb);
	float Lbottom   = luminance(tex2Dlod(ScnSamp, float4(offset[1].zw, 0, 0)).rgb);
	float Lleftleft = luminance(tex2Dlod(ScnSamp, float4(offset[2].xy, 0, 0)).rgb);
	float Ltoptop   = luminance(tex2Dlod(ScnSamp, float4(offset[2].zw, 0, 0)).rgb);

	float4 delta = abs(Lcenter - float4(Lleft, Ltop, Lright, Lbottom));
	float2 edges = step(threshold, delta.xy);
	clip(dot(edges, 1) - 1e-5);

	float2 maxDelta = max(delta.xy, delta.zw);
	maxDelta = max(maxDelta.xx, maxDelta.yy);
	maxDelta = max(maxDelta.xy, abs(float2(Lleft, Ltop) - float2(Lleftleft, Ltoptop)));
	
	return float4(edges * step(maxDelta * 0.5, delta.xy), 0.0, 0.0);
}

technique SMAA
{
	pass SMAAEdgeDetection 
	{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		
		VertexShader = compile vs_3_0 SMAAEdgeDetectionVS();
		PixelShader  = compile ps_3_0 SMAALumaEdgeDetectionPS();
	}
}