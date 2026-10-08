--[[
	The first-time tutorial: teach the loop in under 3 minutes, one action
	per beat, one reward per beat, never more than two lines on screen.
	Pure, for the server (Systems/Intro), the client (Tutorial.client) and
	tests.

	  Tutorial.Enabled                  off = the old starter picker flow
	  Tutorial.Beats                    in order; each has an Id and a prompt
	                                    (Mobile is the touch wording)
	  Tutorial.Gems                     the five scripted gems the rocks drop
	  Tutorial.Rocks                    where those rocks sit, from the Outpost
	                                    spawn (studs, in the spawn's frame)
	  Tutorial.state(profile)           -> the saved state ({ Step, Mined, Done })
	  Tutorial.beat(profile)            -> the current beat, or nil when done
	  Tutorial.met(profile, beatId)     -> can that beat be ticked off?
	  Tutorial.advance(profile, beatId) -> moves past `beatId` if it's the
	                                       current beat and it's met
	  Tutorial.skip(profile)            -> marks it all done
]]
local Tutorial = {}

Tutorial.Enabled = true

-- Thermal, Cryo and Ion are what players call Fire, Frost and Shock.
Tutorial.Beats = {
	{
		Id = "Mine",
		Prompt = "Click a rock to swing your pick.",
		Mobile = "Tap to swing your pick.",
		Detail = "Walk to the highlighted rock. Each click, tap or E press is one swing. Break three rocks to find three gems.",
	},
	{
		Id = "GemIntro",
		Prompt = "Three gems. Your first power-up!",
		Detail = "Color tells you the element. Socket a gem into equipment to enchant it. You can move it later.",
	},
	{
		Id = "OpenInventory",
		Prompt = "Let’s put those gems to work!",
		Mobile = "Tap Inventory.",
		Detail = "Click Inventory below. Your three new gems are waiting in the Gems tab.",
	},
	{
		Id = "SocketArmor",
		Prompt = "Drag the Thermal gem onto your Chest.",
		Mobile = "Tap the Thermal gem, then CHEST.",
		Detail = "Enchanting strengthens your armor's unique perk. Read the green effect confirmation.",
	},
	{
		Id = "SocketWeapon",
		Prompt = "Drag the Cryo gem onto your Sword.",
		Mobile = "Tap the Cryo gem, then WEAPON.",
		Detail = "A weapon enchantment improves your sword. The inventory shows what changes.",
	},
	{
		Id = "SocketShield",
		Prompt = "Drag the Ion gem onto your Shield.",
		Mobile = "Tap the Ion gem, then SHIELD.",
		Detail = "This enchantment strengthens your shield's guard perk.",
	},
	{
		Id = "CloseInventory",
		Prompt = "Loadout upgraded. You’re ready!",
		Mobile = "Tap Back to Lobby.",
		Detail = "That's the loop: mine gems, enchant your gear, and try new combinations.",
	},
}
Tutorial.ById = {}
for index, beat in Tutorial.Beats do
	beat.Index = index
	Tutorial.ById[beat.Id] = beat
end

-- Guaranteed finds from three real Outpost rocks; no tutorial-only geometry.
Tutorial.Gems = {
	{ Element = "Fire", Tier = "Common", Role = "Core" },
	{ Element = "Frost", Tier = "Common", Role = "Core" },
	{ Element = "Shock", Tier = "Common", Role = "Core" },
}

function Tutorial.state(profile)
	local state = profile.Tutorial
	if type(state) ~= "table" then
		-- Older saves: anyone past the intro has played already.
		state = { Step = 1, Mined = 0, Done = profile.Intro ~= nil and profile.Intro.Done == true }
		profile.Tutorial = state
	end
	if state.Version ~= 3 then
		-- Existing completed accounts stay completed. In-progress old tutorials
		-- restart only their guidance, retaining earned items and mined count.
		state.Step = if (state.Mined or 0) >= 3 then 2 else 1
		state.Version = 3
	end
	state.Step = math.clamp(math.floor(tonumber(state.Step) or 1), 1, #Tutorial.Beats + 1)
	state.Mined = math.clamp(math.floor(tonumber(state.Mined) or 0), 0, #Tutorial.Gems)
	return state
end

function Tutorial.beat(profile)
	local state = Tutorial.state(profile)
	return if state.Done then nil else Tutorial.Beats[state.Step]
end

local SOCKETS = {
	SocketArmor = "ArmorGem",
	SocketWeapon = "WeaponGem",
	SocketShield = "ShieldGem",
	SurgeQ = "Surge1Gem",
	SurgeE = "Surge2Gem",
}

function Tutorial.met(profile, beatId: string): boolean
	local state = Tutorial.state(profile)
	if beatId == "Mine" then
		return state.Mined >= #Tutorial.Gems
	end
	if beatId == "Queue" then
		return state.Queued == true
	end
	if beatId == "Fight" then
		return state.Won == true
	end
	if beatId == "Buy" then
		return state.Purchased == true
	end
	local key = SOCKETS[beatId]
	if key then
		return profile.Character ~= nil and profile.Character[key] ~= nil
	end
	-- Opening and closing a menu happen on the player's screen.
	return Tutorial.ById[beatId] ~= nil
end

function Tutorial.advance(profile, beatId: string): boolean
	local state = Tutorial.state(profile)
	local beat = Tutorial.beat(profile)
	if not beat or beat.Id ~= beatId or not Tutorial.met(profile, beatId) then
		return false
	end
	state.Step += 1
	if state.Step > #Tutorial.Beats then
		state.Done = true
	end
	return true
end

function Tutorial.skip(profile)
	local state = Tutorial.state(profile)
	state.Done = true
	state.Step = #Tutorial.Beats + 1
end

return Tutorial
