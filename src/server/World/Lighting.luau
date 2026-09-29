-- Dusky violet sky so the neon reads, with bloom to make it glow.
local Lighting = game:GetService("Lighting")

local function getOrCreate(className: string): any
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Parent = Lighting
	return instance
end

return function()
	Lighting.ClockTime = 18.3
	Lighting.Brightness = 2
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(45, 38, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(95, 85, 120)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 1

	local atmosphere = getOrCreate("Atmosphere")
	atmosphere.Density = 0.35
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(160, 130, 200)
	atmosphere.Decay = Color3.fromRGB(70, 45, 100)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.5

	local bloom = getOrCreate("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.4

	local grade = getOrCreate("ColorCorrectionEffect")
	grade.Contrast = 0.1
	grade.Saturation = 0.15
	grade.TintColor = Color3.fromRGB(255, 245, 255)

	local rays = getOrCreate("SunRaysEffect")
	rays.Intensity = 0.05
end
