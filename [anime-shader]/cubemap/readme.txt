Resource: Camera2Image3DRefTexGen v0.1.2
Author: Ren712
Contact: knoblauch700@o2.pl 

This resource adds a possibility to generate scene based reflection textures.
The world textures are drawn in a separate render pass then transformed into
equirectangular map. The reflection requires 6 frames to complete then it's 
applied to vehicle body. 

Requirements:
The effects require MRT in shader (works with GFX cards with full dx9 support)

Known issues:
The resource draws only what is seen by camera, doesn't stream in anything outside the 
main viewport. So expect many things to be culled - hit '1' to switch between views before
saving to texture.