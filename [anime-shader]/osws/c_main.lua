local w, h = guiGetScreenSize()

local normalStr = {0.2, 0.2, 0.9}	-- surface distortion intensity
local refMult = {0.2, 0.2, 0.2}		-- refraction distortion intensity
setWaterColor(100,215,255,255)

----------------------------------------------------------------
-- DepthBuffer access
----------------------------------------------------------------
local function depthSupported()
	local depthStatus = tostring(dxGetStatus().DepthBufferFormat)
	if depthStatus == "unknown" then depthStatus = false end
	return depthStatus
end

----------------------------------------------------------------
-- enableWaterRef
----------------------------------------------------------------
function enableWaterRef()
if dxGetStatus().VideoCardNumRenderTargets > 1 and tonumber(dxGetStatus().VideoCardPSVersion) > 2 and depthSupported() and not waterEnabled then
	myScreenSource = dxCreateScreenSource(w, h)
	imgRefractShader = dxCreateShader("fx/img_refract_MRT_DB.fx")
	texWaterShader = dxCreateShader("fx/tex_water_MRT_DB.fx")
	secondRT = dxCreateRenderTarget(w, h, false)
	local textureVol = dxCreateTexture("images/waterClear_NRM.png")
	local textureCube = dxCreateTexture("images/cube_env256.dds")
	local textureFoam = dxCreateTexture("images/foam.png")
	
	if myScreenSource and imgRefractShader and texWaterShader and textureVol and textureCube and textureFoam and secondRT then
		dxSetShaderValue(texWaterShader, "secondRT", secondRT)
		dxSetShaderValue(imgRefractShader, "sMaskTexture", secondRT)
		dxSetShaderValue(imgRefractShader, "nRefIntens", refMult)
		dxSetShaderValue(imgRefractShader, "sProjectiveTexture", myScreenSource)
	
		dxSetShaderValue(imgRefractShader, "nStrength", normalStr)
		
		dxSetShaderValue(imgRefractShader, "sRandomTexture", textureVol)

		dxSetShaderValue(imgRefractShader, "sWaveTexture", textureCube)
		
		dxSetShaderValue(imgRefractShader, "foamTexture", textureFoam)
		
		engineApplyShaderToWorldTexture(texWaterShader, "waterclear256")
		waterEnabled = true
	end
end
end

addEventHandler("onClientPreRender", root,
function()
if waterEnabled then
	dxSetRenderTarget(secondRT, true)
	dxSetRenderTarget()
end
end, true, "high")

-----------------------------------------------------------------------------------
-- onClientHUDRender
-----------------------------------------------------------------------------------
addEventHandler("onClientHUDRender", root, function()
if waterEnabled then
	dxUpdateScreenSource(myScreenSource, true)
	local tr, tg, tb, br, bg, bb = getSunColor()
	local wr, wg, wb, waterAlpha = getWaterColor()
	dxSetShaderValue(imgRefractShader, "sSunColorTop", tr, tg, tb)
	dxSetShaderValue(imgRefractShader, "sSunColorBott", br, bg, bb)
	dxSetShaderValue(imgRefractShader, "sWaterColor", wr, wg, wb, waterAlpha)
	dxSetShaderValue(texWaterShader, "sWaterColor", wr/255, wg/255, wb/255, waterAlpha/255 * 0.2)
	
	--dxDrawImage(w/2, h/2, w/2, h/2, secondRT, 0, 0, 0, tocolor(255,255,255,255))
	dxDrawImage(0, 0, w, h, imgRefractShader, 0, 0, 0, tocolor(255,255,255,255))
	--lolz we need a fallback shader if the camera is under water
end
end, true, "high+2.5")