--[[
	A socketed stone's light breathes its element's way: Fire flickers,
	Frost swells slowly, Shock strobes, Poison throbs. The server gives the
	light its PulseBase (brightness), PulsePeriod (seconds from bright to
	dim) and PulseDim (how dim it gets, 0-1) and tags it GemGlow; every
	client moves it. (A tween on the server sent every stone's light to
	every player, every frame, and a copy of it never moved.)

	Lights in the world move near the camera; the first-person copy's
	(LiveLooks) always. Previews (ViewportFrames) draw no lights.

	  GemLights.brightness(base, period, dim, t)  pure: the light at time t
	  GemLights.start()
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)
local LiveLooks = require(script.Parent.LiveLooks)

local GemLights = {}

GemLights.Range = 120 -- (further off, too small to see: held still)

-- Bright at t = 0, dimmest (base * dim) at t = period, bright again at
-- 2 * period: a sine, eased in and out at both ends.
function GemLights.brightness(base: number, period: number, dim: number, t: number): number
	if period <= 0 then
		return base
	end
	local k = 0.5 - 0.5 * math.cos(t * math.pi / period)
	return base * (1 - (1 - dim) * k)
end

function GemLights.start()
	type Glow = { Base: number, Period: number, Dim: number, Place: string }
	local lights: { [Light]: Glow } = {}
	local links: { [Light]: { RBXScriptConnection } } = {}
	local function read(light: Light)
		local entry = lights[light]
		local base, period, dim =
			light:GetAttribute("PulseBase"), light:GetAttribute("PulsePeriod"), light:GetAttribute("PulseDim")
		if entry then
			entry.Base = if type(base) == "number" then base else light.Brightness
			entry.Period = if type(period) == "number" then period else 0
			entry.Dim = if type(dim) == "number" then dim else 1
		end
	end
	local function remove(light: Light)
		lights[light] = nil
		for _, link in links[light] or {} do
			link:Disconnect()
		end
		links[light] = nil
	end
	local function add(instance: Instance)
		if instance:IsA("Light") and not lights[instance] then
			lights[instance] = { Base = 0, Period = 0, Dim = 1, Place = LiveLooks.place(instance) }
			read(instance)
			links[instance] = {
				instance.AttributeChanged:Connect(function()
					read(instance)
				end),
				-- (An untagged copy is forgotten as it leaves the game.)
				LiveLooks.follow(instance, function()
					if lights[instance] then
						lights[instance].Place = LiveLooks.place(instance)
					end
				end, function()
					remove(instance)
				end),
			}
		end
	end
	for _, instance in CollectionService:GetTagged(Tags.GemGlow) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.GemGlow):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.GemGlow):Connect(function(instance)
		remove(instance :: Light)
	end)
	LiveLooks.track("PulseBase", add)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		for light, glow in lights do
			local place = glow.Place
			local moves = place == "Camera"
			if place == "World" then
				local holder = light.Parent
				moves = not eye
					or not holder
					or not holder:IsA("BasePart")
					or (holder.Position - eye).Magnitude < GemLights.Range
			end
			if moves then
				light.Brightness = GemLights.brightness(glow.Base, glow.Period, glow.Dim, t)
			end
		end
	end)
end

return GemLights
