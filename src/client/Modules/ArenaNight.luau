--[[
	Night in the Arena: while you're in an Arena session the lighting drops
	to a dim, cool night, so the fight is lit by itself. Strikes, surges,
	parries and deaths flash real light (CombatFx.flash), and every
	fighter's gear glows: its gem, rarity and affinity lights get a wider,
	stronger companion and its neon trims bloom. Leaving the Arena restores
	the daylight. Purely local; the server never sees it.

	  ArenaNight.Mood     the night's Lighting values
	  ArenaNight.start()  follows your CombatSession attribute
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local CombatFx = require(script.Parent.CombatFx)

local ArenaNight = {}

ArenaNight.Mood = {
	Lighting = {
		Brightness = 0.45,
		Ambient = Color3.fromRGB(30, 32, 46),
		OutdoorAmbient = Color3.fromRGB(40, 42, 60),
		ExposureCompensation = -0.15,
		EnvironmentDiffuseScale = 0.25,
		EnvironmentSpecularScale = 0.6,
	},
	BloomEffect = { Intensity = 1.1, Size = 30, Threshold = 1.05 },
	ColorCorrectionEffect = {
		Brightness = -0.03,
		Contrast = 0.18,
		Saturation = 0.15,
		TintColor = Color3.fromRGB(222, 228, 255),
	},
	Atmosphere = {
		Density = 0.32,
		Haze = 0.4,
		Glare = 0,
		Color = Color3.fromRGB(22, 26, 40),
		Decay = Color3.fromRGB(10, 12, 22),
	},
	SunRaysEffect = { Intensity = 0 },
}
-- Dungeon silhouettes must remain readable between combat flashes.
ArenaNight.DungeonMood = {
	Lighting = {
		Brightness = 2,
		Ambient = Color3.fromRGB(112, 119, 135),
		OutdoorAmbient = Color3.fromRGB(140, 149, 165),
		ExposureCompensation = 0.15,
		EnvironmentDiffuseScale = 0.8,
		EnvironmentSpecularScale = 0.6,
	},
	BloomEffect = { Intensity = 0.25, Size = 20, Threshold = 1.4 },
	ColorCorrectionEffect = { Brightness = 0.02, Contrast = 0.05, Saturation = 0.03, TintColor = Color3.fromRGB(
		246,
		248,
		255
	) },
	Atmosphere = { Density = 0.12, Haze = 0.1, Glare = 0, Color = Color3.fromRGB(145, 156, 178), Decay = Color3.fromRGB(
		92,
		104,
		127
	) },
	SunRaysEffect = { Intensity = 0 },
}
ArenaNight.ClockTime = 0 -- moon and stars
ArenaNight.LampScale = 0.3 -- the Arena's own ceiling lamps, dimmed
ArenaNight.FlashBoost = 1.5 -- combat flashes, brighter and wider
-- The companion glow on each gear light: brightness added, range multiplier.
ArenaNight.GlowBrightness, ArenaNight.GlowRange = 1.1, 1.6

local FADE = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local active = false
local activeMood = nil
local saved = nil -- [instance] = { [property] = value }, plus ClockTime
local lamps = {} -- [PointLight] = original Brightness
local glows = {} -- [source PointLight] = companion PointLight

local function targets(mood)
	local list = { [Lighting] = mood.Lighting }
	for className, goal in mood do
		if className ~= "Lighting" then
			local effect = Lighting:FindFirstChildOfClass(className)
			if effect then
				list[effect] = goal
			end
		end
	end
	return list
end

local function gearOf(model: Instance?): Instance?
	return model and model:FindFirstChild("GemsoulGear")
end

-- A companion light beside every light on a fighter's gear.
local function glowGear()
	local fighters = {}
	for _, other in Players:GetPlayers() do
		table.insert(fighters, other.Character)
	end
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		table.insert(fighters, model)
	end
	for _, model in fighters do
		local gear = gearOf(model)
		for _, light in if gear then gear:GetDescendants() else {} do
			if light:IsA("PointLight") and light.Name ~= "NightGlow" and not glows[light] then
				local glow = Instance.new("PointLight")
				glow.Name = "NightGlow"
				glow.Color = light.Color
				glow.Brightness = ArenaNight.GlowBrightness
				glow.Range = math.min(light.Range * ArenaNight.GlowRange, 20)
				glow.Shadows = false
				glow.Parent = light.Parent
				glows[light] = glow
			end
		end
	end
	for light, glow in glows do
		if not light.Parent or not glow.Parent then
			glow:Destroy()
			glows[light] = nil
		end
	end
end

local function dimLamps()
	local arena = workspace:FindFirstChild("CombatArena")
	for _, light in if arena then arena:GetDescendants() else {} do
		if light:IsA("PointLight") and lamps[light] == nil then
			lamps[light] = light.Brightness
			light.Brightness *= ArenaNight.LampScale
		end
	end
end

local function nightfall(mood)
	if active and activeMood == mood then
		return
	end
	active = true
	activeMood = mood
	saved = saved or { ClockTime = Lighting.ClockTime }
	for instance, goal in targets(mood) do
		local before = {}
		for property in goal do
			before[property] = (instance :: any)[property]
		end
		saved[instance] = saved[instance] or before
		TweenService:Create(instance, FADE, goal):Play()
	end
	Lighting.ClockTime = ArenaNight.ClockTime
	CombatFx.LightBoost = if mood == ArenaNight.DungeonMood then 1 else ArenaNight.FlashBoost
	dimLamps()
	glowGear()
end

local function daybreak()
	if not active then
		return
	end
	active = false
	activeMood = nil
	for instance, before in saved or {} do
		if typeof(instance) == "Instance" and instance.Parent then
			TweenService:Create(instance, FADE, before):Play()
		end
	end
	if saved then
		Lighting.ClockTime = saved.ClockTime
	end
	saved = nil
	CombatFx.LightBoost = 1
	for light, brightness in lamps do
		if light.Parent then
			light.Brightness = brightness
		end
	end
	table.clear(lamps)
	for _, glow in glows do
		glow:Destroy()
	end
	table.clear(glows)
end

local started = false
function ArenaNight.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local function follow()
		if player:GetAttribute("CombatSession") ~= nil then
			nightfall(if player:GetAttribute("DungeonId") then ArenaNight.DungeonMood else ArenaNight.Mood)
		else
			daybreak()
		end
	end
	player:GetAttributeChangedSignal("CombatSession"):Connect(follow)
	player:GetAttributeChangedSignal("DungeonId"):Connect(follow)
	follow()
	-- New fighters, re-equipped gear and streamed-in lamps.
	task.spawn(function()
		while true do
			task.wait(1)
			if active then
				dimLamps()
				glowGear()
			end
		end
	end)
end

return ArenaNight
