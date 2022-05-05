#include "mta-helper.fx"
//--------------------------- BASIC PROPERTIES ------------------------------
// The world transformation
#define World gWorld
 
// The view transformation
#define View gView
 
// The projection transformation
#define Projection gProjection
 
// The transpose of the inverse of the world transformation,
// used for transforming the vertex's normal
#define WorldInverseTranspose gWorldInverseTranspose
 
//--------------------------- DIFFUSE LIGHT PROPERTIES ------------------------------
// The direction of the diffuse light
float3 DiffuseLightDirection = float3(1, 1,1);
//#define DiffuseLightDirection gLightDirection
// The color of the diffuse light
float4 DiffuseColor = float4(1, 1, 1, 1);
 
// The intensity of the diffuse light
float DiffuseIntensity = 0.6;

//--------------------------- TOON SHADER PROPERTIES ------------------------------
// The color to draw the lines in.  Black is a good default.
float4 LineDepth = 0.4;
 
// The thickness of the lines.  This may need to change, depending on the scale of
// the objects you are drawing.
float LineThickness = 0.002;
 
//--------------------------- TEXTURE PROPERTIES ------------------------------
// The texture being used for the object
//texture Texture;
 
// The texture sampler, which will get the texture color
sampler2D textureSampler = sampler_state 
{
    Texture = (gTexture0);
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;   
};
 
//--------------------------- DATA STRUCTURES ------------------------------
// The structure used to store information between the application and the
// vertex shader
struct AppToVertex
{
    float4 Position : POSITION0;            // The position of the vertex
    float3 Normal : NORMAL0;                // The vertex's normal
    float2 TextureCoordinate : TEXCOORD0;    // The texture coordinate of the vertex
    float4 Diffuse : COLOR0;
};
 
// The structure used to store information between the vertex shader and the
// pixel shader
struct VertexToPixel
{
    float4 Position : POSITION0;
    float2 TextureCoordinate : TEXCOORD0;
    float3 Normal : TEXCOORD1;
    float4 Diffuse : COLOR0;
};

float3 RotateAroundZInDegrees (float3 vertex, float degrees)
{
    float alpha = degrees * 3.14 / 180.0;
    float sina, cosa;
    sincos(alpha, sina, cosa);
    float2x2 m = float2x2(cosa, -sina, sina, cosa);
    //return float3(mul(m, vertex.xz), vertex.y).xzy;
    return float3(mul(m, vertex.xy), vertex.z).zxy;
}

//--------------------------- SHADERS ------------------------------
// The vertex shader that does cel shading.
// It really only does the basic transformation of the vertex location,
// and normal, and copies the texture coordinate over.
VertexToPixel CelVertexShader(AppToVertex input)
{
    VertexToPixel output;
 
    // Transform the position
    float4 worldPosition = mul(input.Position, World);
    float4 viewPosition = mul(worldPosition, View);
    output.Position = mul(viewPosition, Projection);
 
    // Transform the normal
    //output.Normal = normalize(mul(input.Normal, WorldInverseTranspose));
    output.Normal = mul(input.Normal, WorldInverseTranspose);
    // Copy over the texture coordinate
    output.TextureCoordinate = input.TextureCoordinate;
    output.Diffuse = input.Diffuse;
    return output;
}
 
// The pixel shader that does cel shading.  Basically, it calculates
// the color like is should, and then it discretizes the color into
// one of four colors.
/*
float4 CelPixelShader(VertexToPixel input) : COLOR0
{
    // Calculate diffuse light amount
    //float intensity = dot(normalize(DiffuseLightDirection), input.Normal);
    float intensity = dot(normalize(RotateAroundZInDegrees(gLightDirection,input.Normal)), input.Normal);

    if(intensity < 0)
        intensity = 0;
 
    // Calculate what would normally be the final color, including texturing and diffuse lighting
    float4 color = tex2D(textureSampler, input.TextureCoordinate) * DiffuseIntensity ;
    color.a = 1;
 
    if (intensity > 0.5)
        color = float4(1.0,1,1,1.0) * color;
    //else if (intensity > 0.5)
        //color = float4(0.8,0.8,0.8,1.0) * color;
    //else if (intensity > 0.45)
        //color = float4(0.75,0.75,0.75,1.0) * color;
    else
        color = float4(0.7,0.7,0.7,1.0) * color;
  
 
    return color;
}
*/

float4 CelPixelShader(VertexToPixel input) : COLOR0
{
    // Calculate diffuse light amount
    //float intensity = dot(normalize(DiffuseLightDirection), input.Normal);
    float intensity = dot(normalize(RotateAroundZInDegrees(gLightDirection,input.Normal)), input.Normal);

    if(intensity < 0)
        intensity = 0;
 
    // Calculate what would normally be the final color, including texturing and diffuse lighting
    float4 color = tex2D(textureSampler, input.TextureCoordinate) * DiffuseIntensity ;

    
    color.a = 1;
 
    if (intensity > 0.5)
        color = float4(1.0,1,1,1.0) * color;
    //else if (intensity > 0.5)
        //color = float4(0.8,0.8,0.8,1.0) * color;
    //else if (intensity > 0.45)
        //color = float4(0.75,0.75,0.75,1.0) * color;
    else
        color = float4(0.7,0.7,0.7,1.0) * color;
  
 
    return color;
}

VertexToPixel OutlineVertexShader(AppToVertex input)
{
    VertexToPixel output = (VertexToPixel)0;
    
    // Calculate where the vertex ought to be.  This line is equivalent
    // to the transformations in the CelVertexShader.
    float4 original = mul(mul(mul(input.Position, World), View), Projection);
 
    // Calculates the normal of the vertex like it ought to be.
    float4 normal = mul(mul(mul(input.Normal, World), View), Projection);
 
    // Take the correct "original" location and translate the vertex a little
    // bit in the direction of the normal to draw a slightly expanded object.
    // Later, we will draw over most of this with the right color, except the expanded
    // part, which will leave the outline that we want.
    output.Position    = original + (mul(LineThickness, normal));
 
    return output;
}

 
// The pixel shader for the outline.  It is pretty simple:  draw everything with the
// correct line color.
float4 OutlinePixelShader(VertexToPixel input) : COLOR0
{
    float4 color = tex2D(textureSampler, input.TextureCoordinate) * DiffuseColor * DiffuseIntensity * LineDepth;

    return color;
}


technique Toon
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 CelVertexShader();
        PixelShader = compile ps_2_0 CelPixelShader();
    }
    pass Pass2
    {
        VertexShader = compile vs_2_0 OutlineVertexShader();
        PixelShader = compile ps_2_0 OutlinePixelShader();
        CullMode = CCW;
    }
 
}