--
-- c_water_ref.lua
--

local scx, scy = guiGetScreenSize()

local removeList = {
						"",	                                                       -- unnamed
						"basketball2","skybox_tex*","flashlight_*",                -- other
						"muzzle_texture*",                                         -- guns
						"font*","radar*","sitem16","snipercrosshair",              -- hud
						"siterocket","cameracrosshair",                            -- hud
						"fireba*","wjet6",                                         -- flame
						--"vehiclegeneric256","vehicleshatter128",                 -- vehicles
						"*shad*",                                                  -- shadows
						"coronastar","coronamoon",
						"coronaheadlightline",                                     -- coronas
						"lunar",                                                   -- moon
						"coronaringa",
						"tx*",                                                     -- grass effect
						"cj_w_grad",                                               -- checkpoint texture
						"*cloud*",                                                 -- clouds
						"*smoke*",                                                 -- smoke
						"sphere_cj",                                               -- nitro heat haze mask
						"particle*",                                               -- particle skid and maybe others
						"water*","newaterfal1_256",
						"boatwake*","splash_up","carsplash_*",
						"boatsplash",
						"gensplash","wjet4","bubbles","blood*",                    -- splash
						"fist","*icon","headlight*",
						"unnamed","sphere",	
						"sl_dtwinlights*","nitwin01_la","sfnite*","shad_exp",
						"vgsn_nl_strip","blueshade*",
						"royaleroof01_64","flmngo05_256","flmngo04_256",
						"casinolights6lit3_256"                                    -- some shinemaps and anims
					}
					
addEventHandler( "onClientResourceStart", getResourceRootElement( getThisResource()),
	function()

		if getVersion ().sortable < "1.3.3" then
			outputChatBox( "Resource is not compatible with this client." )
			return
		end

		watShader, tec = dxCreateShader ( "water_ref.fx" )
		wrdShader, tec = dxCreateShader ( "world_ref.fx",2,0,false,"world,vehicle,ped,object" )
		if not watShader or not wrdShader then
			outputChatBox( "Water refract test v1.7: Could not create shader." )
		else
          
			local textureVol = dxCreateTexture ( "images/wavemap.png" )
			dxSetShaderValue ( watShader, "sRandomTexture", textureVol )
			dxSetShaderValue ( watShader, "normalMult", 0.07 )
			dxSetShaderValue ( watShader, "gDistFade", 390, 160 )

			engineApplyShaderToWorldTexture ( watShader, "waterclear256" )
			engineApplyShaderToWorldTexture ( wrdShader, "*" )
			setWaterDrawnLast(true)
			for _,name in ipairs(getElementsByType("player")) do
				if getElementAlpha(name)>254 then setElementAlpha(name,254) end
			end
			for _,name in ipairs(removeList) do
			engineRemoveShaderFromWorldTexture ( wrdShader, name )			
			end
			setTimer(	function()
							if watShader then
								local r,g,b,a = getWaterColor()
								local posX,posY,posZ = getElementPosition( getCamera() )
								local wLevel = getWaterLevel( posX, posY, posZ )
								if wLevel then dxSetShaderValue ( wrdShader, "fWatLevel", wLevel ) end
								dxSetShaderValue ( watShader, "sWaterColor", r/255, g/255, b/255, a/255 )
							end
						end
						,100,0 )
		end
	end
,true ,"high")

local ScreenInput = dxCreateScreenSource( scx/2, scy/2)
local ScreenOutput = dxCreateScreenSource( scx, scy)

addEventHandler ( "onClientHUDRender", root , function()
	if watShader and wrdShader then
		if (not drawFrame) then
			dxUpdateScreenSource( ScreenOutput,true)
			dxSetShaderValue ( watShader, "gAlpha" ,0.01)
			dxSetShaderValue ( wrdShader, "bInvert" ,true)
			dxSetShaderValue ( wrdShader, "fFogEnable", false)
			dxSetShaderValue ( wrdShader, "fCull", 3)
		else
			dxUpdateScreenSource( ScreenInput,false)
			dxSetShaderValue ( watShader, "sReflectionTexture", ScreenInput );
			dxSetShaderValue ( watShader, "gAlpha" ,0.8)
			dxSetShaderValue ( wrdShader, "bInvert" ,false)
			dxSetShaderValue ( wrdShader, "fFogEnable", true)
			dxSetShaderValue ( wrdShader, "fCull", 1)
		end
		drawFrame= not drawFrame
		dxDrawImage( 0, 0, scx, scy, ScreenOutput, 0,0,0)
	end
end
)

