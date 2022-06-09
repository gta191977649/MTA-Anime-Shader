--
-- c_main.lua
--

-- settings
local distFade = {400, 350}
local tessBall = 45

local scx, scy = guiGetScreenSize()
local cubeRxy = 512 * math.modf(math.min(scx, scy) / 512) -- resolution of cube textures (sets 1024x1024 or 512x512)
local texRx, texRy = guiGetScreenSize() -- resolution of equirectangular and spherical texture
-- render target resolutions should be exact or lower than screen resolution
local sphereFlipView = false -- change sphere map orientation

local isThisOn = false
isSm3MrtSupported = (tonumber(dxGetStatus().VideoCardPSVersion) > 2) and (tonumber(dxGetStatus().VideoCardNumRenderTargets) > 1)
fxTable = {}


textureRemoveList = {
						"","basketball2","skybox_tex*","flashlight_*","font*","radar*","sitem16","snipercrosshair",
						"siterocket","cameracrosshair","*shad*","coronastar","coronamoon","coronaringa","coronaheadlightline",
						"lunar","tx*","lod*","cj_w_grad","*cloud*","*smoke*","sphere_cj","boatwake*","splash_up","carsplash_*",
						"fist","*icon","headlight*","unnamed","sphere"
					}

textureApplyList = {
						"ws_tunnelwall2smoked", "shadover_law","greenshade_64", "greenshade2_64", "venshade*", 
						"blueshade2_64","blueshade4_64","greenshade4_64","metpat64shadow","bloodpool_*"
					}
					
local camParam = {
	{id = 1, name = "posx.png", ori = "right", fwVec = {1,0,0}, upVec = {0,0,1} },
	{id = 2, name = "negx.png", ori = "left", fwVec = {-1,0,0}, upVec = {0,0,1} },
	{id = 3, name = "posy.png", ori = "up", fwVec = {0,0,1}, upVec = {0,-1,0} },
	{id = 4, name = "negy.png", ori = "down", fwVec = {0,0,-1}, upVec = {0,1,0} },
	{id = 5, name = "posz.png", ori = "front", fwVec = {0,1,0}, upVec = {0,0,1} },
	{id = 6, name = "negz.png", ori = "back", fwVec = {0,-1,0}, upVec = {0,0,1} }
				}

local idTex = 0
addEventHandler( "onClientPreRender", root, 
function()
	if not isThisOn then return end
	idTex = idTex + 1
	if (idTex > 6) then 
		idTex = 1
		local tx, ty, tz, bx, by, bz = getSkyGradient()
		camPosX, camPosY, camPosZ = getCameraMatrix()
		dxSetShaderValue( fxTable.inWrdShader, "sCameraPosition", camPosX, camPosY, camPosZ )		
		dxSetShaderValue( fxTable.outEquiShader, "sCameraPosition", camPosX, camPosY, camPosZ )
		dxSetShaderValue( fxTable.outSpheShader, "sCameraPosition", camPosX, camPosY, camPosZ )
		dxSetShaderValue( fxTable.inSkyShader, "sCameraPosition", camPosX, camPosY, camPosZ )
		dxSetShaderValue( fxTable.inSkyShader, "fSkyTop", tx/255, ty/255, tz/255 )
		dxSetShaderValue( fxTable.inSkyShader, "fSkyBot", bx/255, by/255, bz/255 )
		dxSetShaderValue( fxTable.outEquiSkyShader, "fSkyTop", tx/255, ty/255, tz/255 )
		dxSetShaderValue( fxTable.outEquiSkyShader, "fSkyBot", bx/255, by/255, bz/255 )
		dxSetShaderValue( fxTable.outSpheSkyShader, "fSkyTop", tx/255, ty/255, tz/255 )
		dxSetShaderValue( fxTable.outSpheSkyShader, "fSkyBot", bx/255, by/255, bz/255 )
	end
		
	dxSetShaderValue( fxTable.inWrdShader, "sCameraForward", camParam[idTex].fwVec[1], camParam[idTex].fwVec[2], camParam[idTex].fwVec[3] )
	dxSetShaderValue( fxTable.inWrdShader, "sCameraUp", camParam[idTex].upVec[1], camParam[idTex].upVec[2], camParam[idTex].upVec[3] )
		
	dxSetShaderValue( fxTable.outEquiShader, "iFaceNr" , camParam[idTex].id )		
	dxSetShaderValue( fxTable.outEquiShader, "sCameraForward", camParam[idTex].fwVec[1], camParam[idTex].fwVec[2], camParam[idTex].fwVec[3] )
	dxSetShaderValue( fxTable.outEquiShader, "sCameraUp", camParam[idTex].upVec[1], camParam[idTex].upVec[2], camParam[idTex].upVec[3] )
	
	dxSetShaderValue( fxTable.outSpheShader, "iFaceNr" , camParam[idTex].id )		
	dxSetShaderValue( fxTable.outSpheShader, "sCameraForward", camParam[idTex].fwVec[1], camParam[idTex].fwVec[2], camParam[idTex].fwVec[3] )
	dxSetShaderValue( fxTable.outSpheShader, "sCameraUp", camParam[idTex].upVec[1], camParam[idTex].upVec[2], camParam[idTex].upVec[3] )
		
	dxSetShaderValue( fxTable.inSkyShader, "iFaceNr" , camParam[idTex].id )	
	dxSetShaderValue( fxTable.inSkyShader, "sCameraForward", camParam[idTex].fwVec[1], camParam[idTex].fwVec[2], camParam[idTex].fwVec[3] )
	dxSetShaderValue( fxTable.inSkyShader, "sCameraUp", camParam[idTex].upVec[1], camParam[idTex].upVec[2], camParam[idTex].upVec[3] )

	-- Clear third render target
	dxSetRenderTarget( fxTable.colorRT, true )
	dxSetRenderTarget( fxTable.depthRT, false )
	dxDrawRectangle( 0, 0, scx, scy )
	dxSetRenderTarget()	
	
	if isSyncCam then 
		if camPosX then
			setCameraMatrix(camPosX, camPosY, camPosZ, camPosX + camParam[idTex].fwVec[1], camPosY + camParam[idTex].fwVec[2], camPosZ + camParam[idTex].fwVec[3])
		end
	end
end
,true, "high+5")

addEventHandler( "onClientResourceStart", resourceRoot, function()
	if not isSm3MrtSupported then 
		outputChatBox( "cam2_image3d_reflection_texture_gen: Shader Model 3 or MRT in Pixel Shader not supported", 255, 0, 0 )
		return
	end
	-- Create stuff
	fxTable.inSkyShader = dxCreateShader ( "fx/image3d_drawSky.fx" )
	fxTable.outEquiShader = dxCreateShader ( "fx/image3d_1texSwitch2equirectangularTex.fx" )
	fxTable.outSpheShader = dxCreateShader ( "fx/image3d_1texSwitch2sphericalTex.fx" )
	fxTable.outEquiSkyShader = dxCreateShader ( "fx/image3d_equirectangularSkyTex.fx" )
	fxTable.outSpheSkyShader = dxCreateShader ( "fx/image3d_sphericalSkyTex.fx" )
	fxTable.texCubeXZ = dxCreateTexture( "tex/cube_xz.png" )
	fxTable.postSpheShader = dxCreateShader ( "fx/image3d_equirectangular2animSphere.fx" )
	fxTable.postViewShader = dxCreateShader ( "fx/image3d_equirectangular2view.fx" )
	fxTable.post3DBallShader = dxCreateShader ( "fx/image4d_lightBall.fx" )
	fxTable.inWrdShader = dxCreateShader ( "fx/cam2RTScreen_world.fx", 0, distFade[1], true, "world,ped,object,vehicle" )
	fxTable.outRefShader = dxCreateShader ( "fx/car_paint_ref.fx", 1, distFade[1], false, "vehicle" )
	fxTable.colorRT = dxCreateRenderTarget ( scx, scy, true )
	fxTable.depthRT = dxCreateRenderTarget ( scx, scy, true )
	fxTable.outCombEquiRT = dxCreateRenderTarget ( scx, scy, true )
	fxTable.outCombSpheRT = dxCreateRenderTarget ( scx, scy, true )
	fxTable.outEquiRT = dxCreateRenderTarget ( scx, scy, false )
	fxTable.outSpheRT = dxCreateRenderTarget ( scx, scy, false ) 

	fxList = {fxTable.inSkyShader, fxTable.outEquiShader, fxTable.outEquiSkyShader, fxTable.outSpheShader, fxTable.outSpheShader, fxTable.postSpheShader, 
		fxTable.postViewShader, fxTable.post3DBallShader,  fxTable.inWrdShader, fxTable.outRefShader, fxTable.colorRT, fxTable.depthRT, fxTable.outCombEquiRT, 
		fxTable.outCombSpheRT, fxTable.outEquiRT, fxTable.outSpheRT, fxTable.texCubeXZ}
	-- Check list of all elements used
	bAllValid = true
	for _,part in ipairs(fxList) do
		bAllValid = part and bAllValid
	end
	if not bAllValid then
		outputChatBox( "cam2_image3d_reflection_texture_gen: Could not create Shaders or Render Targets", 255, 0, 0 )
	else
		outputChatBox( "cam2_image3d_reflection_texture_gen: Started", 0, 255, 0 )
		outputChatBox( "It is advised to turn off ENB/Ultra Thing/Reshade", 255, 125, 0 )		
		outputChatBox( "Hit 1 to Point main camera matrix at 6 sides to stream in all objects" )
		outputChatBox( "Hit 2 to Save to equirectangular map and draw reflection sphere" )
		outputChatBox( "Hit 3 to Save to sphere map" )
		outputChatBox( "Hit 4 to Save to 6 sides of cube map" )
			
		local camPosX, camPosY, camPosZ = getCameraMatrix()

		-- Apply shader to all world textures
		local tx, ty, tz, bx, by, bz = getSkyGradient()
		dxSetShaderValue( fxTable.inSkyShader, "fSkyTop", tx/255, ty/255, tz/255 )
		dxSetShaderValue( fxTable.inSkyShader, "fSkyBot", bx/255, by/255, bz/255 )

		dxSetShaderValue( fxTable.outEquiSkyShader, "fSkyTop", tx/255, ty/255, tz/255 )
		dxSetShaderValue( fxTable.outEquiSkyShader, "fSkyBot", bx/255, by/255, bz/255 )
		dxSetShaderValue( fxTable.outSpheSkyShader, "fSkyTop", tx/255, ty/255, tz/255 )
		dxSetShaderValue( fxTable.outSpheSkyShader, "fSkyBot", bx/255, by/255, bz/255 )		

		dxSetShaderValue( fxTable.inSkyShader, "sCameraPosition", camPosX, camPosY, camPosZ )
		dxSetShaderValue( fxTable.inSkyShader, "sCameraForward", 0, 1, 0 )
		dxSetShaderValue( fxTable.inSkyShader, "sCameraUp", 0, 0, 1 )
		dxSetShaderValue( fxTable.inSkyShader, "sFov", math.rad(90) )
		dxSetShaderValue( fxTable.inSkyShader, "sClip", 0.3, distFade[1] )
			
		dxSetShaderValue( fxTable.outEquiShader, "sCameraPosition", camPosX, camPosY, camPosZ )
		dxSetShaderValue( fxTable.outEquiShader, "sCameraForward", 0, 1, 0 )
		dxSetShaderValue( fxTable.outEquiShader, "sCameraUp", 0, 0, 1 )
		
		dxSetShaderValue( fxTable.outSpheShader, "sCameraPosition", camPosX, camPosY, camPosZ )
		dxSetShaderValue( fxTable.outSpheShader, "sCameraForward", 0, 1, 0 )
		dxSetShaderValue( fxTable.outSpheShader, "sCameraUp", 0, 0, 1 )
		dxSetShaderValue( fxTable.outSpheShader, "bFlipView", sphereFlipView )
		
		dxSetShaderValue( fxTable.outSpheSkyShader, "bFlipView", sphereFlipView )

		dxSetShaderValue( fxTable.outEquiSkyShader, "sTexture", fxTable.texCubeXZ )		
		dxSetShaderValue( fxTable.outSpheSkyShader, "sTexture", fxTable.texCubeXZ )
	
		dxSetShaderValue( fxTable.outRefShader, "sTexture_ref", fxTable.outEquiRT )
		engineApplyShaderToWorldTexture( fxTable.outRefShader, "vehiclegrunge256" )
		engineApplyShaderToWorldTexture( fxTable.outRefShader, "vehiclegeneric256" )
		engineApplyShaderToWorldTexture( fxTable.outRefShader, "?emap*" )					
			
		dxSetShaderValue( fxTable.outEquiShader, "sTexture_wrdFace", fxTable.colorRT )
		dxSetShaderValue( fxTable.outEquiShader, "iFaceNr" , 1 ) -- 1 - 6
		
		dxSetShaderValue( fxTable.outSpheShader, "sTexture_wrdFace", fxTable.colorRT )
		dxSetShaderValue( fxTable.outSpheShader, "iFaceNr" , 1 ) -- 1 - 6
			
		dxSetShaderValue( fxTable.inWrdShader, "sScrRes", 1, 1 )
		dxSetShaderValue( fxTable.inWrdShader, "sPixelSize", 1 / scx, 1 / scy )
		dxSetShaderValue( fxTable.inWrdShader, "sCameraPosition", camPosX, camPosY, camPosZ )
		dxSetShaderValue( fxTable.inWrdShader, "sCameraForward", 0, 1, 0 )
		dxSetShaderValue( fxTable.inWrdShader, "sCameraUp", 0, 0, 1 )
		dxSetShaderValue( fxTable.inWrdShader, "sFov", math.rad(90) )
		dxSetShaderValue( fxTable.inWrdShader, "sClip", 0.3, distFade[1] )
		dxSetShaderValue( fxTable.inWrdShader, "sScaleRenderTarget", 1, 1 )
		dxSetShaderValue( fxTable.inWrdShader, "colorRT", fxTable.colorRT )
		dxSetShaderValue( fxTable.inWrdShader, "depthRT", fxTable.depthRT )
			
		dxSetShaderValue( fxTable.inWrdShader, "gDistFade", distFade[1], distFade[2] )

		dxSetShaderValue( fxTable.post3DBallShader, "sElementRotation", 0, 0, -10 )
		dxSetShaderValue( fxTable.post3DBallShader, "sElementRotation", math.rad(90), 0, 0 )
		dxSetShaderValue( fxTable.post3DBallShader, "sElementSize", 5, 5, 5 )
		dxSetShaderValue( fxTable.post3DBallShader, "sRefTexture", 0 )
		dxSetShaderValue( fxTable.post3DBallShader, "sSubdivUnit", 1 / tessBall, 1 / tessBall )
			
		dxSetShaderTessellation( fxTable.post3DBallShader, tessBall, tessBall )
			
		engineApplyShaderToWorldTexture( fxTable.inWrdShader, "*" )	
		for _,removeMatch in ipairs( textureRemoveList ) do
			engineRemoveShaderFromWorldTexture( fxTable.inWrdShader, removeMatch )	
		end	
		for _,applyMatch in ipairs( textureApplyList ) do
			engineApplyShaderToWorldTexture( fxTable.inWrdShader, applyMatch )	
		end		
			
		dxSetShaderValue( fxTable.postSpheShader, "fScreenSize", scx, scy )
		dxSetShaderValue( fxTable.postSpheShader, "sTexture_ref", fxTable.outEquiRT )
		
		dxSetShaderValue( fxTable.postViewShader, "fScreenSize", scx, scy )
		dxSetShaderValue( fxTable.postViewShader, "sTexture_ref", fxTable.outEquiRT )
			
		isThisOn = true
	end
end)

addEventHandler( "onClientHUDRender", root, function()
	if not isThisOn then return end
	if idTex == 1 then isRTClear = true else isRTClear = false end
	dxSetRenderTarget(fxTable.outCombEquiRT, isRTClear) 
	dxDrawImage( 0, 0, scx, scy, fxTable.outEquiShader )
	dxSetRenderTarget(fxTable.outCombSpheRT, isRTClear) 
	dxDrawImage( 0, 0, scx, scy, fxTable.outSpheShader )	
	if idTex == 6 then
		dxSetRenderTarget(fxTable.outEquiRT, true)
		dxDrawImage( 0, 0, scx, scy, fxTable.outEquiSkyShader )
		dxDrawImage( 0, 0, scx, scy, fxTable.outCombEquiRT )
		dxSetRenderTarget(fxTable.outSpheRT, true) 
		dxDrawImage( 0, 0, scx, scy, fxTable.outSpheSkyShader )
		dxDrawImage( 0, 0, scx, scy, fxTable.outCombSpheRT )	
	end
	dxSetRenderTarget()
	dxDrawImage( 0, 0, scx, scy, fxTable.post3DBallShader )
end
,true, "high+5")

addEventHandler( "onClientRender", root, function()
	if not isThisOn then return end
	dxDrawImage( 0, 0, scx / 4, scy / 4, fxTable.outSpheRT )
	dxDrawImage( scx / 4, 0, scx / 4, scy / 4, fxTable.outEquiRT )
	dxDrawImage( 2 * scx / 4, 0, scx / 4, scy / 4, fxTable.postSpheShader )
	dxDrawImage( 3 * scx / 4, 0, scx / 4, scy / 4, fxTable.postViewShader )
end
,true, "high+5")

addEventHandler( "onClientResourceStart", resourceRoot, function()
	bindKey("1", "down", 
		function() 
			isSyncCam = not isSyncCam 
			if not isSyncCam then 
				setCameraTarget( localPlayer ) 
			end 
		end)
	bindKey( "2", "down", get1EquiTexOut )
	bindKey( "3", "down", get1SpheTexOut )
	bindKey( "4", "down", 
		function() 
			if not getCube then 
				outputChatBox( "Saving 6 cube textures.." ) 
				addEventHandler( "onClientHUDRender", root, get6CubeTexOut, true, "high+4" )
			end 
		end)
end)

addEventHandler( "onClientResourceStop", resourceRoot, function()
	setCameraTarget(localPlayer)
end)

local getCube = false
local saveCubeRT = nil

function get6CubeTexOut()
	if not isThisOn then return end
	if not saveCubeRT then 
		saveCubeRT = dxCreateRenderTarget( cubeRxy, cubeRxy, false )
	end
	if (idTex == 1) then
		getCube = true	
	end
	if getCube then
		dxSetRenderTarget( saveCubeRT, true )	
		dxDrawImage( 0, 0, cubeRxy, cubeRxy, fxTable.inSkyShader )
		dxDrawImage( 0, 0, cubeRxy, cubeRxy, fxTable.colorRT )
		dxSetRenderTarget()
		saveEquiRTToFile( "cubeTexOUT", "_"..camParam[idTex].name, saveCubeRT )		
	end
	if getCube and (idTex == 6) then 
		getCube = false
		removeEventHandler("onClientHUDRender", root, get6CubeTexOut, true, "high+4")
	end
end

local saveEquiRT = nil
function get1EquiTexOut()
	if not isThisOn then return end
	if not saveEquiRT then 
		saveEquiRT = dxCreateRenderTarget( texRx, texRy, false )
	end
	if not saveEquiRT then return end
	dxSetRenderTarget( saveEquiRT, true )
	dxDrawImage( 0, 0, texRx, texRy, fxTable.outEquiRT, 0, 0, 0, tocolor(255,255,255,255) )
	dxSetRenderTarget()
	saveEquiRTToFile( "equirectangularTexOUT", ".png", saveEquiRT )
	
	local camX, camY, camZ = getCameraMatrix()
	dxSetShaderValue( fxTable.post3DBallShader, "sElementPosition", camX, camY, camZ )
	dxSetShaderValue( fxTable.post3DBallShader, "sRefTexture", saveEquiRT )
end

local saveSpheRT = nil
function get1SpheTexOut()
	if not isThisOn then return end
	if not saveSpheRT then 
		saveSpheRT = dxCreateRenderTarget( texRx, texRy, false )
	end
	if not saveSpheRT then return end
	dxSetRenderTarget( saveSpheRT, true )
	dxDrawImage( 0, 0, texRx, texRy, fxTable.outSpheRT, 0, 0, 0, tocolor(255,255,255,255) )
	dxSetRenderTarget()
	saveEquiRTToFile( "sphericalTexOUT", ".png", saveSpheRT )
end

function getFreeFilePath( filePath, fileID, fileExt )
	while fileExists( filePath..fileID..fileExt, true ) do
		fileID = fileID + 1
	end
	outputChatBox('Saving RT to file: /'..filePath..fileID..fileExt )
	return filePath..fileID..fileExt
end

function saveEquiRTToFile( filePath, fileExt, thisRT )
	if not ( dxGetStatus().AllowScreenUpload ) then
		return false 
	end
	if thisRT then
		local rtPixels = dxGetTexturePixels ( thisRT )
		rtPixels = dxConvertPixels( rtPixels, 'png' )
		isValid = rtPixels and true
		local thisPath = getFreeFilePath( filePath, 0, fileExt )

		local file = fileCreate( thisPath )
		isValid = fileWrite( file, rtPixels ) and isValid
		isValid = fileClose( file ) and isValid
		return isValid
	end
	return false
end
