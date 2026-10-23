-- One cached recommendation per profile update, shared by the lobby and
-- inventory. A slow border pulse leaves labels readable and does not capture input.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Recommendations = require(ReplicatedStorage.Shared.UpgradeRecommendations)
local GemClient = require(script.Parent.GemClient)

local Hints = {}
local changed = Instance.new("BindableEvent")
Hints.Changed = changed.Event
Hints.Current = Recommendations.inspect(nil)
local queued = false
local function refresh()
	if queued then
		return
	end
	queued = true
	task.defer(function()
		queued = false
		Hints.Current = Recommendations.inspect(GemClient.Profile)
		changed:Fire(Hints.Current)
	end)
end
GemClient.Changed:Connect(refresh)
refresh()

function Hints.bind(button, predicate, color)
	local overlay = Instance.new("Frame")
	overlay.Name = "UpgradeGlow"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = button.ZIndex + 3
	overlay.Visible = false
	overlay.Parent = button
	local corner = Instance.new("UICorner")
	local existing = button:FindFirstChildOfClass("UICorner")
	corner.CornerRadius = if existing then existing.CornerRadius else UDim.new(0, 6)
	corner.Parent = overlay
	local edge = Instance.new("UIStroke")
	edge.Color = color
	edge.Thickness = 2
	edge.Transparency = 0.15
	edge.Parent = overlay
	local pulse = TweenService:Create(
		edge,
		TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8 }
	)
	local on = false
	local function update()
		local enabled = predicate(Hints.Current) == true
		if enabled == on then
			return
		end
		on = enabled
		overlay.Visible = on
		if on then
			pulse:Play()
		else
			pulse:Cancel()
		end
	end
	local connection = Hints.Changed:Connect(update)
	local depthConnection = button:GetPropertyChangedSignal("ZIndex"):Connect(function()
		overlay.ZIndex = button.ZIndex + 3
	end)
	button.Destroying:Connect(function()
		connection:Disconnect()
		depthConnection:Disconnect()
		pulse:Cancel()
		pulse:Destroy()
	end)
	update()
	return update
end

return Hints
