--[[
local cel = dxCreateShader("rim.fx",0,0,false,"ped")
engineApplyShaderToWorldTexture(cel, "*")
--]]
print("--------------------------------")
local rim = dxCreateShader("cel2.fx",0,0,false,"ped")
engineApplyShaderToWorldTexture(rim, "*")
local lightColor = {255,210,210,255}
--dxSetShaderValue(cel,"DiffuseColor",{lightColor[1]/255,lightColor[2]/255,lightColor[3]/255,lightColor[4]/255})
local maxrim = 0.7


addEventHandler("onClientRender",root,function()
    local h,m =	getTime()
    s = m
    sunAngle = (m + 60 * h + s/60.0) * 0.0043633231;
    x = 0.7 + math.sin(sunAngle);
    y = -0.7;
    z = 0.2 - math.cos(sunAngle);
    dxSetShaderValue(rim,"sunDirection",{x,y,z})
    
    dxSetShaderValue(rim,"RimLightInten",getSunSize() > maxrim and maxrim or getSunSize())

end)
