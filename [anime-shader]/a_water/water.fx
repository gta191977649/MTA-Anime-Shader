//-- Include some common stuff
#include "mta-helper.fx"
int gCapsMaxAnisotropy < string deviceCaps="MaxAnisotropy"; >;

static const int rays = 6;
float deepness = 0.5;
float2 sPixelSize = float2(0,0);
texture screenInput;
texture normalTexture;
texture foamTexture;
texture gDepthBuffer : DEPTHBUFFER;
float flowSpeed = 0.5;
float reflectionSharpness = 0.1;
float reflectionStrength = 0.0;
float refractionStrength = 0.0;
float causticSpeed = 0.3;
float causticStrength = 0.2;
float causticIterations = 20;
float4 waterColor = float4(1,1,1,1);
float dayTime = 1.0;
float3 sunPos = float3(0, 0, 0);
float3 sunColor = float3(0.9, 0.7, 0.6);
float specularSize = 4;
float waterShiningPower = 1;
float contrast = 0;
float saturation = 0;
#define mod(x, y) (x - y * floor(x / y))


sampler2D screenSampler = sampler_state
{
	Texture = <screenInput>;
	AddressU = Mirror;
	AddressV = Mirror;
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

sampler NormalSampler = sampler_state
{
	Texture = <normalTexture>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler SamplerDepth = sampler_state
{
	Texture = (gDepthBuffer);

};

//--------------------------------------------------------------------------------------
//-- Get value from the depth buffer
//-- Uses define set at compile time to handle RAWZ special case (which will use up a few more slots)
//--------------------------------------------------------------------------------------
float4 GetGray (float4 inColor)
{
	return dot (inColor , float4 (0.3,0.6,0.1,1.0));

}
float4 GetContrast (float4 inColor)
{
	return (inColor + (GetGray(inColor) -0.5) * contrast);

}
float4 GetSaturation (float4 inColor)
{
	float average = (inColor.r + inColor.g + inColor.b) / 3;
	inColor.rgb +=  (inColor.rgb - average) * saturation;
	return inColor;
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

//Code from https://habrahabr.ru/post/244367/
float3 GetUV(float3 position)
{
	float4 pVP = mul(float4(position, 1), gViewProjection);
	pVP.xy = float2(0.5f, 0.5f) + float2(0.5f, -0.5f) * pVP.xy / pVP.w;
	return float3(pVP.xy, pVP.z / pVP.w);
}

//calculate pixel world position at a certain UV+depth location
float3 GetPosition(float2 UV, float depth)
{
	float4 position = 1.0f; 
 
	position.x = UV.x * 2.0f - 1.0f; 
	position.y = -(UV.y * 2.0f - 1.0f); 

	position.z = depth; 

	position = mul(position, inverseMatrix(gViewProjection)); 
 
	position /= position.w;

	return position.xyz;
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

struct VertexInputType
{
	float4 position : POSITION;
	float3 normal : NORMAL0;
	float2 textureCoords : TEXCOORD0;
};

struct PixelInputType
{
	float4 position : POSITION;
	float2 textureCoords : TEXCOORD0;
	float4 refractionPosition : TEXCOORD1;
	float4 worldPosition : TEXCOORD2;
	float3 lightDirection : TEXCOORD3;
	float3 worldNormal : TEXCOORD4;
	float4 vposition : TEXCOORD5;
};

////////////////////////////////////////////////////////////////////////////////
// Vertex Shader
////////////////////////////////////////////////////////////////////////////////
PixelInputType WaterVertexShader(VertexInputType input)
{
	PixelInputType output;

	// Create the view projection world matrix for reflection.
	matrix projection = mul(gWorldViewProjection, gWorld);
	projection = mul(gWorld, projection);

	// Calculate the position of the vertex against the world, view, and projection matrices.
	output.worldPosition = MTACalcWorldPosition(input.position);
	float4 viewPos = mul(output.worldPosition, gView);
	output.worldPosition.w = viewPos.z / viewPos.w;
	output.position = mul(viewPos, gProjection);
	output.lightDirection = normalize(gCameraPosition - sunPos);
	MTAFixUpNormal(input.normal);
	output.worldNormal = MTACalcWorldNormal(input.normal);
	
	// Store the texture coordinates for the pixel shader.
	output.textureCoords = input.textureCoords;

	// Calculate the input position against the projection matrix.
	output.refractionPosition = mul(input.position, projection);

	output.vposition = mul(input.position, gWorldViewProjection);
	return output;
}

float map(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}



////////////////////////////////////////////////////////////////////////////////
// Pixel Shader
////////////////////////////////////////////////////////////////////////////////
float4 WaterPixelShader(PixelInputType input) : COLOR0
{
	float2 refractTexCoord;
	float timer = (gTime/12) * flowSpeed;
	float Depth = input.vposition.z / input.vposition.w;
	
	float2 txcoord = (input.vposition.xy / input.vposition.w) * float2(0.5, -0.5) + 0.5;
	txcoord += 0.5 * sPixelSize;
	
	float3 viewDir = normalize(input.worldPosition - gCameraPosition);// get to pixel view direction
	
	// Sample the normal from the normal map texture.
	float2 movingTextureCoords = input.textureCoords.xy;
	movingTextureCoords.y = movingTextureCoords.y + timer;

	//float a = map(dist,0, 500, 0, 1);
	float3 v = input.worldPosition - gCameraPosition;
	float anisotropy = 1/ddy(length(v.xy));

	float3 normalMap = swell(-input.worldPosition,anisotropy );
	//float3 normalMap = tex2D(NormalSampler, movingTextureCoords);
	
	// Expand the range of the normal from (0,1) to (-1,+1).
	//normalMap = (normalMap * 2.0f) - 1.0f;

	// Calculate the projected refraction texture coordinates.
	refractTexCoord.x = input.refractionPosition.x / input.refractionPosition.w / 2.0 + 0.5;
	refractTexCoord.y = -input.refractionPosition.y / input.refractionPosition.w / 2.0 + 0.5;

	//camera depth
	float cameraDepth = max(0.915, FetchDepthBufferValue(txcoord));// clamp cameraDepth to at least 0.915 to avoid flickering issues close to the camera
	float dp = 1.0 / (1 - Depth);
	float planardepth = 1.0 / (1 - cameraDepth);
	float waterDepth = min(20, planardepth - dp);// Calculates a value between 0 and 10
	float3 camDist = input.worldPosition.xyz - gCameraPosition.xyz;

	//generate base color
	const float4 phases = float4(0.28, 0.50, 0.07, 0);//周期
    const float4 amplitudes = float4(4.02, 0.34, 0.65, 0);//振幅
    const float4 frequencies = float4(0.00, 0.48, 0.08, 0);//频率
    const float4 offsets = float4(0.00, 0.16, 0.00, 0);//相位
	float diffZ = (planardepth - dp)/30;
    //按照距离海滩远近叠加渐变色
    float4 cos_grad = cosine_gradient(saturate(1-diffZ), phases, amplitudes, frequencies, offsets);	

	

	float4 reflectionColor = cos_grad;
	if (gCameraPosition.z > input.worldPosition.z) {// only reflect when camera is above water
		float3 reflectDir = normalize(reflect(viewDir, input.worldNormal));// reflection direction
		float3 currentRay = 0;
		float2 nuv = 0;
		float d = 0;
		
		// It looks like we need to multiply L with a number that gets manipulated by the angle in which we are looking at the water. Lets call it viewMult
		float camHeight = length(input.worldPosition.z - gCameraPosition.z);
		float viewMult = 7 * (1+viewDir.y) / max(1, camHeight * 0.5);
		float L = FetchDepthBufferValue(input.textureCoords) * (6 + viewMult);// This calculation makes literally no sense, but it successfully fights artifacts of vehicles and others
		
		//Maybe someone can come up with a better solution than above or below
		
		for(int i = 0; i < rays; i++)// cast rays for reflection - the used method is by far not perfect
		{
			currentRay = input.worldPosition + reflectDir * L;
			nuv = GetUV(currentRay);
			d = FetchDepthBufferValue(nuv);
		
			float3 newPosition = GetPosition(nuv, d);
			//L = length(input.worldPosition - newPosition);
			L = length( newPosition);
		}

		// Currently we get some flickering pixels because 2 pixels from the main view can be merged into our final reflection result and the computer does not know which
		// pixel should prevail. We can solve this by sorting the projection from top-to-bottom so we only write the pixel closer to the water plane. But i dont know how to do this.
		// Ghost recon wildlands reflections use the InterlockedMax function, but i dont know how to implement this here:
		
		// Read-write max when accessing the projection hash UAV
		// uint projectionHash = SrcPosPixel.y << 16 | SrcPosPixel.x;
		// InterlockedMax(ProjectionHashUAV[ReflPosPixel], projectionHash, dontCare);
		
		
		// Re-position the reflection coordinate sampling position by the normal map value to simulate the rippling wave effect.
		nuv = nuv + normalMap.xy * reflectionSharpness;
		
		float err = 0;
		if ((d > 0.9999) || (Depth > 0.9999)) err = 1; // Prevent reflection of background and objects too far away, if you want
		if (Depth > d) err = 1; // Prevent reflection of objects that are actually in front of the water and not behind it

		//TODO -----> implement edge stretching to fill reflection gaps on the screen sides! They do it in ghost recon wildlands, but i have no idea how to implement it here: 
		//http://remi-genin.fr/blog/screen-space-plane-indexed-reflection-in-ghost-recon-wildlands/
		
		
		// create corona-like mask around reflection edges to obscure artifacts
		
		float dy = 1/2 - (nuv.y - 0.5);
		float dist = pow(dy * dy, 0.5);
		float distFromCenter = 0.5 - dist;
		int fadingStrength = 5;
		float mask = 1 - saturate(distFromCenter * fadingStrength);
		

		float fresnel = saturate(1.5 * dot(viewDir, -input.worldNormal));
		reflectionColor = lerp(tex2D(screenSampler, nuv), waterColor, mask);	// lerp between new reflection and water color with the corona mask
		//reflectionColor = tex2D(screenSampler, nuv);	// lerp between new reflection and water color with the corona mask
		reflectionColor = lerp(reflectionColor, cos_grad, fresnel);			// lerp between reflection and fresnel value to make the reflection slowly lose color
		// lerp between reflection and water color to filter out reflection artifacts
		//reflectionColor = lerp(reflectionColor, cos_grad, err);
		reflectionColor = lerp(waterColor, reflectionColor, reflectionStrength);// lerp between water color and reflection color according to the reflection strength setting
		
		//try to fix the reflection flicking at least, but it's not a optimal approach (nurupo)
		float fade2Normal = abs(dot(gCameraDirection,input.worldNormal));
		reflectionColor = lerp(cos_grad,reflectionColor,saturate((0.3-fade2Normal) * 5));
		//Fix far dist reflection glitch
		reflectionColor = lerp(reflectionColor,cos_grad,saturate(ddy(1-length(camDist.xy)) * 0.6));
	}

	//Create water caustics, originally made by genius "Dave Hoskins" @ https://www.shadertoy.com/view/MdlXz8

	/*
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
	
	float colour = saturate(pow(abs(c), 8.0) * causticStrength + 0.1);
	*/
	
	
	float4 refractionColor = tex2D(screenSampler,refractTexCoord + normalMap.xy) * refractionStrength;
	
	
	// TO DO: Add refraction of stuff below water surface, but i dont think that this is possible
	

	// Using Blinn half angle modification for performance over correctness
	float specularBase = saturate(dot(float3(0.8,0.8,0.4), normalMap)) * 0.1;
	float3 lightRange = normalize(normalize(gCameraPosition - input.worldPosition) - input.lightDirection);
	float specularLight = pow(saturate(dot(lightRange, normalMap)), specularSize);
	float specularAcceleration = pow(saturate(dot(lightRange, normalMap)), 100);
	float3 specularColor = sunColor * specularLight;
	specularColor = saturate(specularColor + pow(saturate(dot(lightRange, input.worldNormal)), specularSize * 3)) * 0.5;
	specularColor = saturate(specularColor + specularAcceleration + float3(specularBase, specularBase, specularBase));



	//TO DO: waterDepth is not really the planar water depth (I think), thats why the shore foam depends on view angle... I cant find a proper solution
	

	//Add shore foam
	float scaling = 15;
	float speed = 0.01;
	float2 foamCoords = input.textureCoords;// Tile the foam texture to make it look more detailed
	//foamCoords.x += sin ((foamCoords.x + foamCoords.y) * 22 + gTime * speed) * scaling;
	//foamCoords.x += cos (foamCoords.y * 22 + gTime * speed) * scaling;
	// tiling
	foamCoords.x = foamCoords.x/50 ;
	foamCoords.y = foamCoords.y/10;

	foamCoords.y -= gTime*speed;
	float4 foamColor = tex2D(foamSampler, foamCoords * scaling);
	
	foamColor = step(0.5,foamColor);
	foamColor = saturate((foamColor.r  +foamColor.g )) * saturate(0.5 + dayTime);	
	// Combine water color, refraction, foam and caustics to the finalColor.


	float4 finalColor = (refractionColor + cos_grad) * reflectionColor ;
	
	float alpha = waterDepth * deepness * waterColor.a;
	//float4 finalColor =  reflectionColor * cos_grad  ;

	
	finalColor = lerp(finalColor,reflectionColor,smoothstep(0.1, 1, finalColor.a));
	finalColor.rgb = saturate(finalColor.rgb + specularColor * waterShiningPower);
	
	float dist = distance(input.worldPosition,gCameraPosition);
	float foamAlpha = lerp(1,0,saturate(20/dist));
	foamColor.a *= foamAlpha;
	
	finalColor.a = lerp(0, finalColor.a, smoothstep(0,5, waterDepth));
	finalColor.a = alpha;
	finalColor = lerp(foamColor  , finalColor, smoothstep(0,2, waterDepth));
	
	//finalColor.rgb *= saturate(0.15 + dayTime);
	// test color code
	//finalColor = reflectionColor;
	

	//create CausticColor
	//float3 CausticColor = float3(1,0,0);
	//float3 Caustic = lerp(lerp(0,1, saturate(colour)), finalColor.rgb, 0);

	//create a edge light
	
	finalColor.rgb += specularColor.rgb * ddy(1-length(camDist.xy)/50);
	
	finalColor = GetContrast(finalColor);
	finalColor = GetSaturation(finalColor);
	
	//finalColor.rgb = Caustic.rgb;
	return float4(MTAApplyFog(finalColor.rgb, input.worldPosition), finalColor.a);
	
}

technique WaterTechnique
{
	pass p0
	{
		ZWriteEnable = true;
		ZFunc = 2;
		VertexShader = compile vs_3_0 WaterVertexShader();
		PixelShader = compile ps_3_0 WaterPixelShader();
	}
}

technique fallback
{
	pass P0
	{
		// Just draw normally
	}
}