#include "SMAAUtils.fx"

texture ScnMap;
sampler ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};

texture SMAAEdgeMap;
sampler SMAAEdgeMapSamp = sampler_state {
	texture = <SMAAEdgeMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU  = CLAMP;  AddressV = CLAMP; MaxMipLevel = 0; MipMapLodBias = 0;
};

texture SMAAAreaMap;
sampler SMAAAreaMapSamp = sampler_state
{
	texture = <SMAAAreaMap>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
	AddressU  = CLAMP; AddressV = CLAMP;
};

texture SMAASearchMap;
sampler SMAASearchMapSamp = sampler_state
{
	texture = <SMAASearchMap>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
	AddressU  = CLAMP; AddressV = CLAMP;
};

float SMAASearchLength(sampler searchTex, float2 e, float offset) 
{
	float2 scale = SMAA_SEARCHTEX_SIZE * float2(0.5, -1.0);
	scale += float2(-1.0,  1.0);
	scale *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;

	float2 bias = SMAA_SEARCHTEX_SIZE * float2(offset, 1.0);
	bias  += float2( 0.5, -0.5);
	bias *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;

	return tex2Dlod(searchTex, float4(madd(scale, e, bias), 0, 0)).r;
}

float SMAASearchXLeft(sampler edgesTex, sampler searchTex, float2 texcoord, float end) 
{
	float2 e = float2(0.0, 1.0);

	for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++)
	{
		e = tex2Dlod(edgesTex, float4(texcoord, 0, 0)).rg;
		texcoord -= ViewportOffset2 * float2(2.0, 0.0);
		if (!(texcoord.x > end && e.g > 0.8281 && e.r == 0.0)) break;
	}

	float offset = madd(-(255.0 / 127.0), SMAASearchLength(searchTex, e, 0.0), 3.25);
	return madd(ViewportOffset2.x, offset, texcoord.x);
}

float SMAASearchXRight(sampler edgesTex, sampler searchTex, float2 texcoord, float end) 
{
	float2 e = float2(0.0, 1.0);

	for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++)
	{
		e = tex2Dlod(edgesTex, float4(texcoord, 0, 0)).rg;
		texcoord += ViewportOffset2 * float2(2.0, 0.0);
		if (!(texcoord.x < end &&  e.g > 0.8281 && e.r == 0.0)) break;
	}

	float offset = madd(-(255.0 / 127.0), SMAASearchLength(searchTex, e, 0.5), 3.25);
	return madd(-ViewportOffset2.x, offset, texcoord.x);
}

float SMAASearchYUp(sampler edgesTex, sampler searchTex, float2 texcoord, float end) 
{
	float2 e = float2(1.0, 0.0);

	for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++)
	{
		e = tex2Dlod(edgesTex, float4(texcoord, 0, 0)).rg;
		texcoord -= ViewportOffset * float2(0.0, 2.0);
		if (!(texcoord.y > end && e.r > 0.8281 && e.g == 0.0)) break;
	}

	float offset = madd(-(255.0 / 127.0), SMAASearchLength(searchTex, e.gr, 0.0), 3.25);
	return madd(ViewportOffset.y, offset, texcoord.y);
}

float SMAASearchYDown(sampler edgesTex, sampler searchTex, float2 texcoord, float end) 
{
	float2 e = float2(1.0, 0.0);

	for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++)
	{
		e = tex2Dlod(edgesTex, float4(texcoord, 0, 0)).rg;
		texcoord += ViewportOffset * float2(0.0, 2.0);
		if (!(texcoord.y < end && e.r > 0.8281 && e.g == 0.0)) break;
	}

	float offset = madd(-(255.0 / 127.0), SMAASearchLength(searchTex, e.gr, 0.5), 3.25);
	return madd(-ViewportOffset.y, offset, texcoord.y);
}

float2 SMAAArea(sampler areaTex, float2 dist, float e1, float e2, float offset) 
{
	float2 texcoord = madd(float2(SMAA_AREATEX_MAX_DISTANCE, SMAA_AREATEX_MAX_DISTANCE), round(4.0 * float2(e1, e2)), dist);
	texcoord = madd(SMAA_AREATEX_PIXEL_SIZE, texcoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);
	texcoord.y = madd(SMAA_AREATEX_SUBTEX_SIZE, offset, texcoord.y);
	return tex2Dlod(areaTex, float4(texcoord, 0, 0)).ra;
}

#if SMAA_MAX_SEARCH_STEPS_DIAG

float2 SMAAAreaDiag(sampler areaTex, float2 dist, float2 e, float offset) 
{
	float2 texcoord = madd(float2(SMAA_AREATEX_MAX_DISTANCE_DIAG, SMAA_AREATEX_MAX_DISTANCE_DIAG), e, dist);
	texcoord = madd(SMAA_AREATEX_PIXEL_SIZE, texcoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);
	texcoord.x += 0.5;
	texcoord.y += SMAA_AREATEX_SUBTEX_SIZE * offset;
	return tex2Dlod(areaTex, float4(texcoord, 0, 0)).ra;
}

float2 SMAADecodeDiagBilinearAccess(float2 e) 
{
	e.r = e.r * abs(5.0 * e.r - 5.0 * 0.75);
	return round(e);
}

float4 SMAADecodeDiagBilinearAccess(float4 e) 
{
	e.rb = e.rb * abs(5.0 * e.rb - 5.0 * 0.75);
	return round(e);
}

float2 SMAASearchDiag1(sampler edgesTex, float2 texcoord, float2 dir, out float2 e) 
{
	float4 coord = float4(texcoord, -1.0, 1.0);
	float3 t = float3(ViewportOffset2.xy, 1.0);

	for (int i = 0; i < SMAA_MAX_SEARCH_STEPS_DIAG; i++)
	{
		if (!(coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) && coord.w > 0.9)) break;
		coord.xyz = madd(t, float3(dir, 1.0), coord.xyz);
		e = tex2Dlod(edgesTex, float4(coord.xy, 0, 0)).rg;
		coord.w = dot(e, float2(0.5, 0.5));
	}

	return coord.zw;
}

float2 SMAASearchDiag2(sampler edgesTex, float2 texcoord, float2 dir, out float2 e) 
{
	float4 coord = float4(texcoord, -1.0, 1.0);
	coord.x += 0.25 * ViewportOffset2.x;
	float3 t = float3(ViewportOffset2.xy, 1.0);

	for (int i = 0; i < SMAA_MAX_SEARCH_STEPS_DIAG; i++)
	{
		if (!(coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) && coord.w > 0.9)) break;
		coord.xyz = madd(t, float3(dir, 1.0), coord.xyz);
		e = tex2Dlod(edgesTex, float4(coord.xy, 0, 0)).rg;
		e = SMAADecodeDiagBilinearAccess(e);
		coord.w = dot(e, float2(0.5, 0.5));
	}

	return coord.zw;
}

float2 SMAACalculateDiagWeights(sampler edgesTex, sampler areaTex, float2 texcoord, float2 e, float4 subsampleIndices) 
{
	float2 weights = float2(0.0, 0.0);

	float4 d;
	float2 end;
	if (e.r > 0.0) 
	{
		d.xz = SMAASearchDiag1(edgesTex, texcoord, float2(-1.0,  1.0), end);
		d.x += float(end.y > 0.9);
	}
	else
	{
		d.xz = float2(0.0, 0.0);
	}

	d.yw = SMAASearchDiag1(edgesTex, texcoord, float2(1.0, -1.0), end);

	[branch]
	if (d.x + d.y > 2.0) 
	{
		float4 coords = madd(float4(-d.x + 0.25, d.x, d.y, -d.y - 0.25), ViewportOffset2.xyxy, texcoord.xyxy);
		
		float4 c;
		c.xy = tex2Dlod(edgesTex, float4(coords.xy + float2(-ViewportOffset2.x,  0), 0, 0)).rg;
		c.zw = tex2Dlod(edgesTex, float4(coords.zw + float2( ViewportOffset2.x,  0), 0, 0)).rg;
		c.yxwz = SMAADecodeDiagBilinearAccess(c.xyzw);
		
		float2 cc = madd(float2(2.0, 2.0), c.xz, c.yw);
		SMAAMovc(bool2(step(0.9, d.zw)), cc, float2(0.0, 0.0));
		
		weights += SMAAAreaDiag(areaTex, d.xy, cc, subsampleIndices.z);
	}

	d.xz = SMAASearchDiag2(edgesTex, texcoord, float2(-1.0, -1.0), end);
	if (tex2Dlod(edgesTex, float4(texcoord + float2(1, 0) * ViewportOffset2, 0, 0)).r > 0.0) 
	{
		d.yw = SMAASearchDiag2(edgesTex, texcoord, float2(1.0, 1.0), end);
		d.y += float(end.y > 0.9);
	}
	else
	{
		d.yw = float2(0.0, 0.0);
	}

	[branch]
	if (d.x + d.y > 2.0)
	{
		float4 coords = madd(float4(-d.x, -d.x, d.y, d.y), ViewportOffset2.xyxy, texcoord.xyxy);
		float4 c;
		c.x  = tex2Dlod(edgesTex, float4(coords.xy + float2(-1,  0) * ViewportOffset2, 0, 0)).g;
		c.y  = tex2Dlod(edgesTex, float4(coords.xy + float2( 0, -1) * ViewportOffset2, 0, 0)).r;
		c.zw = tex2Dlod(edgesTex, float4(coords.zw + float2( 1,  0) * ViewportOffset2, 0, 0)).gr;
		
		float2 cc = madd(float2(2.0, 2.0), c.xz, c.yw);
		SMAAMovc(bool2(step(0.9, d.zw)), cc, float2(0.0, 0.0));

		weights += SMAAAreaDiag(areaTex, d.xy, cc, subsampleIndices.w).gr;
	}

	return weights;
}
#endif

void SMAADetectHorizontalCornerPattern(sampler edgesTex, inout float2 weights, float4 texcoord, float2 d) 
{
#if SMAA_CORNER_ROUNDING
	float2 leftRight = step(d.xy, d.yx);
	float2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;

	rounding /= leftRight.x + leftRight.y;

	float2 factor = float2(1.0, 1.0);
	factor.x -= rounding.x * tex2Dlod(edgesTex, float4(texcoord.xy + float2(0,  1) * ViewportOffset2, 0, 0)).r;
	factor.x -= rounding.y * tex2Dlod(edgesTex, float4(texcoord.zw + float2(1,  1) * ViewportOffset2, 0, 0)).r;
	factor.y -= rounding.x * tex2Dlod(edgesTex, float4(texcoord.xy + float2(0, -2) * ViewportOffset2, 0, 0)).r;
	factor.y -= rounding.y * tex2Dlod(edgesTex, float4(texcoord.zw + float2(1, -2) * ViewportOffset2, 0, 0)).r;

	weights *= saturate(factor);
#endif
}

void SMAADetectVerticalCornerPattern(sampler edgesTex, inout float2 weights, float4 texcoord, float2 d) 
{
#if SMAA_CORNER_ROUNDING
	float2 leftRight = step(d.xy, d.yx);
	float2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;

	rounding /= leftRight.x + leftRight.y;

	float2 factor = float2(1.0, 1.0);
	factor.x -= rounding.x * tex2Dlod(edgesTex, float4(texcoord.xy + float2( 1, 0) * ViewportOffset2, 0, 0)).g;
	factor.x -= rounding.y * tex2Dlod(edgesTex, float4(texcoord.zw + float2( 1, 1) * ViewportOffset2, 0, 0)).g;
	factor.y -= rounding.x * tex2Dlod(edgesTex, float4(texcoord.xy + float2(-2, 0) * ViewportOffset2, 0, 0)).g;
	factor.y -= rounding.y * tex2Dlod(edgesTex, float4(texcoord.zw + float2(-2, 1) * ViewportOffset2, 0, 0)).g;

	weights *= saturate(factor);
#endif
}

struct InputSMAABWCalculationVS
{
	float4 Position : POSITION0;
	float3 TexCoord : TEXCOORD0;
};

struct OutputSMAABWCalculationVS
{
	float4 Position  : POSITION0;
	float3 TexCoord  : TEXCOORD0;
	
	float4 oTexcoord0  : TEXCOORD1;
	float4 oTexcoord1  : TEXCOORD2;
	float4 oTexcoord2  : TEXCOORD3;
	float4 oTexcoord3  : TEXCOORD4;
};

OutputSMAABWCalculationVS SMAABlendingWeightCalculationVS(InputSMAABWCalculationVS input)
{   
	OutputSMAABWCalculationVS output = (OutputSMAABWCalculationVS)0;
	
	output.Position  = mul(input.Position, gWorldViewProjection);
	output.TexCoord  = input.TexCoord;

	float2 coord = input.TexCoord.xy + ViewportOffset;
	output.oTexcoord0 = coord.xyxy * float4(1.0, 1.0, ViewportSize);
	output.oTexcoord1 = coord.xyxy + ViewportOffset2.xyxy * float4(-0.25, -0.125,  1.25, -0.125);
	output.oTexcoord2 = coord.xyxy + ViewportOffset2.xyxy * float4(-0.125, -0.25, -0.125,  1.25);
	output.oTexcoord3 = float4(output.oTexcoord1.xz, output.oTexcoord2.yw) + ViewportOffset2.xxyy * float4(-2.0, 2.0, -2.0, 2.0) * float(SMAA_MAX_SEARCH_STEPS);
	
	return output;
}

float4 SMAABlendingWeightCalculationPS(OutputSMAABWCalculationVS input) : COLOR0
{
	float4 weights = 0;
	float4 offset[3] = { input.oTexcoord1, input.oTexcoord2, input.oTexcoord3 };
	float4 subsampleIndices = float4(0, 0, 0, 0);
	float2 edge = tex2Dlod(SMAAEdgeMapSamp, float4(input.oTexcoord0.xy, 0, 0)).rg;
	
	clip(dot(edge, 1) - 1e-5);

	[branch]
	if (edge.g > 0.0)
	{
#if SMAA_MAX_SEARCH_STEPS_DIAG
		weights.rg = SMAACalculateDiagWeights(SMAAEdgeMapSamp, SMAAAreaMapSamp, input.oTexcoord0.xy, edge, subsampleIndices);

		[branch]
		if (dot(weights.rg, 1.0) == 0.0) 
		{
#endif
		
		float3 coords;
		coords.x = SMAASearchXLeft(SMAAEdgeMapSamp, SMAASearchMapSamp, offset[0].xy, offset[2].x);
		coords.y = offset[1].y;
		coords.z = SMAASearchXRight(SMAAEdgeMapSamp, SMAASearchMapSamp, offset[0].zw, offset[2].y);
		
		float2 d = coords.xz;
		d = abs(round(madd(ViewportSize.xx, d, -input.oTexcoord0.zz)));
		
		float e1 = tex2Dlod(SMAAEdgeMapSamp, float4(coords.xy, 0, 0)).r;
		float e2 = tex2Dlod(SMAAEdgeMapSamp, float4(coords.zy + float2(ViewportOffset2.x, 0), 0, 0)).r;
		
		weights.rg = SMAAArea(SMAAAreaMapSamp, sqrt(d), e1, e2, subsampleIndices.y);
		
		coords.y = input.oTexcoord0.y;
		SMAADetectHorizontalCornerPattern(SMAAEdgeMapSamp, weights.rg, coords.xyzy, d);
#if SMAA_MAX_SEARCH_STEPS_DIAG
		} 
		else
		{
			edge.r = 0.0;
		}
#endif
	}

	[branch]
	if (edge.r > 0.0)
	{
		float3 coords;
		coords.y = SMAASearchYUp(SMAAEdgeMapSamp, SMAASearchMapSamp, offset[1].xy, offset[2].z);
		coords.x = offset[0].x;
		coords.z = SMAASearchYDown(SMAAEdgeMapSamp, SMAASearchMapSamp, offset[1].zw, offset[2].w);
		
		float2 d = coords.yz;
		d = abs(round(madd(ViewportSize.yy, d, -input.oTexcoord0.ww)));

		float e1 = tex2Dlod(SMAAEdgeMapSamp, float4(coords.xy, 0, 0)).g;
		float e2 = tex2Dlod(SMAAEdgeMapSamp, float4(coords.xz + float2(0, ViewportOffset2.y), 0, 0)).g;
		
		weights.ba = SMAAArea(SMAAAreaMapSamp, sqrt(d), e1, e2, subsampleIndices.x);
		
		coords.x = input.oTexcoord0.x;
		SMAADetectVerticalCornerPattern(SMAAEdgeMapSamp, weights.ba, coords.xyxz, d);
	}
	
	return weights;
}

technique SMAA
{
	pass SMAABlendingWeightCalculation
	{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		
		VertexShader = compile vs_3_0 SMAABlendingWeightCalculationVS();
		PixelShader  = compile ps_3_0 SMAABlendingWeightCalculationPS();
	}
}