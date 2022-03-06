--
-- c_fxaa.lua
--
-- Post-Process Anti Aliasing technique 
-- FXAA technique and original code is copyright (C) NVIDIA by Timothy Lottes
-- Original source: Master Effect 1.6 Shader Suite by Marty McFly

local orderPriority = "-2.5"	-- The lower this number, the later the effect is applied

local maxAntialiasing = 8		-- The maximum number of antialiaisng passes.

Settings = {}
Settings.var = {}  
aaEffectEnabled = false
----------------------------------------------------------------
-- enableFxaa
----------------------------------------------------------------
function enableFxaa()
	if aaEffectEnabled then return end
	-- Create things
    myScreenSource = dxCreateScreenSource( scx, scy )
	fxaaShader,tecName = dxCreateShader( "fx/FXAA.fx" )
	outputDebugString( "fxaaShader is using technique " .. tostring(tecName) )

	-- Get list of all elements used
	effectParts = {
						myScreenSource,
						fxaaShader,
					}

	-- Check list of all elements used
	bAllValid = true
	for _,part in ipairs(effectParts) do
		bAllValid = part and bAllValid
	end

	setEffectVariables ()
	aaEffectEnabled = true
	
end

----------------------------------------------------------------
-- disableFxaa
----------------------------------------------------------------
function disableFxaa()
	if not aaEffectEnabled then return end
	-- Destroy all shaders
	for _,part in ipairs(effectParts) do
		if part then
			destroyElement( part )
		end
	end
	effectParts = {}
	bAllValid = false
	RTPool.clear()

	-- Flag effect as stopped
	aaEffectEnabled = false
end

---------------------------------
-- Settings for effect
---------------------------------
function setEffectVariables()
    local v = Settings.var

	-- Debugging
    v.PreviewEnable=0
    v.PreviewPosY=0
    v.PreviewPosX=100
    v.PreviewSize=70
	
	applySettings(v)
end

function applySettings(v)
	if not fxaaShader then return end
	dxSetShaderValue(fxaaShader, "fViewportSize", scx, scy)
	dxSetShaderValue(fxaaShader, "fViewportScale", 1, 1)
	dxSetShaderValue(fxaaShader, "fViewportPos", 0, 0)
end
-----------------------------------------------------------------------------------
-- onClientHUDRender
-----------------------------------------------------------------------------------
addEventHandler( "onClientHUDRender", root,
    function()
		if not bAllValid or not Settings.var then return end
		local v = Settings.var
		
		-- Reset render target pool
		RTPool.frameStart()
		DebugResults.frameStart()

		-- Update screen
		dxUpdateScreenSource( myScreenSource, true )

		-- Start with screen
		local current = myScreenSource
			
		current = applyFXAA( current )		

		-- When we're done, turn the render target back to default
		dxSetRenderTarget()

		if current then dxDrawImage( 0, 0, scx, scy, current) end
			
		-- Debug stuff
		if v.PreviewEnable > 0.5 then
			DebugResults.drawItems ( v.PreviewSize, v.PreviewPosX, v.PreviewPosY )
		end
    end
,true ,"low" .. orderPriority )


----------------------------------------------------------------
-- Apply the different stages
----------------------------------------------------------------
function applyFXAA( Src )
	if not Src then return nil end
	local mx,my = dxGetMaterialSize( Src )
	local scrRes = {mx,my}
	local newRT = RTPool.GetUnused(mx,my)
	if not newRT then return nil end
	dxSetRenderTarget( newRT, true )
	dxSetShaderValue( fxaaShader, "sTex0", Src )
	dxDrawImage( 0, 0, mx, my, fxaaShader ) 

	DebugResults.addItem( newRT, 'fxaa' )
	return newRT
end

----------------------------------------------------------------
-- Avoid errors messages when memory is low
----------------------------------------------------------------
_dxDrawImage = dxDrawImage
function xdxDrawImage(posX, posY, width, height, image, ... )
	if not image then return false end
	return _dxDrawImage( posX, posY, width, height, image, ... )
end