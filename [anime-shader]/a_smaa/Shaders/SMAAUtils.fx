#include "mta-helper.fx"

#define SMAA_PRESET_ULTRA

#if defined(SMAA_PRESET_LOW)
	#define SMAA_THRESHOLD 0.15
	#define SMAA_MAX_SEARCH_STEPS 4
	#define SMAA_DISABLE_DIAG_DETECTION
	#define SMAA_DISABLE_CORNER_DETECTION
#elif defined(SMAA_PRESET_MEDIUM)
	#define SMAA_THRESHOLD 0.1
	#define SMAA_MAX_SEARCH_STEPS 8
	#define SMAA_DISABLE_DIAG_DETECTION
	#define SMAA_DISABLE_CORNER_DETECTION
#elif defined(SMAA_PRESET_HIGH)
	#define SMAA_THRESHOLD 0.1
	#define SMAA_MAX_SEARCH_STEPS 16
	#define SMAA_MAX_SEARCH_STEPS_DIAG 8
	#define SMAA_CORNER_ROUNDING 25
#elif defined(SMAA_PRESET_ULTRA)
	#define SMAA_THRESHOLD 0.05
	#define SMAA_MAX_SEARCH_STEPS 32
	#define SMAA_MAX_SEARCH_STEPS_DIAG 16
	#define SMAA_CORNER_ROUNDING 25
#endif

#define SMAA_AREATEX_MAX_DISTANCE 16
#define SMAA_AREATEX_MAX_DISTANCE_DIAG 20
#define SMAA_AREATEX_PIXEL_SIZE (1.0 / float2(160.0, 560.0))
#define SMAA_AREATEX_SUBTEX_SIZE (1.0 / 7.0)
#define SMAA_SEARCHTEX_SIZE float2(66.0, 33.0)
#define SMAA_SEARCHTEX_PACKED_SIZE float2(64.0, 16.0)
#define SMAA_CORNER_ROUNDING_NORM (float(SMAA_CORNER_ROUNDING) / 100.0)
 
float2 ViewportSize 	= float2(1920, 1080);
float2 ViewportOffset 	= float2(0.00026041666, 0.00046296296);
float2 ViewportOffset2 	= float2(0.00052083333, 0.00092592592);

float madd(float v, float t1, float t2)
{
	return v * t1 + t2;
}

float2 madd(float2 v, float2 t1, float2 t2)
{
	return v * t1 + t2;
}

float3 madd(float3 v, float3 t1, float3 t2)
{
	return v * t1 + t2;
}

float4 madd(float4 v, float4 t1, float4 t2)
{
	return v * t1 + t2;
}

float3 srgb2linear(float3 rgb)
{
	rgb = max(6.10352e-5, rgb);
	return rgb < 0.04045f ? rgb * (1.0 / 12.92) : pow(rgb * (1.0 / 1.055) + 0.0521327, 2.4);
}

float4 srgb2linear(float4 c)
{
	return float4(srgb2linear(c.rgb), c.a);
}

float3 linear2srgb(float3 srgb)
{
	srgb = max(6.10352e-5, srgb);
	return min(srgb * 12.92, pow(max(srgb, 0.00313067), 1.0/2.4) * 1.055 - 0.055);
}

float4 linear2srgb(float4 c)
{
	return float4(linear2srgb(c.rgb), c.a);
}

float luminance(float3 rgb)
{
	const float3 lumfact = float3(0.2126f, 0.7152f, 0.0722f);
	return dot(rgb, lumfact);
}

void SMAAMovc(bool2 cond, inout float2 variable, float2 value) 
{
	[flatten] if (cond.x) variable.x = value.x;
	[flatten] if (cond.y) variable.y = value.y;
}

void SMAAMovc(bool4 cond, inout float4 variable, float4 value) 
{
	SMAAMovc(cond.xy, variable.xy, value.xy);
	SMAAMovc(cond.zw, variable.zw, value.zw);
}