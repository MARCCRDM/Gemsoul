--[[
	Saga Outpost: the shared mining basin (Shared.Outpost has the rules,
	World.OutpostWorld the place). Everyone in the server mines the same
	rocks, sees each other swing, trades at the Probe and challenges each
	other to duels. Request actions:

	  "OutpostEnter"           go to the Outpost (a free Survey Pick each day)
	  "OutpostLeave"           back to base
	  "OutpostHit", nodeId     swing at a rock (wears your pick; the last hit
	                           pops it and pays out)
	  "OutpostBuyPick", id     buy a pick at the Probe (coins)
	  "OutpostEquipPick", id   take a pick you own in hand
	  "OutpostState"           your picks and record

	Rocks are shared: a rock's first hitter keeps it while they keep
	swinging (Outpost.ClaimSeconds). A mined-out rock grows back somewhere
	in the basin after its respawn time. Rocks carry their state as
	attributes (Hp, MaxHp, ClaimedBy, LastHitBy, LastCrit, Popped) so every
	client can show every swing; prompts carry PromptKind (Mine, Probe,
	Gate, Duel, Party) for the client to act on.

	The leaderboard billboard shows the top gear scores and duel wins
	(TopPlayers' Gear and Wins boards), refreshed every 30 seconds.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Outpost)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Mine = require(ReplicatedStorage.Shared.Mine)
local OutpostWorld = require(script.Parent.Parent.World.OutpostWorld)
local ChatChannels = require(script.Parent.ChatChannels)
local Gems = require(script.Parent.Gems)
local MineWall = require(script.Parent.MineWall)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Shop = require(script.Parent.Shop)
local TopPlayers = require(script.Parent.TopPlayers)

local reply = Shop.reply

local OutpostServer = {}

OutpostServer.Tag = "OutpostNode"

local site = nil
local nodesFolder: Folder? = nil
local nodes = {} -- [id] = { Id, Spot, Size, Hp, MaxHp, Model, ClaimedBy, ClaimUntil, Ready }
local freeSpots: { [number]: boolean } = {}
local nextId = 0
local lastSwing: { [Player]: number } = {}
local secretParts: { [string]: BasePart } = {}
local rng = Random.new()

local function today(): number
	return math.floor(os.time() / 86400)
end

-- A player's Outpost record, the free pick's regained swings added, a
-- working pick in hand.
local function record(profile)
	profile.Outpost = profile.Outpost or { Picks = {}, Active = "Survey", Rocks = 0 }
	local o = profile.Outpost
	o.Picks = o.Picks or {}
	o.Rocks = o.Rocks or 0
	if o.SurveyAt == nil then
		-- A new miner (or one from before the refill) starts with it full.
		o.Picks.Survey = math.max(o.Picks.Survey or 0, Rules.Picks.Survey.Swings)
	end
	local swings
	swings, o.SurveyAt = Rules.refillSurvey(o.Picks.Survey or 0, o.SurveyAt or os.time(), os.time())
	-- (A worn-out pick stays gone until a swing comes back.)
	o.Picks.Survey = if swings > 0 then swings else o.Picks.Survey
	if (o.Picks[o.Active] or 0) <= 0 then
		for i = #Rules.PickOrder, 1, -1 do
			local id = Rules.PickOrder[i]
			if (o.Picks[id] or 0) > 0 then
				o.Active = id
				break
			end
		end
	end
	return o
end

local function stateOf(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	local o = record(profile)
	local secrets = 0
	for _ in o.Secrets or {} do
		secrets += 1
	end
	return {
		Picks = o.Picks,
		Active = o.Active,
		Rocks = o.Rocks,
		Secrets = secrets,
		SecretsTotal = #Rules.SecretOrder,
		-- Seconds until the free pick regains its next swing (nil when full).
		NextSwingIn = if (o.Picks.Survey or 0) < Rules.Picks.Survey.Swings
			then math.max(0, (o.SurveyAt or os.time()) + Rules.FreeSwingSeconds - os.time())
			else nil,
	}
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The pick in hand, seen by everyone; the weapon is put away meanwhile.
local function pickModel(player: Player)
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand") :: BasePart?
	if not character or not hand then
		return
	end
	local old = character:FindFirstChild("OutpostPick")
	if old then
		old:Destroy()
	end
	local profile = PlayerData.get(player)
	local spec = Rules.Picks[profile and record(profile).Active or "Survey"] or Rules.Picks.Survey
	local model = Instance.new("Model")
	model.Name = "OutpostPick"
	local grip = hand.CFrame * CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-120), 0, 0)
	local function add(at: CFrame, size: Vector3, color: Color3, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Size, p.Color, p.Material = size, color, material or Enum.Material.Metal
		p.CFrame = grip * at
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = hand, p, p
		p.Parent = model
		return p
	end
	add(CFrame.new(0, 0.9, 0), Vector3.new(0.22, 2.6, 0.22), Color3.fromRGB(60, 56, 54), Enum.Material.Wood)
	add(CFrame.new(0, 2.1, 0), Vector3.new(0.34, 0.34, 0.34), Color3.fromRGB(40, 42, 50))
	add(CFrame.new(0, 2.2, -0.55), Vector3.new(0.26, 0.3, 1.2), spec.Color)
	add(CFrame.new(0, 2.05, -1.25) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(0.2, 0.22, 0.5), spec.Color)
	add(CFrame.new(0, 2.2, 0.4), Vector3.new(0.24, 0.26, 0.6), spec.Color)
	if spec.Power > 1 then
		local glow = add(CFrame.new(0, 2.2, -0.55), Vector3.new(0.3, 0.12, 1.0), spec.Color, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = spec.Color, 8, 1.5
		light.Parent = glow
	end
	model.Parent = character
end

local function weaponVisible(player: Player, visible: boolean)
	local character = player.Character
	local gear = character and character:FindFirstChild("GemsoulGear")
	local weapon = gear and gear:FindFirstChild("Weapon")
	for _, part in weapon and weapon:GetDescendants() or {} do
		if part:IsA("BasePart") then
			if visible then
				local was = part:GetAttribute("OutpostTransparency")
				if was ~= nil then
					part.Transparency = was
					part:SetAttribute("OutpostTransparency", nil)
				end
			elseif part:GetAttribute("OutpostTransparency") == nil then
				part:SetAttribute("OutpostTransparency", part.Transparency)
				part.Transparency = 1
			end
		end
	end
end

-- Mining kit on while at the Outpost and not in a fight; off otherwise.
local function refreshKit(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local mining = player:GetAttribute("Outpost") == true and player:GetAttribute("CombatSession") == nil
	weaponVisible(player, not mining)
	local pick = character:FindFirstChild("OutpostPick")
	if mining then
		pickModel(player)
	elseif pick then
		pick:Destroy()
	end
end

-- "Challenge to a duel" (G) and "Invite to party" (F) on each visitor, for others.
local function socialPrompts(player: Player, on: boolean)
	local root = rootOf(player)
	if not root then
		return
	end
	for _, name in { "OutpostDuel", "OutpostParty" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if not on then
		return
	end
	for _, spec in
		{
			{ "OutpostDuel", "Duel", "Challenge to a duel", Enum.KeyCode.G },
			{ "OutpostParty", "Party", "Invite to party", Enum.KeyCode.F },
		}
	do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = spec[1]
		prompt.ActionText = spec[3]
		prompt.ObjectText = player.DisplayName
		prompt.KeyboardKeyCode = spec[4]
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("PromptKind", spec[2])
		prompt:SetAttribute("TargetUserId", player.UserId)
		prompt.Parent = root
	end
end

-- Rocks ---------------------------------------------------------------------------

local function spawnNode()
	local spots = {}
	for index in freeSpots do
		table.insert(spots, index)
	end
	if #spots == 0 or not site or not nodesFolder then
		return
	end
	local index = spots[rng:NextInteger(1, #spots)]
	freeSpots[index] = nil
	nextId += 1
	local size = Rules.rollSize(rng:NextNumber())
	local spec = Rules.Sizes[size]
	local model = OutpostWorld.rock(size, site.Spots[index], rng)
	model.Name = "Rock" .. nextId
	model:SetAttribute("NodeId", nextId)
	model:SetAttribute("Size", size)
	model:SetAttribute("Hp", spec.Hp)
	model:SetAttribute("MaxHp", spec.Hp)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Mine"
	prompt.ObjectText = spec.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Rules.Reach + spec.Scale / 2
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PromptKind", "Mine")
	prompt:SetAttribute("NodeId", nextId)
	prompt.Parent = model.PrimaryPart
	CollectionService:AddTag(model, OutpostServer.Tag)
	model.Parent = nodesFolder
	nodes[nextId] = {
		Id = nextId,
		Spot = index,
		Size = size,
		Hp = spec.Hp,
		MaxHp = spec.Hp,
		Model = model,
		Ready = true,
	}
end

-- A rock popped: it lingers a moment (for the burst), then grows back later.
local function popNode(node, player: Player)
	node.Ready = false
	nodes[node.Id] = nil
	local model = node.Model
	model:SetAttribute("Popped", player.UserId)
	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end
	task.delay(0.9, function()
		model:Destroy()
		freeSpots[node.Spot] = true
	end)
	task.delay(Rules.Sizes[node.Size].Respawn, spawnNode)
end

-- What a popped rock pays: a gem by chance, a few coins by chance (mining
-- is for gems, not a coin mint), gear rarely.
local function loot(player: Player, node, profile)
	local spec = Rules.Sizes[node.Size]
	local roll = Gems.random()
	local result = { Size = node.Size, Name = spec.Name }
	if roll:NextNumber() < (spec.CoinChance or 1) then
		local coins = roll:NextInteger(spec.Coins[1], spec.Coins[2])
		PlayerData.addCoins(player, coins)
		result.Coins = coins
	end
	if roll:NextNumber() < spec.Gem then
		local gem = Gems.award(player, "MiningNode", { Luck = Mine.luck(spec.Depth) + (spec.Luck or 0) })
		if gem then
			result.Gem = gem
			result.Rarity = gem.Tier
			result.Text = GemConfig.displayName(gem)
			PlayerData.milestone(player, "Mined")
			-- Ultra Rare and Legendary finds are called out to the whole server.
			if (GemConfig.TierRank[gem.Tier] or 0) >= 4 then
				ChatChannels.announce(
					"Loot",
					string.format("%s unearthed [%s] at the Outpost!", player.DisplayName, result.Text)
				)
			end
		else
			result.Full = true
		end
	end
	if roll:NextNumber() < spec.Gear then
		result.Gear = MineWall.recoverGear(player, spec.Depth)
	end
	Progress.addXP(player, "Mine")
	record(profile).Rocks += 1
	return result
end

local function hit(player: Player, nodeId: any)
	if player:GetAttribute("Outpost") ~= true or player:GetAttribute("CombatSession") then
		return reply(false, "Head to the Outpost to mine.")
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		return reply(false, "Hop out of the machine to mine.")
	end
	local now = os.clock()
	if now - (lastSwing[player] or 0) < Rules.SwingCooldown then
		return reply(false, "")
	end
	local node = type(nodeId) == "number" and nodes[nodeId] or nil
	if not node or not node.Ready then
		return reply(false, "That rock is mined out.")
	end
	local root = rootOf(player)
	local body = node.Model.PrimaryPart
	local spec = Rules.Sizes[node.Size]
	if not root or not body or (root.Position - body.Position).Magnitude > Rules.Reach + spec.Scale then
		return reply(false, "Get closer to the rock.")
	end
	if not Rules.claimHolder(node, player.UserId, now) then
		local holder = Players:GetPlayerByUserId(node.ClaimedBy)
		return reply(false, (if holder then holder.DisplayName else "Someone") .. " is mining that one.")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your data is still loading.")
	end
	local o = record(profile)
	local pickId = o.Active
	if (o.Picks[pickId] or 0) <= 0 then
		return reply(
			false,
			"Your pick is broken! Get a new one at the Probe.",
			{ NoPick = true, State = stateOf(player) }
		)
	end
	lastSwing[player] = now
	o.Picks[pickId] -= 1
	local pick = Rules.Picks[pickId]
	local crit = rng:NextNumber() < Rules.CritChance + pick.Crit
	node.Hp = math.max(0, node.Hp - Rules.damage(pickId, crit))
	node.ClaimedBy, node.ClaimUntil = player.UserId, now + Rules.ClaimSeconds
	local model = node.Model
	model:SetAttribute("ClaimedBy", player.UserId)
	model:SetAttribute("LastHitBy", player.UserId)
	model:SetAttribute("LastCrit", crit)
	model:SetAttribute("Hp", node.Hp)
	-- The chop, for everyone to see (Client BodyPoses).
	local character = player.Character
	if character then
		local t = workspace:GetServerTimeNow()
		character:SetAttribute("ActionKind", "Heavy")
		character:SetAttribute("ActionStart", t - 0.12)
		character:SetAttribute("ActionAt", t + 0.05)
	end
	local broke = o.Picks[pickId] <= 0
	if broke then
		o.Picks[pickId] = nil
		record(profile)
		pickModel(player)
	end
	local result = {
		Hp = node.Hp,
		MaxHp = node.MaxHp,
		Crit = crit,
		Tension = Rules.tension(node.Hp, node.MaxHp),
		PickBroke = if broke then pick.Name else nil,
		State = stateOf(player),
	}
	if node.Hp <= 0 then
		result.Loot = loot(player, node, profile)
		popNode(node, player)
	end
	PlayerData.sync(player)
	return reply(true, "", result)
end

local function nearProbe(player: Player): boolean
	local root = rootOf(player)
	return root ~= nil and site ~= nil and (root.Position - site.Probe.Position).Magnitude <= 40
end

local function buy(player: Player, pickId: any)
	local pick = type(pickId) == "string" and Rules.Picks[pickId] or nil
	if not pick or pick.Price <= 0 then
		return reply(false, "The Probe doesn't sell that.")
	end
	if not nearProbe(player) then
		return reply(false, "Visit the Probe to buy picks.")
	end
	local profile = PlayerData.get(player)
	if not profile or not PlayerData.spendCoins(player, pick.Price) then
		return reply(false, "Not enough coins.")
	end
	local o = record(profile)
	o.Picks[pickId] = (o.Picks[pickId] or 0) + pick.Swings
	o.Active = pickId
	if player:GetAttribute("Outpost") then
		pickModel(player)
	end
	PlayerData.sync(player)
	return reply(true, pick.Name .. " ready: " .. pick.Swings .. " swings.", { State = stateOf(player) })
end

local function equip(player: Player, pickId: any)
	local profile = PlayerData.get(player)
	if not profile or type(pickId) ~= "string" or not Rules.Picks[pickId] then
		return reply(false, "Pick not found.")
	end
	local o = record(profile)
	if (o.Picks[pickId] or 0) <= 0 then
		return reply(false, "You don't have that pick.")
	end
	o.Active = pickId
	if player:GetAttribute("Outpost") then
		pickModel(player)
	end
	return reply(true, Rules.Picks[pickId].Name .. " in hand.", { State = stateOf(player) })
end

local function enter(player: Player)
	if player:GetAttribute("CombatSession") or player:GetAttribute("MatchId") then
		return reply(false, "Finish your fight first.")
	end
	if player:GetAttribute("Expedition") then
		return reply(false, "Return from your expedition first.")
	end
	local root = rootOf(player)
	if not site or not root or not PlayerData.get(player) then
		return reply(false, "The Outpost isn't ready yet. Try again in a moment.")
	end
	pcall(function()
		player:RequestStreamAroundAsync(site.Spawn.Position)
	end)
	local character = player.Character :: Model
	character:PivotTo(site.Spawn * CFrame.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-4, 4)))
	player:SetAttribute("Outpost", true)
	refreshKit(player)
	socialPrompts(player, true)
	return reply(true, "Welcome to Saga Outpost.", { State = stateOf(player) })
end

local function leave(player: Player)
	player:SetAttribute("Outpost", nil)
	refreshKit(player)
	socialPrompts(player, false)
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if player.Character then
		player.Character:PivotTo(if spawn then spawn.CFrame + Vector3.new(0, 4, 0) else CFrame.new(0, 6, 0))
	end
	return reply(true, "Back at base.")
end

-- The billboard: top gear scores and duel wins.
local function drawBoard()
	local face = site and site.Board
	if not face then
		return
	end
	local gui = face:FindFirstChild("Board") :: SurfaceGui?
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(1140, 540)
		gui.LightInfluence = 0
		gui.Brightness = 1.6
		gui.Parent = face
	end
	gui:ClearAllChildren()
	local function label(text, x, y, w, h, size, color, font, align)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position, l.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
		l.Text, l.TextSize, l.TextColor3 = text, size, color
		l.Font = font or Enum.Font.GothamBold
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = gui
		return l
	end
	label(
		"SAGA OUTPOST  ·  HALL OF MINERS",
		0,
		14,
		1140,
		52,
		44,
		Color3.fromRGB(255, 196, 90),
		Enum.Font.GothamBlack,
		Enum.TextXAlignment.Center
	)
	for column, spec in
		{
			{ "Gear", "TOP ARMOR  ·  GEAR SCORE", Color3.fromRGB(110, 220, 255) },
			{ "Wins", "MOST DUEL WINS", Color3.fromRGB(255, 110, 120) },
		}
	do
		local x = 40 + (column - 1) * 560
		label(spec[2], x, 84, 520, 34, 28, spec[3])
		local rows = TopPlayers.board(spec[1])
		for i = 1, 8 do
			local row = rows[i]
			local y = 128 + (i - 1) * 48
			local color = if i == 1 then Color3.fromRGB(255, 214, 110) else Color3.fromRGB(225, 232, 245)
			label(string.format("%d.", i), x, y, 46, 42, 30, color)
			label(if row then row.Name else "—", x + 50, y, 330, 42, 30, color, Enum.Font.GothamMedium)
			label(
				if row then tostring(math.floor(row.Value)) else "",
				x + 380,
				y,
				130,
				42,
				30,
				color,
				Enum.Font.GothamBold,
				Enum.TextXAlignment.Right
			)
		end
	end
end

-- The Probe's screen and the gate's sign.
local function drawSigns()
	local function sign(part: BasePart, title: string, sub: string, color: Color3)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(400, 200)
		gui.LightInfluence = 0
		gui.Parent = part
		for i, line in { { title, 46, 30 }, { sub, 24, 110 } } do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size, l.Position = UDim2.new(1, 0, 0, line[2] + 8), UDim2.fromOffset(0, line[3])
			l.Text, l.TextSize = line[1], line[2]
			l.TextColor3 = if i == 1 then color else Color3.fromRGB(220, 235, 255)
			l.Font = if i == 1 then Enum.Font.GothamBlack else Enum.Font.GothamMedium
			l.Parent = gui
		end
	end
	sign(site.Probe, "PROBE-7", "EXCHANGE  ·  PICKS  ·  MARKET", Color3.fromRGB(110, 220, 255))
end

-- An Easter egg found: paid once per player (and a bonus for the full set),
-- told to the whole server. Found again, it just shows its story.
local function secret(player: Player, id: any)
	if player:GetAttribute("Outpost") ~= true then
		return reply(false, "")
	end
	local spec = type(id) == "string" and Rules.Secrets[id] or nil
	local part = spec and secretParts[id]
	if not spec or not part then
		return reply(false, "")
	end
	local root = rootOf(player)
	if not root or (root.Position - part.CFrame.Position).Magnitude > 20 then
		return reply(false, "Get closer.")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your data is still loading.")
	end
	local o = record(profile)
	o.Secrets = o.Secrets or {}
	local new = not o.Secrets[id]
	o.Secrets[id] = true
	local found = 0
	for _ in o.Secrets do
		found += 1
	end
	local total = #Rules.SecretOrder
	local coins, bonus = 0, 0
	if new then
		coins = Rules.SecretReward
		bonus = if found >= total then Rules.SecretBonus else 0
		PlayerData.addCoins(player, coins + bonus)
		ChatChannels.announce(
			"System",
			string.format("%s discovered a secret: %s! (%d/%d)", player.DisplayName, spec.Name, found, total)
		)
		if bonus > 0 then
			ChatChannels.announce("Loot", player.DisplayName .. " has found every secret on the moon!")
		end
	end
	return reply(true, "", {
		Secret = {
			Id = id,
			Name = spec.Name,
			Lore = spec.Lore,
			New = new,
			Found = found,
			Total = total,
			Coins = coins,
			Bonus = bonus,
		},
		State = stateOf(player),
	})
end

function OutpostServer.start()
	site = OutpostWorld.build(Rules.Location, workspace)
	local folder = Instance.new("Folder")
	folder.Name = "Nodes"
	folder.Parent = site.Model
	nodesFolder = folder
	for index in site.Spots do
		freeSpots[index] = true
	end
	for _ = 1, math.min(Rules.NodeCount, #site.Spots) do
		spawnNode()
	end
	-- Prompts at the Probe (market) and the Arena gate.
	for _, spec in
		{
			{ site.Probe, "Probe", "Open the Exchange", "PROBE-7" },
			{ site.Gate, "Gate", "Arena Uplink", "Duels · Raids · Rival" },
		}
	do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = spec[3], spec[4]
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("PromptKind", spec[2])
		prompt.Parent = spec[1]
	end
	-- The hidden Easter eggs: a prompt that says nothing about what it is.
	for _, part in site.Secrets or {} do
		local id = part:GetAttribute("SecretId")
		secretParts[id] = part
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "Inspect", "???"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("PromptKind", "Secret")
		prompt:SetAttribute("SecretId", id)
		prompt.Parent = part
	end
	drawSigns()
	-- Where a finished duel brings an Outpost visitor back to (ArenaSessions.leave).
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	if not landmarks then
		landmarks = Instance.new("Folder")
		landmarks.Name = "Landmarks"
		landmarks.Parent = ReplicatedStorage
	end
	landmarks:SetAttribute("OutpostSpawn", site.Spawn)

	Shop.register("OutpostEnter", enter)
	Shop.register("OutpostLeave", leave)
	Shop.register("OutpostHit", hit)
	Shop.register("OutpostBuyPick", buy)
	Shop.register("OutpostEquipPick", equip)
	Shop.register("OutpostSecret", secret)
	Shop.register("OutpostState", function(player)
		return reply(true, "", { State = stateOf(player) })
	end)

	local function watch(player: Player)
		player:GetAttributeChangedSignal("CombatSession"):Connect(function()
			refreshKit(player)
		end)
		player.CharacterAdded:Connect(function(character)
			-- Back on your feet at the Outpost after a respawn.
			if player:GetAttribute("Outpost") then
				task.wait(0.5)
				if player.Character == character and site then
					character:PivotTo(site.Spawn)
					refreshKit(player)
					socialPrompts(player, true)
				end
			end
		end)
		player.CharacterAdded:Connect(function(character)
			-- A rebuilt outfit brings the weapon back: put it away again.
			character.ChildAdded:Connect(function(child)
				if child.Name == "GemsoulGear" and player:GetAttribute("Outpost") then
					task.defer(refreshKit, player)
				end
			end)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		for _, node in nodes do
			if node.ClaimedBy == player.UserId then
				node.ClaimedBy = nil
			end
		end
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			pcall(drawBoard)
			task.wait(30)
		end
	end)
end

-- For tests.
OutpostServer._hit, OutpostServer._enter, OutpostServer._buy = hit, enter, buy
OutpostServer._secret = secret
OutpostServer._nodes = nodes
function OutpostServer.site()
	return site
end

return OutpostServer
