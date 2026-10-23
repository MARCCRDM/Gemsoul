-- Execute the actual client cue controller with events and tween doubles.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local entry = { Fn = fn, Active = true }
			table.insert(listeners, entry)
			return {
				Disconnect = function()
					entry.Active = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in listeners do
				if entry.Active then
					entry.Fn(...)
				end
			end
		end,
	}
end
local objects = {}
local function instance(kind)
	local object = { Kind = kind, ZIndex = 1, Destroying = signal(), Depth = signal() }
	if kind == "BindableEvent" then
		object.Event = signal()
		function object:Fire(...)
			self.Event:Fire(...)
		end
	end
	function object:FindFirstChildOfClass()
		return nil
	end
	function object:GetPropertyChangedSignal()
		return self.Depth
	end
	table.insert(objects, object)
	return object
end
local deferred, tweens, evaluations = {}, {}, 0
local GemClient = { Changed = signal() }
local Recommendations = {
	inspect = function(profile)
		evaluations += 1
		return profile or { Any = false, Equipment = false, Surges = { Changes = 0, Keys = {} } }
	end,
}
local function flush()
	while #deferred > 0 do
		table.remove(deferred, 1)()
	end
end
local TweenService = {
	Create = function(_, target, _, goal)
		local tween = { Plays = 0, Cancels = 0, Target = target, Goal = goal }
		function tween:Play()
			self.Plays += 1
		end
		function tween:Cancel()
			self.Cancels += 1
		end
		function tween:Destroy()
			self.Destroyed = true
		end
		table.insert(tweens, tween)
		return tween
	end,
}
local env = setmetatable({
	game = {
		GetService = function(_, service)
			return if service == "TweenService"
				then TweenService
				else { Shared = { UpgradeRecommendations = "recommendations" } }
		end,
	},
	script = { Parent = { GemClient = "client" } },
	require = function(id)
		return if id == "client" then GemClient else Recommendations
	end,
	Instance = { new = instance },
	UDim2 = {
		fromScale = function(x, y)
			return { x, y }
		end,
	},
	UDim = {
		new = function(x, y)
			return { x, y }
		end,
	},
	TweenInfo = {
		new = function(...)
			return { ... }
		end,
	},
	Enum = { EasingStyle = { Sine = 1 }, EasingDirection = { InOut = 1 } },
	task = {
		defer = function(fn)
			table.insert(deferred, fn)
		end,
	},
}, { __index = _G })
local Hints = luau.load(fs.readFile(ROOT .. "/src/client/Modules/UpgradeHints.luau"), { environment = env })()
flush()
local inventory, auto, surge = instance("TextButton"), instance("TextButton"), instance("TextButton")
Hints.bind(inventory, function(h)
	return h.Any
end, "gold")
local bestSelected = true
local updateAuto = Hints.bind(auto, function(h)
	return h.Equipment and bestSelected
end, "gold")
Hints.bind(surge, function(h)
	return h.Surges.Keys.Q == true
end, "cyan")
check(tweens[1].Plays == 0, "Empty profile flashed Inventory")
local before = evaluations
GemClient.Profile = { Any = true, Equipment = true, Surges = { Changes = 1, Keys = { Q = true } } }
GemClient.Changed:Fire()
GemClient.Changed:Fire()
GemClient.Changed:Fire()
flush()
check(evaluations == before + 1, "Repeated profile updates were not coalesced")
for _, tween in tweens do
	check(tween.Plays == 1 and tween.Target.Parent.Visible, "Upgrade cue did not appear")
end
GemClient.Changed:Fire()
flush()
check(tweens[1].Plays == 1, "Same recommendation restarted the flash")
bestSelected = false
updateAuto()
check(not tweens[2].Target.Parent.Visible, "Other build mode incorrectly highlighted Auto Equip")
bestSelected = true
updateAuto()
check(tweens[2].Target.Parent.Visible, "Best mode did not regain its cue")
surge.ZIndex = 9
surge.Depth:Fire()
check(tweens[3].Target.Parent.ZIndex == 12, "Compact popup hid its pulse behind the menu")
GemClient.Profile = nil
GemClient.Changed:Fire()
flush()
for _, tween in tweens do
	check(not tween.Target.Parent.Visible and tween.Cancels > 0, "Upgrade cue remained after upgrade disappeared")
end
surge.Destroying:Fire()
check(tweens[3].Destroyed, "Destroyed button retained its tween")
local plays = tweens[3].Plays
GemClient.Profile = { Any = true, Equipment = false, Surges = { Changes = 1, Keys = { Q = true } } }
GemClient.Changed:Fire()
flush()
check(tweens[3].Plays == plays, "Destroyed button still listened to updates")
check(
	tweens[1].Target.Parent.Visible and not tweens[2].Target.Parent.Visible,
	"Surge-only upgrade did not route correctly"
)
print(string.format("PASS: %d upgrade hint lifecycle checks", checks))
