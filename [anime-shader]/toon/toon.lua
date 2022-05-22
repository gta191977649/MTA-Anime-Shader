

addEventHandler("onClientRender",root,function()
    if isElement(toon) then
        local h,m =	getTime()
        s = m
        sunAngle = (m + 60 * h + s/60.0) * 0.0043633231;
        x = 0.7 + math.sin(sunAngle);
        y = -0.7;
        z = 0.2 - math.cos(sunAngle);

        local h, m = getTime()
        local timeInterval =  h * 60 + m
        local sunSize = getSunSize()
        if timeInterval >= 360 and timeInterval <= 1140 and getRainLevel() == 0 then -- is day
            sunSize = sunSize < 5 and 5 or sunSize
        end
       

        --local vecCam = getCamera().matrix:getPosition()
        local vecCam = getLocalPlayer().matrix:getPosition()
        local sunVec = vecCam + Vector3(x,y,z) * 1000
        local isClear = isLineOfSightClear (vecCam.x,vecCam.y,vecCam.z,sunVec.x,sunVec.y,sunVec.z, true,  true,  true,
        true, false, true, false, localPlayer )
        dxSetShaderValue(toon,"sunDirection",{x,y,z})
        dxSetShaderValue(toon,"sunSize",sunSize)
        dxSetShaderValue(toon,"isClear",isClear)
        --dxDrawLine3D(vecCam.x,vecCam.y,vecCam.z, sunVec.x,sunVec.y,sunVec.z,isClear and tocolor(0,255,0,255) or tocolor(255,0,0,255))
   
        --print(timeInterval)
    end
end)
function createShader() 
    print("--------------------------------")
    toon = dxCreateShader("cel2.fx",0,0,false,"ped")
    --toon = dxCreateShader("normal.fx",0,0,false,"ped")
    
    engineApplyShaderToWorldTexture(toon, "*")
    triggerEvent( "switchBloom", root, true )
    triggerEvent( "switchSun", root, true )
    
end
function destoryShader() 
    destroyElement(toon)
    triggerEvent( "switchBloom", root, false )
    triggerEvent( "switchSun", root, false )
end
--------------------------------
-- Switch effect on or off
--------------------------------
function switchToon( blOn )
	
	if isElement(toon) then
		destoryShader() 
        outputChatBox("卡通渲染关闭")
	else
		createShader() 
        outputChatBox("卡通渲染开启")
	end
end

addCommandHandler("toon",switchToon)

addEventHandler("onClientResourceStart", resourceRoot, function(resource)
	createShader() 
end)