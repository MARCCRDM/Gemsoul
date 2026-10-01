-- UI doubles expose input events and screen bounds; production drag code is inserted below.
local now = 10
local os = {
	clock = function()
		return now
	end,
}
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, f)
			table.insert(callbacks, f)
		end,
		Fire = function(_, ...)
			for _, f in callbacks do
				f(...)
			end
		end,
	}
end
local Vector2 = {}
function Vector2.new(x, y)
	return setmetatable({ X = x, Y = y }, {
		__sub = function(a, b)
			local x1, y1 = a.X - b.X, a.Y - b.Y
			return { Magnitude = math.sqrt(x1 * x1 + y1 * y1) }
		end,
	})
end
local UDim2 = { fromOffset = Vector2.new }
local Enum = {
	UserInputType = { Touch = "Touch", MouseButton1 = "MouseButton1", MouseMovement = "MouseMovement" },
	UserInputState = { Cancel = "Cancel" },
	AutomaticSize = { None = "None" },
	TextXAlignment = { Center = "Center" },
	KeyCode = { Escape = "Escape" },
}
local function new(kind, props, parent)
	local obj = props or {}
	obj.Kind = kind
	obj.Parent = parent
	obj.Children = {}
	obj.Signals = {}
	if parent then
		table.insert(parent.Children, obj)
	end
	function obj:FindFirstChildOfClass(class)
		for _, child in self.Children do
			if child.Kind == class and child.Parent then
				return child
			end
		end
	end
	function obj:Destroy()
		self.Parent = nil
	end
	function obj:GetPropertyChangedSignal(key)
		self.Signals[key] = self.Signals[key] or signal()
		return self.Signals[key]
	end
	return obj
end
local function text(parent)
	return new("TextLabel", {}, parent)
end
local UiKit = { round = function() end }
local P = { Inset = "Inset", Gold = "Gold", Teal = "Teal" }
local BOLD = "Bold"
local GemArt = {
	viewport = function(parent)
		return new("ViewportFrame", {}, parent)
	end,
}
local gui = new("ScreenGui", { Enabled = true })
local grid = { ScrollingEnabled = true }
local boardHint = {}
local Slots = { Order = { "Weapon", "Armor", "Helmet", "Gloves", "Boots", "Shield" }, Definitions = {} }
local equipmentSlots = {}
local gem = { Id = "loose", Cut = 8 }
local GemClient = { Profile = { Gems = { gem }, Character = {} } }
for i, key in Slots.Order do
	Slots.Definitions[key] = { Label = key }
	GemClient.Profile.Character[key] = "equipped"
	local target = new("Frame", { AbsolutePosition = Vector2.new(i * 120, 100), AbsoluteSize = Vector2.new(112, 112) })
	new("UIStroke", {}, target)
	equipmentSlots[key] = { DropTarget = target }
end
local UserInputService =
	{ InputChanged = signal(), InputEnded = signal(), InputBegan = signal(), WindowFocusReleased = signal() }
local mouse = Vector2.new(20, 400)
function UserInputService:GetMouseLocation()
	return mouse
end
local suppressClickUntil = 0
local enchantPending = false
local selection = nil
local requests = {}
local function request(...)
	table.insert(requests, table.pack(...))
end
local function socketed(key)
	return GemClient.Profile.Character[key .. "Gem"]
end
local CharacterUI = { refresh = function() end }
-- INSERT_REAL_DRAG_HANDLERS
local count = 0
local function check(ok, message)
	assert(ok, message)
	count += 1
end
local cell = { Parent = grid }
local function mouseBegin()
	now += 1
	mouse = Vector2.new(20, 400)
	beginDrag(cell, gem, { UserInputType = "MouseButton1" })
end
local function mouseMove(x, y)
	mouse = Vector2.new(x, y)
	UserInputService.InputChanged:Fire({ UserInputType = "MouseMovement" })
end
local function mouseEnd()
	UserInputService.InputEnded:Fire({ UserInputType = "MouseButton1" })
end
for i, key in Slots.Order do
	local n = #requests
	mouseBegin()
	mouseMove(i * 120 + 50, 150)
	check(dragGhost.Visible and not grid.ScrollingEnabled, "Drag must lift gem and lock scroll")
	check(equipmentSlots[key].DropTarget.BackgroundTransparency == 0.65, "Target must highlight")
	mouseEnd()
	check(
		#requests == n + 1
			and requests[#requests][1] == "SocketGem"
			and requests[#requests][2] == gem.Id
			and requests[#requests][3] == key,
		"Wrong enchant request"
	)
	mouseEnd()
	check(#requests == n + 1, "Release sent duplicate request")
	check(not dragGhost.Visible and grid.ScrollingEnabled, "Drop failed cleanup")
	check(selection.Slot == key and suppressClickUntil > now, "Drop must select socket and suppress release-click")
end
local n = #requests
mouseBegin()
mouseEnd()
check(#requests == n, "Click must not enchant")
mouseBegin()
mouseMove(22, 402)
mouseEnd()
check(#requests == n, "Jitter must not enchant")
mouseBegin()
mouseMove(950, 500)
mouseEnd()
check(#requests == n and not dragGhost.Visible, "Outside drop must cancel")
mouseBegin()
mouseMove(170, 150)
UserInputService.InputBegan:Fire({ KeyCode = "Escape" })
mouseEnd()
check(#requests == n and grid.ScrollingEnabled, "Escape must cancel and restore scrolling")
mouseBegin()
mouseMove(170, 150)
UserInputService.WindowFocusReleased:Fire()
mouseEnd()
check(#requests == n, "Lost focus submitted enchant")
mouseBegin()
mouseMove(170, 150)
gui.Enabled = false
gui:GetPropertyChangedSignal("Enabled"):Fire()
mouseEnd()
check(#requests == n and not dragGhost.Visible, "Closing menu submitted enchant")
gui.Enabled = true
mouseBegin()
mouseMove(170, 150)
GemClient.Profile.Gems = {}
mouseEnd()
check(#requests == n, "Stale gem submitted enchant")
GemClient.Profile.Gems = { gem }
local weapon = GemClient.Profile.Character.Weapon
GemClient.Profile.Character.Weapon = nil
mouseBegin()
mouseMove(170, 150)
mouseEnd()
check(#requests == n, "Empty equipment accepted gem")
GemClient.Profile.Character.Weapon = weapon
GemClient.Profile.Character.WeaponGem = { Id = "old" }
mouseBegin()
mouseMove(170, 150)
check(string.find(dragHint.Text, "Old gem returns", 1, true) ~= nil, "Replacement needs return notice")
cancelDrag()
-- Bounds are screen pixels, including a panel scaled down to half size.
local target = equipmentSlots.Weapon.DropTarget
local originalAt, originalSize = target.AbsolutePosition, target.AbsoluteSize
target.AbsolutePosition = Vector2.new(60, 50)
target.AbsoluteSize = Vector2.new(56, 56)
check(dropTargetAt(Vector2.new(80, 75)) == "Weapon", "Scaled target missed")
check(dropTargetAt(Vector2.new(118, 75)) == nil, "Scaled target exceeded bounds")
target.AbsolutePosition = originalAt
target.AbsoluteSize = originalSize
local touch = { UserInputType = "Touch", Position = Vector2.new(20, 400) }
now += 1
beginDrag(cell, gem, touch)
touch.Position = Vector2.new(20, 350)
UserInputService.InputChanged:Fire(touch)
check(drag == nil and grid.ScrollingEnabled, "Touch swipe must keep backpack scrolling")
now += 1
touch.Position = Vector2.new(20, 400)
beginDrag(cell, gem, touch)
now += 0.3
touch.Position = Vector2.new(170, 150)
UserInputService.InputChanged:Fire(touch)
check(dragGhost.Visible, "Held touch must start drag")
UserInputService.InputEnded:Fire({ UserInputType = "Touch", Position = touch.Position })
check(drag ~= nil, "Second finger must not release original gesture")
UserInputService.InputEnded:Fire(touch)
check(#requests == n + 1 and requests[#requests][3] == "Weapon", "Touch drop failed")
n = #requests
mouseBegin()
mouseMove(170, 150)
UserInputService.InputEnded:Fire({ UserInputType = "MouseButton1", UserInputState = "Cancel" })
check(#requests == n and grid.ScrollingEnabled, "Cancelled input submitted request")
enchantPending = true
mouseBegin()
check(drag == nil, "Pending enchant allowed duplicate gesture")
enchantPending = false
local cut = gem.Cut
gem.Cut = nil
mouseBegin()
check(drag == nil, "Uncut gem can be dragged")
gem.Cut = cut
-- Exercise the actual docking lifecycle and then drag through its new ScreenGui.
local embedded = false
local window = { Gui = gui, Close = { Visible = true }, Shade = { Visible = true } }
local originalGui = gui
local panel = new("Frame", {}, gui)
local scale = { Parent = panel, Scale = 0.5 }
local title = {}
local subtitle = {}
local avatarRefreshes = 0
local function refreshAvatar()
	avatarRefreshes += 1
end
-- Standalone-only dependencies: those branches must never run once mounted.
local function fit()
	error("Docked armory used modal fit")
end
local TweenService = {
	Create = function()
		error("Docked armory used modal tween")
	end,
}
local TweenInfo = {}
local atVey, gridKey, pending, avatarModel = false, "", {}, nil
Vector2.zero = Vector2.new(0, 0)
Enum.TextTruncate = { AtEnd = "AtEnd" }
-- INSERT_REAL_ARMORY_LIFECYCLE
local host = new("ScreenGui", { Enabled = true })
local hostRoot = new("Frame", {}, host)
mouseBegin()
mouseMove(170, 150)
CharacterUI.mount(hostRoot, host, Vector2.new(16, 84))
check(embedded and panel.Parent == hostRoot and gui == host, "Armory not mounted in dashboard")
check(dragGhost.Parent == host and scale.Parent == nil, "Ghost/scale not transferred to dashboard coordinates")
check(
	not window.Close.Visible and not window.Shade.Visible and not originalGui.Enabled,
	"Modal chrome survived docking"
)
check(drag == nil and not dragGhost.Visible, "Dock did not cancel old gesture")
check(avatarRefreshes == 1, "Dock did not load avatar")
CharacterUI.close()
check(host.Enabled, "Closing embedded armory hid dashboard")
CharacterUI.toggle()
check(host.Enabled and avatarRefreshes == 2, "Toggle did not preserve dashboard")
local refreshes = avatarRefreshes
CharacterUI.mount(new("Frame"), new("ScreenGui"), Vector2.zero)
check(panel.Parent == hostRoot and avatarRefreshes == refreshes, "Repeated mount duplicated setup")
mouseBegin()
mouseMove(170, 150)
mouseEnd()
check(#requests == n + 1 and requests[#requests][3] == "Weapon", "Docked drag failed")
n = #requests
mouseBegin()
mouseMove(170, 150)
host.Enabled = false
host:GetPropertyChangedSignal("Enabled"):Fire()
mouseEnd()
check(drag == nil and #requests == n, "Hidden dashboard submitted a drag")
CharacterUI.open()
check(not host.Enabled, "Armory open bypassed intro hiding")
host.Enabled = true
host:GetPropertyChangedSignal("Enabled"):Fire()
check(avatarRefreshes == refreshes + 1, "Visible dashboard did not restore avatar")
print(string.format("Gem drag + dashboard docking: %d checks passed.", count))
