-- lune run tests/fight_drama_cases.luau <repo>
-- The fight's drama (Client Modules/FightDrama), on Roblox's own UI
-- instances with stand-ins for the services: the announcer's callouts
-- (FIRST BLOOD, combos, PERFECT PARRY, only in a 1v1), low health (the
-- heartbeat, the music muffled, LAST STAND), and a rival's entrance, words
-- and K.O. (FLAWLESS when you took nothing).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local ROOT = process.args[1] or "."
local checks = 0
local function check(v, m)
	checks += 1
	if not v then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(m) .. "\n")
		process.exit(1)
	end
end
local function signal()
	local fns = {}
	return {
		Connect = function(_, fn) table.insert(fns, fn); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, fn in fns do fn(...) end end,
	}
end

-- Stand-ins: a humanoid (its events fired by hand), a body, the player.
local function humanoid(health, most)
	local h = { Health = health, MaxHealth = most, HealthChanged = signal(), Died = signal() }
	function h:IsA(c) return c == "Humanoid" end
	return h
end
local function body(h, attrs, head)
	local sigs = {}
	local b = { Parent = true, Attrs = attrs or {}, Head = head }
	function b:FindFirstChildOfClass(c) return if c == "Humanoid" then h else nil end
	function b:FindFirstChild(n) return if n == "Head" then head elseif n == "HumanoidRootPart" then nil else nil end
	function b:WaitForChild(n) return if n == "Humanoid" then h else nil end
	function b:GetAttribute(k) return self.Attrs[k] end
	function b:SetAttribute(k, v) self.Attrs[k] = v; if sigs[k] then sigs[k]:Fire() end end
	function b:GetAttributeChangedSignal(k) sigs[k] = sigs[k] or signal(); return sigs[k] end
	function b:IsA(c) return c == "Model" end
	return b
end
local mine = humanoid(100, 100)
local me = body(mine)
local attrs, attrSigs = {}, {}
local LocalPlayer = {
	UserId = 1, Name = "Tester", Character = me, CharacterAdded = signal(),
	GetAttribute = function(_, k) return attrs[k] end,
	SetAttribute = function(_, k, v) attrs[k] = v; if attrSigs[k] then attrSigs[k]:Fire() end end,
	GetAttributeChangedSignal = function(_, k) attrSigs[k] = attrSigs[k] or signal(); return attrSigs[k] end,
}
local playerGui = roblox.Instance.new("Folder")
local lighting = roblox.Instance.new("Folder")
local musicGroup = roblox.Instance.new("SoundGroup")
local heartbeat = signal()
local enemies = { List = {} }
function enemies:GetChildren() return self.List end
local services = {
	Lighting = lighting,
	Players = { LocalPlayer = LocalPlayer, GetPlayers = function() return { LocalPlayer } end, PlayerAdded = signal() },
	RunService = { Heartbeat = heartbeat },
	SoundService = roblox.Instance.new("Folder"),
	TweenService = { Create = function(_, inst, _, goal)
		-- (no animation here: straight to where it's going)
		return { Play = function() for k, v in goal do inst[k] = v end end }
	end },
}
local camera = roblox.Instance.new("Camera")
local stubs = {
	UiKit = {
		gui = function(name)
			local g = roblox.Instance.new("ScreenGui"); g.Name = name; g.Parent = playerGui; return g
		end,
		round = function(frame) local c = roblox.Instance.new("UICorner"); c.Parent = frame end,
	},
	CombatFx = { shake = function() end },
	Music = { group = function() return musicGroup end },
}
local env = setmetatable({
	game = { GetService = function(_, n) return services[n] or error("no service " .. n) end },
	workspace = { CurrentCamera = camera, FindFirstChild = function(_, n) return if n == "Enemies" then enemies else nil end },
	script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
	require = function(name) return stubs[name] or error("no stub " .. tostring(name)) end,
	task = task, Instance = roblox.Instance, Enum = roblox.Enum, Color3 = roblox.Color3, UDim2 = roblox.UDim2,
	Vector2 = roblox.Vector2, Vector3 = roblox.Vector3,
	TweenInfo = { new = function() return {} end },
}, { __index = _G })
local Drama = luau.load(fs.readFile(ROOT .. "/src/client/Modules/FightDrama.luau"), { debugName = "FightDrama", environment = env })()
Drama.start()
local function words()
	local gui = playerGui:FindFirstChild("FightDrama")
	local w = gui and gui:FindFirstChild("Word")
	local s = gui and gui:FindFirstChild("Sub")
	return if w and w.TextTransparency < 1 then w.Text else nil, if s and s.TextTransparency < 1 then s.Text else nil
end
local function settle() task.wait(1.25) end -- (the last callout gone)

-- The announcer: only in a 1v1.
attrs.CombatSession = "Raid"
Drama.setFight(true)
Drama.contact({ Combo = 1 })
check(words() == nil, "A callout outside a 1v1")
Drama.setFight(false)
attrs.CombatSession = "Training"
Drama.setFight(true)
Drama.contact({ Combo = 1 })
check(words() == "FIRST BLOOD", "No FIRST BLOOD on your first blow: " .. tostring(words()))
Drama.contact({ Combo = 3 })
check(words() == "FIRST BLOOD", "A combo cut over FIRST BLOOD")
settle()
Drama.contact({ Combo = 3 })
check(words() == "COMBO  x3", "No COMBO x3: " .. tostring(words()))
settle()
Drama.contact({ Combo = 5, Blocked = true })
check(words() == nil, "A blocked blow called out")
Drama.contact({ Combo = 5 })
check(words() == "x5  UNSTOPPABLE", "No x5")
settle()
Drama.parry()
check(words() == "PERFECT PARRY", "No PERFECT PARRY")
check(lighting:FindFirstChild("FightDramaGrade") ~= nil, "The parry's flash of colour")
settle()

-- Low health: the music muffled, the heartbeat, LAST STAND once.
mine.Health = 15
heartbeat:Fire()
check(musicGroup:FindFirstChild("FightDramaMuffle") ~= nil, "The music wasn't muffled at low health")
check(words() == "LAST STAND", "No LAST STAND: " .. tostring(words()))
settle()
heartbeat:Fire()
check(words() == nil, "LAST STAND twice in a fight")
mine.Health = 90
heartbeat:Fire()
check(musicGroup:FindFirstChild("FightDramaMuffle") == nil, "The music stayed muffled")
Drama.setFight(false)
mine.Health = 15
heartbeat:Fire()
check(musicGroup:FindFirstChild("FightDramaMuffle") == nil, "Muffled out of a fight")
mine.Health = 100

-- A rival: VS its name and title, its words, its K.O. (flawless).
local head = roblox.Instance.new("Part")
local foe = humanoid(100, 100)
local rival = body(foe, { RivalOwner = 1, RivalName = "Sable", RivalTitle = "THE SHADOW" }, head)
table.insert(enemies.List, rival)
Drama.setFight(true)
task.wait(0.35)
heartbeat:Fire()
local w, s = words()
check(w == "VS  SABLE" and s == "THE SHADOW", "No VS card for the rival: " .. tostring(w) .. " / " .. tostring(s))
task.wait(1.6)
local said = head:FindFirstChild("RivalSays")
local text = said and said:FindFirstChildWhichIsA("TextLabel", true)
check(text ~= nil and text.Text == Drama.Lines.Sable.Enter, "The rival didn't walk in with its line")
foe.HealthChanged:Fire(45)
text = head:FindFirstChild("RivalSays") and head:FindFirstChild("RivalSays"):FindFirstChildWhichIsA("TextLabel", true)
check(text ~= nil and text.Text == Drama.Lines.Sable.Hurt, "Hurt, the rival said nothing")
foe.HealthChanged:Fire(40)
check(head:FindFirstChild("RivalSays"):FindFirstChildWhichIsA("TextLabel", true).Text == Drama.Lines.Sable.Hurt, "The rival repeats itself")
settle()
foe.Died:Fire()
w, s = words()
check(w == "K.O.!" and s == "FLAWLESS VICTORY", "No K.O. (flawless) on the rival: " .. tostring(w) .. " / " .. tostring(s))
check(camera.FieldOfView > 0, "The K.O.'s punch-in broke the view")

-- Ranked: the other player knocked out (RoundKO) is a K.O. too; you, KNOCKED OUT.
settle()
local other = { UserId = 2, Character = nil, CharacterAdded = signal() }
local theirs = body(humanoid(1, 100))
other.Character = theirs
other.GetAttribute = function(_, k) return ({ MatchId = "D1", MatchTeam = 2 })[k] end
attrs.MatchId, attrs.MatchTeam, attrs.CombatSession = "D1", 1, "Duel"
services.Players.PlayerAdded:Fire(other)
task.wait(0.05)
mine.Health = 60
theirs:SetAttribute("RoundKO", true)
w, s = words()
check(w == "K.O.!" and s == nil, "No K.O. when your opponent's knocked out: " .. tostring(w))
settle()
me:SetAttribute("RoundKO", true)
check(words() == "KNOCKED OUT", "No KNOCKED OUT when you're knocked out")
print(string.format("PASS: %d fight drama checks (callouts only in a 1v1, first blood, combos, parry, low health and LAST STAND, a rival's VS card, words and flawless K.O., Ranked K.O.s)", checks))
process.exit(0)
