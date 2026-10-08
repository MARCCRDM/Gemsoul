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
	{ Id = "Mine", Prompt = "Hold E to mine.", Mobile = "Hold the button to mine." },
	{ Id = "OpenInventory", Prompt = "Open your Inventory.", Mobile = "Tap Inventory." },
	{
		Id = "SocketArmor",
		Prompt = "Drag the Thermal gem onto your Chest.",
		Mobile = "Tap the Thermal gem, then your Chest.",
	},
	{
		Id = "SocketWeapon",
		Prompt = "Now socket the Cryo gem onto your Sword.",
		Mobile = "Now tap the Cryo gem, then your Sword.",
	},
	{
		Id = "SocketShield",
		Prompt = "And the Ion gem onto your Shield.",
		Mobile = "And the Ion gem onto your Shield.",
	},
	{ Id = "SurgeQ", Prompt = "Drag Ember Lance onto Q.", Mobile = "Tap Ember Lance, then Q." },
	{ Id = "SurgeE", Prompt = "Drag Chain Lightning onto E.", Mobile = "Tap Chain Lightning, then E." },
	{ Id = "CloseInventory", Prompt = "Close your Inventory.", Mobile = "Tap Close." },
	{ Id = "Queue", Prompt = "Step onto the glowing Rival pad." },
	{ Id = "Fight", Prompt = "Follow the combat prompts." },
	{ Id = "Return", Prompt = "Return to the Outpost." },
	{ Id = "OpenMarket", Prompt = "Open the Market." },
	{ Id = "Buy", Prompt = "Buy one Common item." },
	{ Id = "CloseMarket", Prompt = "Close the Market." },
	{ Id = "Play", Prompt = "You're ready. Go." },
}
Tutorial.ById = {}
for index, beat in Tutorial.Beats do
	beat.Index = index
	Tutorial.ById[beat.Id] = beat
end

-- Three gems for gear ("Core"), then two Surges that explode.
Tutorial.Gems = {
	{ Element = "Fire", Tier = "Common", Role = "Core" },
	{ Element = "Frost", Tier = "Common", Role = "Core" },
	{ Element = "Shock", Tier = "Common", Role = "Core" },
	{ Element = "Fire", Tier = "Common", Role = "Surge", Surge = "EmberLance" },
	{ Element = "Shock", Tier = "Uncommon", Role = "Surge", Surge = "ChainLightning" },
}

-- A short arc in front of the spawn, a few steps apart.
Tutorial.Rocks = {
	Vector3.new(-9, 0, -14),
	Vector3.new(-4, 0, -19),
	Vector3.new(3, 0, -21),
	Vector3.new(10, 0, -18),
	Vector3.new(14, 0, -12),
}
Tutorial.MineReach = 14 -- studs from a rock the server accepts a mine

function Tutorial.state(profile)
	local state = profile.Tutorial
	if type(state) ~= "table" then
		-- Older saves: anyone past the intro has played already.
		state = { Step = 1, Mined = 0, Done = profile.Intro ~= nil and profile.Intro.Done == true }
		profile.Tutorial = state
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
