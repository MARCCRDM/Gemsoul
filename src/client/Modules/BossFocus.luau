--[[
	Where a boss's attention is. A raid boss, a Rift boss or a dungeon's
	boss turns between the players fighting it and their kaiju by the damage
	it takes (Shared.Aggro, Server.Duelist), so everyone in the fight should
	see who it's on right now, not just the one it hits: a red diamond
	hangs over the target's head with TARGET under it; yours (you, or one
	of your kaiju) is bigger, brighter and pulses, and reads ON YOU over
	you. The server names the target on the boss's model (FocusKaiju, a
	kaiju's id, else FocusUserId, a player), and only the players in that
	fight (its RaidId, RiftRun or DungeonId on them too) see the marks.

	  BossFocus.start()                      once (Lobby.client, Combat.client)
	  BossFocus.isBoss(get) -> boolean       a fight's boss, by its attributes
	                                         (pure: `get(name)` reads one)
	  BossFocus.inFight(boss, me) -> bool    is this player in that boss's
	                                         fight (both `get` functions; pure)
	  BossFocus.text(mine, kaiju) -> string  the mark's words (pure)
	  BossFocus.scale(t, mine) -> number     the pulse at time `t` (pure)
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BossFocus = {}

BossFocus.Rescan = 0.25 -- seconds between looks at who's on whom
BossFocus.Range = 160 -- studs from the camera: further, no mark
BossFocus.Pulse = 1.1 -- seconds per beat of your own mark
BossFocus.Lift = 2.4 -- studs above the head

local RED = Color3.fromRGB(236, 58, 70)
local HOT = Color3.fromRGB(255, 110, 96)
local INK = Color3.fromRGB(12, 11, 16)
local PALE = Color3.fromRGB(255, 226, 222)

-- A fight's boss: a Rift boss, a dungeon's boss room fighter, or a party
-- raid's boss (a raid with no dungeon or Rift about it has only the one
-- creature). A dungeon room's ordinary fighters aren't marked.
function BossFocus.isBoss(get: (string) -> any): boolean
	if get("RaidId") == nil then
		return false
	end
	if get("RiftBoss") or get("DungeonBoss") then
		return true
	end
	return get("DungeonId") == nil and get("RiftRun") == nil
end

-- Whether the player is in that boss's fight: in its raid, its Rift trip
-- or its dungeon.
function BossFocus.inFight(boss: (string) -> any, me: (string) -> any): boolean
	for _, name in { "RaidId", "RiftRun", "DungeonId" } do
		local id = boss(name)
		if id ~= nil and me(name) == id then
			return true
		end
	end
	return false
end

-- The words under the diamond: over you, over one of your kaiju, over
-- anyone else's.
function BossFocus.text(mine: boolean, kaiju: boolean): string
	if mine then
		return if kaiju then "ON YOUR KAIJU" else "ON YOU"
	end
	return "TARGET"
end

-- The mark's size over time: yours beats, the rest hold still.
function BossFocus.scale(t: number, mine: boolean): number
	if not mine then
		return 1
	end
	local phase = (t % BossFocus.Pulse) / BossFocus.Pulse
	return 1.15 + 0.2 * math.max(0, math.cos(phase * math.pi * 2))
end

type Mark = { Board: BillboardGui, Diamond: Frame, Label: TextLabel, Target: Model?, Mine: boolean, Kaiju: boolean }
local marks: { [Model]: Mark } = {}

local function attr(instance: Instance): (string) -> any
	return function(name)
		return instance:GetAttribute(name)
	end
end

local function make(class: string, props, parent: Instance?)
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function build(): Mark
	local board = make("BillboardGui", {
		Name = "BossFocus",
		Size = UDim2.fromOffset(120, 54),
		AlwaysOnTop = true,
		MaxDistance = BossFocus.Range,
		ResetOnSpawn = false,
		Enabled = false,
	}, Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))
	-- (A square turned on its corner: the diamond, with a dark heart.)
	local diamond = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(16, 16),
		Rotation = 45,
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
	}, board)
	make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, diamond)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.4, 0.4),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
	}, diamond)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 28),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextColor3 = PALE,
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0.2,
		Text = "TARGET",
	}, board)
	return { Board = board, Diamond = diamond, Label = label, Target = nil, Mine = false, Kaiju = false }
end

local function headOf(model: Model): BasePart?
	local head = model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return if head and head:IsA("BasePart") then head else nil
end

local function kaijuOf(id: any): Model?
	local folder = if id ~= nil then workspace:FindFirstChild("Kaiju") else nil
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("KaijuId") == id then
			return model
		end
	end
	return nil
end

local function alive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Health > 0
end

-- Whom the boss is on, on this screen: the kaiju it names, else the player.
local function targetOf(boss: Model): (Model?, boolean)
	local kaiju = kaijuOf(boss:GetAttribute("FocusKaiju"))
	if kaiju and kaiju.Parent and alive(kaiju) then
		return kaiju, true
	end
	local userId = boss:GetAttribute("FocusUserId") or boss:GetAttribute("RivalOwner")
	local owner = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local character = owner and owner.Character
	return if character and alive(character) then character else nil, false
end

local function drop(boss: Model)
	local mark = marks[boss]
	if mark then
		mark.Board:Destroy()
		marks[boss] = nil
	end
end

local function scan()
	local me = Players.LocalPlayer
	local folder = workspace:FindFirstChild("Enemies")
	local seen = {}
	if folder and me then
		local mine = attr(me)
		for _, boss in folder:GetChildren() do
			if boss:IsA("Model") and alive(boss) then
				local get = attr(boss)
				if BossFocus.isBoss(get) and BossFocus.inFight(get, mine) then
					local target, kaiju = targetOf(boss)
					local head = target and headOf(target)
					if target and head then
						seen[boss] = true
						local mark = marks[boss]
						if not mark then
							mark = build()
							marks[boss] = mark
						end
						local owned = if kaiju then target:GetAttribute("KaijuOwner") == me.UserId else target == me.Character
						if mark.Target ~= target or mark.Mine ~= owned or mark.Kaiju ~= kaiju then
							mark.Target, mark.Mine, mark.Kaiju = target, owned, kaiju
							mark.Board.Adornee = head
							mark.Board.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + BossFocus.Lift, 0)
							mark.Label.Text = BossFocus.text(owned, kaiju)
							mark.Label.TextColor3 = if owned then HOT else PALE
							mark.Diamond.BackgroundColor3 = if owned then HOT else RED
							mark.Board.Enabled = true
						end
					end
				end
			end
		end
	end
	for boss in marks do
		if not seen[boss] then
			drop(boss)
		end
	end
end

local function beat()
	local t = os.clock()
	for _, mark in marks do
		local scale = BossFocus.scale(t, mark.Mine)
		local size = math.floor(16 * scale + 0.5)
		mark.Diamond.Size = UDim2.fromOffset(size, size)
	end
end

local started = false
function BossFocus.start()
	if started then
		return
	end
	started = true
	local nextScan = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + BossFocus.Rescan
			scan()
		end
		beat()
	end)
end

return BossFocus
