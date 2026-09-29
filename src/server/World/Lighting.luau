-- Sunny afternoon: warm light, soft haze, drifting clouds. Bloom is kept
-- subtle so the neon still glows without washing out the daylight.
local Lighting = game:GetService("Lighting")

local function getOrCreate(parent: Instance, className: string): any
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Parent = parent
	return instance
end

return function()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(110, 108, 118)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 148, 160)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local atmosphere = getOrCreate(Lighting, "Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 220, 255)
	atmosphere.Decay = Color3.fromRGB(106, 140, 180)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2

	local bloom = getOrCreate(Lighting, "BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 2

	local grade = getOrCreate(Lighting, "ColorCorrectionEffect")
	grade.Brightness = 0.03
	grade.Contrast = 0.08
	grade.Saturation = 0.12
	grade.TintColor = Color3.fromRGB(255, 250, 240)

	local rays = getOrCreate(Lighting, "SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.8

	local clouds = getOrCreate(workspace.Terrain, "Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.new(1, 1, 1)
end
