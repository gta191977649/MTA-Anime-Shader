local SunInstance = nil

SunShader = {}
resetSunSize()
resetSunColor()
resetSkyGradient()
resetFarClipDistance()
resetFogDistance()
--setCloudsEnabled(true)
function SunShader:constructor()
	
	self.shadersEnabled = "false"
	self.screenWidth, self.screenHeight = guiGetScreenSize()
	
	self.lensFlareDirt = dxCreateTexture("Textures/lensflare_dirt.png")
	self.lensFlareChroma = dxCreateTexture("Textures/lensflare_chroma.png")
	
	self.viewDistance = 0.00005
	
	self.sunColorInner = {0.9, 0.7, 0.6, 1}
	self.sunColorOuter = {0.85, 0.65, 0.55, 1}
	self.sunSize = 0.04
	
	self.excludingTextures = 	{	"waterclear256",
									"*smoke*",
									"*particle*",
									"*cloud*",
									"*splash*",
									"*corona*",
									"*sky*",
									"*radar*",
									"*wgush1*",
									"*debris*",
									"*wjet4*",
									"*gun*",
									"*wake*",
									"*effect*",
									"*fire*",
									"muzzle_texture*",
									"*font*",
									"*icon*",
									"shad_exp",
									"*headlight*", 
									"*corona*",
									"sfnitewindow_alfa", 
									"sfnitewindows", 
									"monlith_win_tex", 
									"sfxref_lite2c",
									"dt_scyscrap_door2", 
									"white", 
									"casinolights*",
									"cj_frame_glass", 
									"custom_roadsign_text", 
									"dt_twinklylites",
									"vgsn_nl_strip", 
									"unnamed", 
									"white64", 
									"lasjmslumwin1",
									"pierwin05_law", 
									"nitwin01_la", 
									"sl_dtwinlights1", 
									"fist",
									"sphere",
									"*spark*",
									"glassmall",
									"*debris*",
									"wgush1",
									"wjet2",
									"wjet4",
									"beastie",
									"bubbles",
									"pointlight",
									"unnamed",
									"txgrass1_1", 
									"txgrass0_1", 
									"txgrass1_0",
									"item*",
									"undefined*",
									"coin*",
									"turbo*",
									"lava*",
									"ampelLight*",
									"*shad*",
									"cj_w_grad"}

	
	self.m_Update = function() self:update() end
	addEventHandler("onClientHUDRender", root, self.m_Update)
	
	self.m_ToggleShaders = function() self:toggleShaders() end
	--bindKey("M", "down", self.m_ToggleShaders)
	
	self:createShaders()
	
	self.sun = new(Sun, self)	
end



function SunShader:toggleShaders()
	if (self.shadersEnabled == "true") then
		self:removeShaders()
		
		if (self.sun) then
			self.sun.isDebugMode = "false"
		end
	elseif (self.shadersEnabled == "false") then
		self:createShaders()
	end
end

function SunShader:createShaders()
	if (self.shadersEnabled == "false") then
		self.screenSource = dxCreateScreenSource(self.screenWidth, self.screenHeight)
		self.renderTargetBW = dxCreateRenderTarget(self.screenWidth, self.screenHeight)
		self.renderTargetSun = dxCreateRenderTarget(self.screenWidth, self.screenHeight)
		self.renderTargetGodRaysBase = dxCreateRenderTarget(self.screenWidth, self.screenHeight)
		self.renderTargetGodRays = dxCreateRenderTarget(self.screenWidth, self.screenHeight)
		self.bwShader = dxCreateShader("Shaders/bw.fx")
		self.godRayBaseShader = dxCreateShader("Shaders/godRayBase.fx")
		self.sunShader = dxCreateShader("Shaders/sun.fx")
		self.godRayShader = dxCreateShader("Shaders/godrays.fx")
		self.lensFlareShader = dxCreateShader("Shaders/lensflares.fx")
		self.dynamicLightShader = dxCreateShader("Shaders/dynamiclight.fx", 1000, 0, false, "world,ped,object,other")
		self.vehicleShader = dxCreateShader("Shaders/vehicle.fx", 1000, 0, false, "vehicle")
		
		if (not self.dynamicLightShader) or (not self.vehicleShader) or (not self.bwShader) or (not self.godRayBaseShader) or (not self.sunShader) or (not self.godRayShader) or (not self.lensFlareShader) or (not self.screenSource) or (not self.renderTargetBW) or (not self.renderTargetSun) or (not self.renderTargetGodRaysBase) or (not self.renderTargetGodRays) then
			outputChatBox("Loading sun shader failed. Please use debugscript 3 for further details")
			
			self:removeShaders()
		else
			--engineApplyShaderToWorldTexture(self.dynamicLightShader, "*")
			--engineApplyShaderToWorldTexture(self.vehicleShader, "*")
			

			for _, texture in ipairs(self.excludingTextures) do
				engineRemoveShaderFromWorldTexture(self.dynamicLightShader, texture)
			end	
			
			self.shadersEnabled = "true"
		end
	end
end

function SunShader:update()
	local h, _ = getTime()
	if (self.dynamicLightShader) and (self.vehicleShader) and (self.bwShader) and (self.godRayBaseShader) and (self.sunShader) and (self.godRayShader) and (self.lensFlareShader) and (self.screenSource) and (self.renderTargetBW) and (self.renderTargetSun) and (self.renderTargetGodRaysBase) and (self.renderTargetGodRays) and h < 20 then	
		if (self.sun) then
			
			self.sunX, self.sunY, self.sunZ = self.sun:getSunPosition()
			self.sunScreenX, self.sunScreenZ = getScreenFromWorldPosition(self.sunX, self.sunY, self.sunZ, 1, true)
			
			-- check if can see through
			local px,py,pz = getElementPosition(getLocalPlayer())
			if getElementInterior(localPlayer) == 0 then
				self.sunSize = getSunSize () 
			else
				self.sunSize = 0
			end
			--[[
			if isLineOfSightClear(px, py, pz, self.sunX, self.sunY, self.sunZ) then 
				self.sunSize = getSunSize () 
			else 
				self.sunSize = 0
			end
			]]

			local inX,inY,inZ,outX,outY,outZ = getSunColor ()
			--print(inX)
			self.sunColorInner = {inX/255,inY/255,inZ/255,1}
			self.sunColorOuter = {outX/255,outY/255,outZ/255,1}
			dxUpdateScreenSource(self.screenSource)	


			--showPlayerHudComponent("all", true)
			--setTime(12,0)
			--setSunSize(0)
			--setSunColor (0, 0, 0, 0, 0, 0)
			--setSkyGradient(90, 85, 120, 120, 130, 175)
			--setCloudsEnabled(false)
			--setFarClipDistance(1200)
			--setFogDistance(850)
			
			-- object lighting
			--[[
			dxSetShaderValue(self.dynamicLightShader, "sunPos", {self.sunX, self.sunY, self.sunZ})
			dxSetShaderValue(self.dynamicLightShader, "sunColor", self.sunColorInner)
			dxSetShaderValue(self.dynamicLightShader, "ambientColor", self.sunColorOuter)
			
			-- vehicle lighting
			dxSetShaderValue(self.vehicleShader, "sunPos", {self.sunX, self.sunY, self.sunZ})
			dxSetShaderValue(self.vehicleShader, "sunColor", self.sunColorInner)
			dxSetShaderValue(self.vehicleShader, "ambientColor", self.sunColorOuter)
			]]
			
			if (self.sunScreenX) and (self.sunScreenZ) then
				--print("yes")
				-- scenario bw
				dxSetShaderValue(self.bwShader, "screenSource", self.screenSource)
				dxSetShaderValue(self.bwShader, "viewDistance", self.viewDistance)

				dxSetRenderTarget(self.renderTargetBW, true)
				dxDrawImage(0, 0, self.screenWidth, self.screenHeight, self.bwShader)
				dxSetRenderTarget()
				
				-- sun
				dxSetShaderValue(self.sunShader, "screenSource", self.screenSource)
				dxSetShaderValue(self.sunShader, "bwSource", self.renderTargetBW)
				dxSetShaderValue(self.sunShader, "sunPos", {(1 / self.screenWidth) * self.sunScreenX, (1 / self.screenHeight) * self.sunScreenZ})
				dxSetShaderValue(self.sunShader, "sunColorInner", self.sunColorInner)
				dxSetShaderValue(self.sunShader, "sunColorOuter", self.sunColorOuter)
				dxSetShaderValue(self.sunShader, "sunSize", self.sunSize)

				dxSetRenderTarget(self.renderTargetSun, true)
				dxDrawImage(0, 0, self.screenWidth, self.screenHeight, self.sunShader)
				dxSetRenderTarget()

				-- godray base
				dxSetShaderValue(self.godRayBaseShader, "screenSource", self.screenSource)
				dxSetShaderValue(self.godRayBaseShader, "renderTargetBW", self.renderTargetBW)
				dxSetShaderValue(self.godRayBaseShader, "renderTargetSun", self.renderTargetSun)
				dxSetShaderValue(self.godRayBaseShader, "screenSize", {self.screenWidth, self.screenHeight})

				dxSetRenderTarget(self.renderTargetGodRaysBase, true)
				dxDrawImage(0, 0, self.screenWidth, self.screenHeight, self.godRayBaseShader)
				dxSetRenderTarget()
				
				-- godrays
				dxSetShaderValue(self.godRayShader, "sunLight", self.renderTargetGodRaysBase)
				dxSetShaderValue(self.godRayShader, "lensDirt", self.lensFlareDirt)
				dxSetShaderValue(self.godRayShader, "sunPos", {(1 / self.screenWidth) * self.sunScreenX, (1 / self.screenHeight) * self.sunScreenZ})

				dxSetRenderTarget(self.renderTargetGodRays, true)
				dxDrawImage(0, 0, self.screenWidth, self.screenHeight, self.godRayShader)
				dxSetRenderTarget()
				
				
				-- lensflares
		
				dxSetShaderValue(self.lensFlareShader, "screenSource", self.screenSource)
				dxSetShaderValue(self.lensFlareShader, "sunLight", self.renderTargetGodRays)
				--dxSetShaderValue(self.lensFlareShader, "lensDirt", self.lensFlareDirt)
				--dxSetShaderValue(self.lensFlareShader, "lensChroma", self.lensFlareChroma)
				dxSetShaderValue(self.lensFlareShader, "sunPos", {(1 / self.screenWidth) * self.sunScreenX, (1 / self.screenHeight) * self.sunScreenZ})
				dxSetShaderValue(self.lensFlareShader, "sunColor", self.sunColorInner)
				dxSetShaderValue(self.lensFlareShader, "screenSize", {self.screenWidth, self.screenHeight})
				
				--dxDrawImage(0, 0, self.screenWidth, self.screenHeight, self.bwShader)
				--dxDrawImage(0, 0, self.screenWidth, self.screenHeight, self.sunShader)
				--dxDrawImage(0, 0, self.screenWidth, self.screenHeight, self.godRayBaseShader)
				--dxDrawImage(0, 0, self.screenWidth, self.screenHeight, self.godRayShader)
				dxDrawImage(0, 0, self.screenWidth, self.screenHeight, self.lensFlareShader)
			
			end
		end
	end
	

	--[[
		DEBUG WINDOW
	dxDrawRectangle (0, self.screenHeight * 0.5, self.screenWidth * 0.14, self.screenHeight * 0.25, tocolor(0, 0, 0, 150), false)
	dxDrawText("Sun Shader:", 5, self.screenHeight * 0.52, 5, self.screenHeight * 0.52, tocolor (255, 200, 0, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)

	if (getFps()) and (getFps() > 30) then
		dxDrawText("#FFFFFFFPS: #00FF00" .. getFps(), 5, self.screenHeight * 0.56, 5, self.screenHeight * 0.56, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, true, false, 0, 0, 0)
	else
		dxDrawText("#FFFFFFFPS: #FF0000" .. getFps(), 5, self.screenHeight * 0.56, 5, self.screenHeight * 0.56, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, true, false, 0, 0, 0)
	end
	
	dxDrawText("Shaders enabled: " .. self.shadersEnabled, 5, self.screenHeight * 0.58, 5, self.screenHeight * 0.58, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)
	
	if (self.sun) and (self.sunX) and (self.sunY) and (self.sunZ) then
		dxDrawText("Debug enabled: " .. self.sun.isDebugMode, 5, self.screenHeight * 0.60, 5, self.screenHeight * 0.60, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)
		dxDrawText("SunPosX: " .. math.floor(self.sunX + 0.5), 5, self.screenHeight * 0.62, 5, self.screenHeight * 0.62, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)
		dxDrawText("SunPosY: " .. math.floor(self.sunY + 0.5), 5, self.screenHeight * 0.64, 5, self.screenHeight * 0.64, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)		
		dxDrawText("SunPosZ: " .. math.floor(self.sunZ + 0.5), 5, self.screenHeight * 0.66, 5, self.screenHeight * 0.66, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)				
	else
		dxDrawText("Debug enabled: false", 5, self.screenHeight * 0.60, 5, self.screenHeight * 0.60, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)
		dxDrawText("SunPosX: -", 5, self.screenHeight * 0.62, 5, self.screenHeight * 0.62, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)
		dxDrawText("SunPosY: -", 5, self.screenHeight * 0.64, 5, self.screenHeight * 0.64, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)		
		dxDrawText("SunPosZ: -", 5, self.screenHeight * 0.66, 5, self.screenHeight * 0.66, tocolor (255, 255, 255, 200), 1, "default-bold", "left", "center", false, false, false, false, false, 0, 0, 0)				
	end
	
	dxDrawText("Press 'M' to enable/disable shaders.", 5, self.screenHeight * 0.70, 5, self.screenHeight * 0.70, tocolor (255, 128, 0, 200), 0.75, "default-bold", "left", "center", false, false, false, true, false, 0, 0, 0)
	dxDrawText("Press 'N' to enable/disable debugmode.", 5, self.screenHeight * 0.72, 5, self.screenHeight * 0.72, tocolor (255, 128, 0, 200), 0.75, "default-bold", "left", "center", false, false, false, true, false, 0, 0, 0)
	]]
end

function SunShader:removeShaders()
	removeEventHandler("onClientHUDRender", root, self.m_Update)
	
	if (self.dynamicLightShader) then
		destroyElement(self.dynamicLightShader)
		self.dynamicLightShader = nil
	end
	
	if (self.vehicleShader) then
		destroyElement(self.vehicleShader)
		self.vehicleShader = nil
	end

	if (self.bwShader) then
		destroyElement(self.bwShader)
		self.bwShader = nil
	end
	
	if (self.godRayBaseShader) then
		destroyElement(self.godRayBaseShader)
		self.godRayBaseShader= nil
	end
	
	if (self.sunShader) then
		destroyElement(self.sunShader)
		self.sunShader= nil	
	end
	
	if (self.godRayShader) then
		destroyElement(self.godRayShader)
		self.godRayShader= nil	
	end

	if (self.lensFlareShader) then
		destroyElement(self.lensFlareShader)
		self.lensFlareShader= nil	
	end
	
	if (self.screenSource) then
		destroyElement(self.screenSource)
		self.screenSource = nil
	end
	
	if (self.renderTargetBW) then
		destroyElement(self.renderTargetBW)
		self.renderTargetBW = nil
	end
	
	if (self.renderTargetSun) then
		destroyElement(self.renderTargetSun)
		self.renderTargetSun = nil
	end
	
	if (self.renderTargetGodRaysBase) then
		destroyElement(self.renderTargetGodRaysBase)
		self.renderTargetGodRaysBase = nil
	end
	
	if (self.renderTargetGodRays) then
		destroyElement(self.renderTargetGodRays)
		self.renderTargetGodRays = nil
	end
	
	--setTime(12,0)
	resetSunSize()
	resetSunColor()
	resetSkyGradient()
	resetFarClipDistance()
	resetFogDistance()
	--setCloudsEnabled(true)
	
	self.shadersEnabled = "false"
end

function SunShader:destructor()	
	self:removeShaders()
	
	if (self.sun) then
		delete(self.sun)
		self.sun = nil
	end
end

--[[
addEventHandler("onClientResourceStart", resourceRoot, 
function(resource)
	if (resource == getThisResource()) then
		SunInstance = new(SunShader)
	end
end)

addEventHandler("onClientResourceStop", resourceRoot, 
function(resource)
	if (resource == getThisResource()) then
		if (SunInstance) then
			delete(SunInstance)
			SunInstance = nil
		end
	end
end)
]]


addEventHandler("onClientResourceStart", resourceRoot, function(resource)
	resetSunSize()
	resetSunColor()
	resetSkyGradient()
	resetFarClipDistance()
	resetFogDistance()
end)


function switchSun(switch) 
	if switch then 
		if not SunInstance then
			SunInstance = new(SunShader)
			print("Sun shader created")
		end
	else
		if (SunInstance) then
			delete(SunInstance)
			SunInstance = nil
			print("Sun shader stopped")
		end
	end
end
addEvent( "switchSun", true )
addEventHandler( "switchSun", root, switchSun)