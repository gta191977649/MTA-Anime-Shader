#include "mta-helper.fx"

#define Projection gProjection
#define View gView
#define World gWorld
//--------------------------- TOON SHADER PROPERTIES ------------------------------
// The color to draw the lines in.  Black is a good default.
float4 LineColor = float4(0, 0, 0, 1);
 
// The thickness of the lines.  This may need to change, depending on the scale of
// the objects you are drawing.
float LineThickness = .03;

//--------------------------- DATA STRUCTURES ------------------------------
// The structure used to store information between the application and the
// vertex shader
struct AppToVertex
{
    float4 Position : POSITION0;            // The position of the vertex
    float3 Normal : NORMAL0;                // The vertex's normal
    float2 TextureCoordinate : TEXCOORD0;    // The texture coordinate of the vertex
};
 
// The structure used to store information between the vertex shader and the
// pixel shader
struct VertexToPixel
{
    float4 Position : POSITION0;
    float2 TextureCoordinate : TEXCOORD0;
    float3 Normal : TEXCOORD1;
};
// The vertex shader that does the outlines
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
    return LineColor;
}


technique Toon
{
    // The first pass will go through and draw the back-facing triangles with the outline shader,
    // which will draw a slightly larger version of the model with the outline color.  Later, the
    // model will get drawn normally, and draw over the top most of this, leaving only an outline.
    pass Pass1
    {
        VertexShader = compile vs_2_0 OutlineVertexShader();
        PixelShader = compile ps_2_0 OutlinePixelShader();
        CullMode = CCW;
    }

}