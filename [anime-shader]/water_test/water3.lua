--##### SETTINGS #####--

local moonIlluminance = 0.1			-- This value determines how strong the moon should illuminate the water at night
local specularSize = 9.0			-- Lower value = bigger specular lighting from sun (dynamic sky supported)
local flowSpeed = 0.8				-- Movement speed of the water
local reflectionSharpness = 0.06	-- lower value = sharper reflection
local reflectionStrength = 0.9		-- How much reflection?
local refractionStrength = 0.4		-- Strength of the refraction (Only surface refraction, stuff inside water does not get refracted currently)
local causticStrength = 0.3			-- Surface caustic wave effect strength
local causticSpeed = 0.2			-- Caustic movement speed
local causticIterations = 20		-- Caustic detail
local shoreFadeStrength = 0.101		-- lower value = stronger shore fading
setWaterColor(100,225,255,255)		-- i think this water color is pretty

--#######################

local width, height = guiGetScreenSize()
local ScreenInput = dxCreateScreenSource(width/6, height/6)-- Decrease this divisor to increase reflection quality. But anything higher than 1/6 is a waste of memory
local waterNormal = dxCreateTexture("images/normal.png", "dxt1")
local waterFoam = dxCreateTexture("images/foam.png", "dxt1")
local waterShader
local currentMinute, minuteStartTickCount, minuteEndTickCount = 0, 0, 0

local effectBias = dxCreateShader("fx/effectBias.fx", 999, 0, false, "world")-- Apply depth bias to water effects to prevent flickering
if effectBias then
	engineApplyShaderToWorldTexture(effectBias, "coronaringa")
	engineApplyShaderToWorldTexture(effectBias, "boatwake1")
	engineApplyShaderToWorldTexture(effectBias, "waterwake")
	engineApplyShaderToWorldTexture(effectBias, "sphere")
end

addEventHandler("onClientResourceStop", resourceRoot,
function()
triggerEvent("UpdateButton", root, 2, "Off")
end)

function setShaders()
if ScreenInput and not waterShader then
waterShader = dxCreateShader("fx/water3.fx", 999, 0, false, "world")
	if waterShader then
		setNearClipDistance(0.299)-- prevent depth buffer glitching
		engineApplyShaderToWorldTexture(waterShader, "waterclear256")
		dxSetShaderValue(waterShader, "sPixelSize", {1/width, 1/height})
		dxSetShaderValue(waterShader, "normalTexture", waterNormal)
		dxSetShaderValue(waterShader, "foamTexture", waterFoam)
		dxSetShaderValue(waterShader, "screenInput", ScreenInput)
		dxSetShaderValue(waterShader, "specularSize", specularSize)
		dxSetShaderValue(waterShader, "flowSpeed", flowSpeed)
		dxSetShaderValue(waterShader, "reflectionSharpness", reflectionSharpness)
		dxSetShaderValue(waterShader, "reflectionStrength", reflectionStrength)
		dxSetShaderValue(waterShader, "refractionStrength", refractionStrength)
		dxSetShaderValue(waterShader, "causticStrength", causticStrength)
		dxSetShaderValue(waterShader, "causticSpeed", causticSpeed)
		dxSetShaderValue(waterShader, "causticIterations", causticIterations)
		dxSetShaderValue(waterShader, "deepness", shoreFadeStrength)
		removeEventHandler("onClientPreRender", root, updateShaders)
		addEventHandler("onClientPreRender", root, updateShaders)
	end
end
end
addEventHandler("onClientResourceStart", resourceRoot, setShaders)

function destroyShaders()
removeEventHandler("onClientPreRender", root, updateShaders)
if waterShader then
	destroyElement(waterShader)
	waterShader = nil
end
if lowShader then
	engineApplyShaderToWorldTexture(lowShader, "waterclear256")
end
end

function updateShaders()
if waterShader and ScreenInput then
	-- get Time with seconds
	local ho, mi = getTime()
	local se = 0
	if mi ~= currentMinute then
		minuteStartTickCount = getTickCount()
		local gameSpeed = math.clamp(0.01, getGameSpeed(), 10)
		minuteEndTickCount = minuteStartTickCount + getMinuteDuration() / gameSpeed
	end
	if minuteStartTickCount then
		local minFraction = math.unlerpclamped(minuteStartTickCount, getTickCount(), minuteEndTickCount)
		se = math_min (59, math.floor(minFraction * 60)) / 60 -- divide seconds by 60 to make it more useful
	end
	currentMinute = mi
	local shiningPower = getShiningPower(ho, mi, se)
	local sunX, sunY, sunZ = 0, 0, 0
	local moonX, moonY, moonZ = 0, 0, 0
	local skyResource = getResourceFromName("shader_dynamic_sky")
	if skyResource and getResourceState(skyResource) == "running" and exports.shader_dynamic_sky:isDynamicSkyEnabled() then-- try to get sun position from dynamic sky
		local px, py, pz = getElementPosition(localPlayer)
		local x, y, z = exports.shader_dynamic_sky:getDynamicSunVector()
		local dist = getFarClipDistance()*0.8
		sunX, sunY, sunZ = px - x*dist, py - y*dist, pz - z*dist
		x, y, z = exports.shader_dynamic_sky:getDynamicMoonVector()
		moonX, moonY, moonZ = px - x*dist, py - y*dist, pz - z*dist
	else
		shiningPower = 0-- if no sun position is available, disable specular lighting
	end
	local cr, cg, cb = getSunColor()
	local nightModifier = 1
	if ho >= 21 or ho < 5 then-- at night sun color is now moon color, sun position is now moon position, specular strength is lower
		cr, cg, cb = 255, 255, 255
		sunX, sunY, sunZ = moonX, moonY, moonZ
		nightModifier = 0.4
	end
	local wr, wg, wb, waterAlpha = getWaterColor()
	dxUpdateScreenSource(ScreenInput)
	dxSetShaderValue(waterShader, "dayTime", getDiffuse(ho, mi, se))
	dxSetShaderValue(waterShader, "waterShiningPower", shiningPower * nightModifier)
	dxSetShaderValue(waterShader, "waterColor", {wr/255, wg/255, wb/255, waterAlpha/255})
	dxSetShaderValue(waterShader, "sunColor", {cr/600, cg/600, cb/600})-- reduce sun color intensity because it looks garbage otherwise
	dxSetShaderValue(waterShader, "sunPos", {sunX, sunY, sunZ})
end
end

function getDiffuse(ho, mi, se)
local diffuse = 1
if ho > 21 or ho < 6 then
	diffuse = 0
end
if ho == 6 then
	diffuse = 1 - (60 - mi - se) / 60-- make water bright at 6:00
elseif ho == 20 then
	diffuse = 1 - (mi + se) / 60-- make water dark after 20:00
elseif ho == 21 then-- add moon light after 21:00
	diffuse = math_min(1, 1 + (mi + se - 20) / 20) * moonIlluminance
elseif ho > 21 or ho < 3 then
	diffuse = moonIlluminance
elseif ho == 3 then-- remove moon light between 3:40 and 4:00
	diffuse = math_min(1, 1 - (mi + se - 40) / 20) * moonIlluminance
end
return diffuse
end

function getShiningPower(ho, mi, se)
local shiningPower = 1
if ho == 6 then
	if mi < 20 then-- lerp specular start between 6:00 - 6:20
		shiningPower = 1 - (20 - mi - se) / 20
	elseif mi >= 20 then
		shiningPower = 1
	end
elseif ho == 19 then-- lerp specular end between 19:40 - 20:00
	shiningPower = math_min(1, 1 - (mi + se - 40) / 20)
elseif ho == 20 or ho == 5 or ho == 4 then
	shiningPower = 0
elseif ho == 3 then-- stop specular moon lighting between 3:40 and 4:00
	shiningPower = math_min(1, 1 - (mi + se - 40) / 20)
elseif ho == 21 then
	shiningPower = math_min(1, 1 + (mi + se - 20) / 20)-- start specular moon lighting between 21:00 and 21:20
end
return shiningPower
end

function math.clamp(low, value, high)
    return math_max(low, math_min(value, high))
end

function math.unlerp(from, pos, to)
	if to == from then
		return 1
	end
	return (pos - from) / (to - from)
end

function math.unlerpclamped(from, pos, to)
	return math.clamp(0, math.unlerp(from, pos, to), 1)
end

function math_max(a, b)
return a > b and a or b
end

function math_min(a, b)
return a < b and a or b
end