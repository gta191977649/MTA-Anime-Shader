Resource: Shader water refract test v1.7
Update 1.7:
-Changed the reflection method

Update 1.5:
-Changed drawing method to work with other full screen effects
-Rewritten the shader effect

This shader uses some of the vertex and pixel calculations from water_shader by Ccw.
http://wiki.multitheftauto.com/wiki/Shader_examples
It uses screen image as a reflection texture instead of a cubebox (water_shader).

It needs one frame to get the reflection and another to draw the effect.
During the first step, the screen is covered by full screen dxDrawImage,
so expect some visible FPS drops.

Consider that a fun example of what can be done with a projective texture
(like mirrors, glass refractons and stuff).

Ren712
knoblauch700@o2.pl

