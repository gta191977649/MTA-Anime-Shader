--
-- c_switch.lua
--

----------------------------------------------------------------
----------------------------------------------------------------
-- Effect switching on and off
--
--	To switch on:
--			triggerEvent( "switchFxaa", root, 2 )
--
--	To switch off:
--			triggerEvent( "switchFxaa", root, 0 )
--
----------------------------------------------------------------
----------------------------------------------------------------

--------------------------------
-- onClientResourceStart
--		Auto switch on at start
--------------------------------
addEventHandler( "onClientResourceStart", getResourceRootElement( getThisResource()),
	function()
		if tonumber(dxGetStatus().VideoCardPSVersion) < 3 then 
			outputChatBox('fxaa: Shader Model 3 not supported',255,0,0) 
			return 
		end
		triggerEvent( "switchFxaa", resourceRoot, true )
		addCommandHandler( "sFxaa",
			function()
				triggerEvent( "switchFxaa", resourceRoot, not aaEffectEnabled )
			end
		)
	end
)


--------------------------------
-- Switch effect on or off
--------------------------------
function switchFxaa( aaOn )
	outputDebugString( "switchFxaa: " .. tostring(aaOn) )
	if aaOn then
		enableFxaa()
	else
		disableFxaa()
	end
end

addEvent( "switchFxaa", true )
addEventHandler( "switchFxaa", resourceRoot, switchFxaa )
