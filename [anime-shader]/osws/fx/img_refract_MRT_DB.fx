//
// file: img_refract_MRT_DB.fx
// version: v1.5
// author: Ren712
//

//--------------------------------------------------------------------------------------
// Settings
//--------------------------------------------------------------------------------------
#include "mta-helper.fx"
#define mod(x, y) (x - y * floor(x / y))
float4 sWaterColor = float4(90, 170, 170, 255);

float sSpecularBrightness = 1;
float3 sLightDir = float3(0,-0.5,-0.5);
float sSpecularPower = 4;
float sVisibility = 1;
float3 sSunColorTop = float3(255,255,255);
float3 sSunColorBott = float3(255,255,255);
float foamVisibility = 0.5;
float causticIterations = 2;
float causticSpeed = 0.3;
float causticStrength = 0.2;
float3 nStrength = float3(0.1,0.1,0.1);
float3 nRefIntens = float3(0.05,0.05,0.05);

//--------------------------------------------------------------------------------------
// Textures
//--------------------------------------------------------------------------------------
texture sMaskTexture;
texture sWaveTexture;
texture sRandomTexture;
texture sProjectiveTexture;
texture foamTexture;
	
//--------------------------------------------------------------------------------------
// Variables set by MTA
//--------------------------------------------------------------------------------------
texture gDepthBuffer : DEPTHBUFFER;
int gCapsMaxAnisotropy < string deviceCaps="MaxAnisotropy"; >;

//--------------------------------------------------------------------------------------
// Sampler 
//--------------------------------------------------------------------------------------
samplerCUBE SamplerWave = sampler_state
{
	Texture = (sWaveTexture);
	MagFilter = Linear;
	MinFilter = Linear;
	MipFilter = Linear;
	MIPMAPLODBIAS = 0.000000;
};

sampler2D foamSampler = sampler_state
{
	Texture = <foamTexture>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler2D SamplerNormal = sampler_state
{
	Texture = (sRandomTexture);
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler2D SamplerScreen = sampler_state
{
	Texture = (sProjectiveTexture);
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Mirror;
	AddressV = Mirror;
};

sampler SamplerDepthTex = sampler_state
{
	Texture = (sMaskTexture);
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = None;
};

sampler SamplerDepth = sampler_state
{
	Texture = (gDepthBuffer);
	MinFilter = Point;
	MagFilter = Point;
	MipFilter = None;
	AddressU = Clamp;
	AddressV = Clamp;
};

//------------------------------------------------------------------------------------------
// Structure of data sent to the vertex shader
//------------------------------------------------------------------------------------------
struct VSInput
{
	float3 Position : POSITION0;
	float4 Diffuse : COLOR0;
	float2 TexCoord : TEXCOORD0;
};

//------------------------------------------------------------------------------------------
// Structure of data sent to the pixel shader ( from the vertex shader )
//------------------------------------------------------------------------------------------
struct PSInput
{
	float4 Position : POSITION0;
	float4 Diffuse : COLOR0;
	float2 TexCoord : TEXCOORD0;
	float3 CameraDirection : TEXCOORD1;
	float3 CameraPosition : TEXCOORD2;
	float3 Normal : TEXCOORD3;
	float3 Tangent : TEXCOORD4;
	float3 Binormal : TEXCOORD5;
	float4 SparkleTex : TEXCOORD6;
};

//--------------------------------------------------------------------------------------
// Get value from the depth buffer
// Uses define set at compile time to handle RAWZ special case (which will use up a few more slots)
//--------------------------------------------------------------------------------------
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
 
//--------------------------------------------------------------------------------------
// Use the last scene projecion matrix to linearize the depth value a bit more
//--------------------------------------------------------------------------------------
float Linearize(float posZ)
{
	return gProjectionMainScene[3][2] / (posZ - gProjectionMainScene[2][2]);
}

//------------------------------------------------------------------------------------------
// VertexShaderFunction
//------------------------------------------------------------------------------------------
PSInput VertexShaderFunction(VSInput VS)
{
	PSInput PS = (PSInput)0;

	// retrieve cameraPosition and cameraDirection from inverted ViewMatrix	
	float4x4 sViewInverse = inverseMatrix(gViewMainScene);
	PS.CameraDirection = sViewInverse[2].xyz;
	PS.CameraPosition = sViewInverse[3].xyz;
	
	// calculate projection inverse matrix
	float4x4 sProjectionInverse = inverseMatrix(gProjectionMainScene);

	// calculate screen position of the vertex
	PS.Position = mul(float4(VS.Position.xyz, 1), gWorldViewProjection);
	// pass texCoords and vertex color to PS
	PS.TexCoord = VS.TexCoord;
	
	// create Normal, Binormal and Tangent vectors	
	float3 VSNormal = float3(0,0,1);
	float3 Tangent; 
	float3 Binormal; 
	float3 c1 = cross(VSNormal, float3(0.0, 0.0, 1.0)); 
	float3 c2 = cross(VSNormal, float3(0.0, 1.0, 0.0)); 
	if (length(c1) > length(c2)) Tangent = c1;	
		else Tangent = c2;	
	PS.Normal = VSNormal;
	PS.Tangent = normalize(Tangent);
	PS.Binormal = normalize(cross(VSNormal, PS.Tangent)); 
	
	// Scroll noise texture
	float2 uvpos1 = 0;
	float2 uvpos2 = 0;

	uvpos1.x = sin(gTime/5) * 0.25;
	uvpos1.y = fmod(gTime/40,1);

	uvpos2.x = fmod(gTime/70,1);
	uvpos2.y = sin((1.6 + gTime)/10) * 0.25;

	// pass sparkleTex to PS	
	PS.SparkleTex = float4(uvpos1.x, uvpos1.y, uvpos2.x, uvpos2.y);
	
	// Convert regular water color to what we want
	float4 conv = float4(850, 850, 850, 255);
	PS.Diffuse = saturate(sWaterColor / conv);

	return PS;
}

//------------------------------------------------------------------------------------------
//-- Function for converting depth to view-space position
//-- in deferred pixel shader pass.  vTexCoord is a texture
//-- coordinate for a full-screen quad, such that x=0 is the
//-- left of the screen, and y=0 is the top of the screen.
//------------------------------------------------------------------------------------------
float3 VSPositionFromDepthTex(float z, float2 vTexCoord, float4x4 g_matInvProjection)
{
	// Get x/w and y/w from the viewport position
	float x = vTexCoord.x * 2 - 1;
	float y = (1 - vTexCoord.y) * 2 - 1;
	float4 vProjectedPos = float4(x, y, z, 1.0f);
	// Transform by the inverse projection matrix
	float4 vPositionVS = mul(vProjectedPos, g_matInvProjection);  
	// Divide by w to get the view-space position
	return vPositionVS.xyz / vPositionVS.w;  
}

//------------------------------------------------------------------------------------------
// Unpack RGB24 into Unit Float [0,1]
//------------------------------------------------------------------------------------------
float ColorToUnit24New(in float3 color) {
	const float3 scale = float3(65536.0, 256.0, 1.0) / 65793.0;
	return dot(color, scale);
}

//------------------------------------------------------------------------------------------
// applyLiSpecular
//------------------------------------------------------------------------------------------
float3 applyLiSpecular(float3 color1, float3 color2, float3 normal, float3 lightDir, float3 sView, float specul) 
{	
	float3 h = normalize(sView - lightDir);
	float spec = pow(saturate(dot(h, normal)), specul);	
	
	float spec1 = saturate(pow(spec, specul));
	float spec2 = saturate(pow(spec, 2 * specul));
	float3 specular = spec1 * color1.rgb / 3 + spec2 * color2.rgb;
	return saturate( specular );
}

//------------------------------------------------------------------------------------------
// Pixel shader
//------------------------------------------------------------------------------------------
float4 PixelShaderFunction(PSInput PS) : COLOR
{
	// calculate projection inverse and view inverse matrices
	float4x4 sProjectionInverse = inverseMatrix(gProjectionMainScene);
	float4x4 sViewInverse = inverseMatrix(gViewMainScene);

	// get pixel depth from depth texture
	float3 depthColor = tex2D(SamplerDepthTex, PS.TexCoord).rgb;
	float waterDepthValue = ColorToUnit24New(depthColor);
	float linearWaterDepthValue = Linearize(waterDepthValue);
	
	if (waterDepthValue < 0.0001) return 0;

	// get world position from depth texture
	float3 viewPos = VSPositionFromDepthTex(waterDepthValue, PS.TexCoord, sProjectionInverse);
	float4 worldPos = mul(float4(viewPos, 1), sViewInverse);
	
	// create texture coords from world position
	float2 TexCoord =  float2(worldPos.y,-worldPos.x) * 0.125 * 0.125;

	// calculate wave texture coords
	float4 SparkleTex;
	SparkleTex.x = TexCoord.x * 1 + PS.SparkleTex.x;
	SparkleTex.y = TexCoord.y * 1 + PS.SparkleTex.y;
	SparkleTex.z = TexCoord.x * 2 + PS.SparkleTex.z;
	SparkleTex.w = TexCoord.y * 2 + PS.SparkleTex.w;

	// sample normal texture and calculate bump normals 
	float3 vFlakesNormal = tex2D(SamplerNormal, SparkleTex.xy).rgb;
	float3 vFlakesNormal2 = tex2D(SamplerNormal, SparkleTex.zw).rgb;

	float3 NormalTex = (vFlakesNormal + vFlakesNormal2) / 2;
	NormalTex = normalize((NormalTex * 2.0) - 1.0) * nStrength;
	
	float3 Normal = normalize(NormalTex.x * normalize(PS.Tangent) + NormalTex.y * normalize(PS.Binormal) + NormalTex.z * normalize(PS.Normal));
	NormalTex *= nRefIntens * PS.Diffuse.a;
	
	// Sample wave map using this reflection method
	float3 vView = normalize(PS.CameraPosition - worldPos.xyz);
	float fNdotV = saturate(dot(PS.Normal, vView));
	float3 vReflection = 2 * PS.Normal * fNdotV - vView;
	vReflection += Normal;
	float4 envMap = texCUBE(SamplerWave, -vReflection);
	float envGray = (envMap.r + envMap.g + envMap.b)/1.5;
	envMap.rgb = float3(envGray,envGray,envGray);
	envMap.rgb = saturate(envMap.rgb * envMap.a * PS.Diffuse.rgb);

	// calculate specular light
	float3 lightDir = normalize(sLightDir);
	float3 specLighting = applyLiSpecular(sSunColorBott/255, sSunColorTop/255, Normal, lightDir, vView, sSpecularPower);	
	specLighting = specLighting * envGray * sSpecularBrightness * PS.Diffuse.a;
	
	// calculate and apply bleed fix
	float depthAlt = Linearize(FetchDepthBufferValue(PS.TexCoord + NormalTex.xy));
	float refMul =  1 - saturate(linearWaterDepthValue - depthAlt);
	NormalTex *= refMul;
	
	// sample projective screen texture
	float4 refractionColor = tex2D(SamplerScreen, PS.TexCoord + NormalTex.xy);
	
	// Apply shore foam, but only on water surface, not below
	float linearSceneDepth = Linearize(FetchDepthBufferValue(PS.TexCoord + NormalTex.xy));
	float foamStrength = 0;
	float alphaFactor = 0;
	float shoreFading = 1;
	float foamSpeed = 2;
	float2 foamCoords = TexCoord * 10 + PS.SparkleTex.zw * foamSpeed;// Tile foam texture for more detail and move it with the sparkle tex
	if (PS.CameraPosition.z > worldPos.z) {
		float scaling = 0.01;
		foamCoords.x += sin((foamCoords.x + foamCoords.y) * 22 + gTime * foamSpeed) * scaling;
		foamCoords.x += cos(foamCoords.y * 22 + gTime * foamSpeed) * scaling;
		
		shoreFading = saturate(linearSceneDepth - linearWaterDepthValue);//We need to spread this a little bit out
	
		foamStrength = (1-shoreFading) * 15;// We need something better for the foam, we need to check water depth, not eye depth
		
		alphaFactor = pow(shoreFading, 3);//Try to fade the water at the coast line so we dont get an ugly line where the water ends
	}
	// Apply caustics
	float2 movingTextureCoords = TexCoord * 2;
	movingTextureCoords.y = movingTextureCoords.y + gTime / 24;
	float2 p = mod(movingTextureCoords * 6.28318530718, 6.28318530718) - 350;
	float2 i = p;
	float c = 0.3 * causticIterations;
	float inten = 0.01;
	for (int n = 0; n < causticIterations; n++) 
	{
		float t = gTime * causticSpeed * (1 - 3.5 / (n+1));
		i = p + float2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
		c += 1.0/length(float2(p.x / (sin(i.x+t)/inten), p.y / (cos(i.y+t)/inten)));
	}
	c = 1.17 - pow(c / causticIterations, 1.4);
	float caustics = saturate(pow(abs(c), 14.0) * causticStrength);
	envMap.rgb = saturate(envMap.rgb + float3(caustics, caustics, caustics));
	
	// lerp between refraction and water color and apply shore fading
	refractionColor.rgb = lerp(refractionColor.rgb, envMap.rgb, PS.Diffuse.a * shoreFading);
	
	// Apply specular
	refractionColor.rgb += specLighting * shoreFading * alphaFactor;
	
	// Apply foam
	float4 foamColor = tex2D(foamSampler, foamCoords);
	refractionColor = lerp(refractionColor, foamColor, foamColor.a * foamVisibility * foamStrength * alphaFactor);
	
	// Apply custom fog
	float DistanceFromCamera = distance(PS.CameraPosition, worldPos);
	float FogAmount = pow(saturate((DistanceFromCamera - gFogStart) / (gFogEnd - gFogStart)), 2);
	refractionColor.rgb = lerp(refractionColor.rgb, gFogColor, FogAmount);
	refractionColor.a *= (1 - FogAmount);

	
	// Apply world texture mask to the refracted water with a little bit of Bias to avoid issues with the shore fading
	if (linearWaterDepthValue > linearSceneDepth*1.15) refractionColor.a = 0;
	
	return refractionColor;
}

//-----------------------------------------------------------------------------
//-- Techniques
//-----------------------------------------------------------------------------

technique dxDrawImage2D_ref_PS3_MRT_DB
{
  pass P0
  {
	ZEnable = true;
	ZWriteEnable = true;
	ZFunc = 2;
	VertexShader = compile vs_3_0 VertexShaderFunction();
	PixelShader  = compile ps_3_0 PixelShaderFunction();
  }
}