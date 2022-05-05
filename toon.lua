

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
        dxSetShaderValue(toon,"sunDirection",{x,y,z})
        dxSetShaderValue(toon,"sunSize",sunSize)
        --print(timeInterval)
    end
end)
function createShader() 
    print("--------------------------------")
    toon = dxCreateShader("cel2.fx",0,0,false,"ped")
    engineApplyShaderToWorldTexture(toon, "*")
    triggerEvent( "switchBloom", root, true )
end
function destoryShader() 
    destroyElement(toon)
    triggerEvent( "switchBloom", root, false )
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
createShader() 