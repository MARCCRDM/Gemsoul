--[[
	Health recovery. Roblox puts a "Health" script in every player character
	that heals 1% a second, even mid-fight, while computer fighters (the
	Arena rival) never get it, so duels were one-sided. That script is
	removed and replaced by this rule, the same for everyone:

	  · no recovery during an Arena fight (a PvP or Training session)
	  · elsewhere, 1% of max health a second once 5 seconds have passed
	    without taking damage
]]
local Players = game:GetService("Players")

local HealthRegen = {}

local RATE = 0.01 -- of max health, per second
local DELAY = 5 -- seconds without damage before recovery starts
local STEP = 1

-- [humanoid] = { Health = last seen, HurtAt = os.clock() of the last drop }
local seen = setmetatable({}, { __mode = "k" })

-- Pure, for testing: how much to restore this step.
function HealthRegen.amount(health: number, maxHealth: number, inArena: boolean, sinceHurt: number, dt: number): number
	if inArena or health <= 0 or health >= maxHealth or sinceHurt < DELAY then
		return 0
	end
	return math.min(maxHealth - health, maxHealth * RATE * dt)
end

local function removeDefault(character: Model)
	local default = character:FindFirstChild("Health") or character:WaitForChild("Health", 10)
	if default and default:IsA("Script") then
		default:Destroy()
	end
end

local function step(dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local entry = seen[humanoid]
			if not entry then
				entry = { Health = humanoid.Health, HurtAt = -math.huge }
				seen[humanoid] = entry
			end
			if humanoid.Health < entry.Health then
				entry.HurtAt = now
			end
			local inArena = player:GetAttribute("CombatSession") ~= nil
			local heal = HealthRegen.amount(humanoid.Health, humanoid.MaxHealth, inArena, now - entry.HurtAt, dt)
			if heal > 0 then
				humanoid.Health += heal
			end
			entry.Health = humanoid.Health
		end
	end
end

function HealthRegen.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(removeDefault, character)
		end)
		if player.Character then
			task.spawn(removeDefault, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	task.spawn(function()
		while true do
			step(task.wait(STEP))
		end
	end)
end

return HealthRegen
