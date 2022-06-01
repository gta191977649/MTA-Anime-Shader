local scx,scy = guiGetScreenSize ()




addEventHandler( "onClientHUDRender", root, function()
	if not isElement(waterShader) then return end
	if not isElement(normalRT) then return end
    
    dxSetShaderValue( waterShader, "sNormalTexture", normalRT )
    dxSetShaderValue( waterShader, "sDepthTexture",  depthRT )
    -- Update screen
    dxUpdateScreenSource( screenSource,true )
    dxSetShaderValue(waterShader,"screenInput",screenSource)
end)

function enableWater() 
    screenSource = dxCreateScreenSource( scx,scy)
    normalRT = dxCreateRenderTarget( scx, scy, true )
    depthRT = dxCreateRenderTarget( scx, scy, false )
    waterShader = dxCreateShader("fx/water.fx")
    engineApplyShaderToWorldTexture( waterShader, "waterclear256" )
    print("OK")
    setColorFilter (0, 0, 0, 0, 0, 0, 0, 0)
end

enableWater() 