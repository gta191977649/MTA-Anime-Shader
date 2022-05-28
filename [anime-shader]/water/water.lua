local scx,scy = guiGetScreenSize ()




addEventHandler( "onClientHUDRender", root, function()
	if not isElement(waterShader) then return end
	if not isElement(normalRT) then return end
    
    dxSetShaderValue( waterShader, "sNormalTexture", normalRT )
    dxSetShaderValue( waterShader, "sDepthTexture",  depthRT )
    -- Update screen
    dxUpdateScreenSource( screenSource,true )
    dxSetShaderValue(waterShader,"sScreenSource",screenSource)
end)

addEventHandler("onClientPreRender",root,function() 
    if not isElement(waterShader) then return end
    dxSetRenderTarget( normalRT, true )
    dxSetRenderTarget()
    dxSetRenderTarget( depthRT, true )
    dxDrawRectangle( 0, 0, scx, scy )
    dxSetRenderTarget()
    
end)

function enableWater() 
    screenSource = dxCreateScreenSource( scx,scy)
    normalRT = dxCreateRenderTarget( scx, scy, true )
    depthRT = dxCreateRenderTarget( scx, scy, false )
    waterShader = dxCreateShader("fx/water.fx")
    engineApplyShaderToWorldTexture( waterShader, "waterclear256" )
    print("OK")
end

enableWater() 