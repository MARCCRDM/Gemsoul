--[[
	The Outpost's LED screens, lit (World.OutpostWorld builds them: giants
	in the sky round the whole settlement (eight), facing in, each a LedPanel with
	its Board attribute; Shared.Led draws their scenes, from the game's own
	kaiju and bosses: Shared.Kaiju, Shared.RiftRun).

	Every screen is a grid of LEDs (Led.W x Led.H), each its own dot, dim
	when it's off. A screen plays its board's scenes one after another,
	animated (Fps frames a second, only the LEDs that change are touched),
	the next scene wiping in across it column by column. A screen's LEDs are
	only built while you're within Reach of it (and go past Drop), and only
	drawn while it's in front of your camera (one behind you is switched
	off and keeps time without painting: there are eight).

	  LedScreens.step(dt)   each frame, wherever you are (the Arena under them
	                        too); out of Reach, nothing's built
	  LedScreens.clear()    all of them off
	  LedScreens.info() -> Led.scenes' info (the kaiju and bosses shown)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Led = require(ReplicatedStorage.Shared.Led)

local LedScreens = {}
LedScreens.Fps = 10 -- frames a second
LedScreens.Wipe = 0.45 -- seconds for the next scene to wipe across
LedScreens.Reach = 1100 -- studs: built within this (they're seen from all over the Outpost)
LedScreens.Drop = 1250 -- studs: taken down past this
LedScreens.Every = 0.5 -- seconds between looks round
LedScreens.Dot = 0.72 -- of a cell, an LED's size
LedScreens.RowsPerFrame = 6 -- LED rows built a frame (no hitch)
LedScreens.Behind = -0.25 -- the camera's look against the way to a screen: under this, it's behind you

local OFF = Color3.fromRGB(22, 25, 34)

-- [panel] = { Gui, Back, Dots, BuiltRows, Board, Scenes, Scene, T, Frame, Shown, Wiping }
local screens: { [BasePart]: any } = {}
local since = math.huge
local folder: Instance? = nil
local cached: any = nil

local function color(rgb: number?): Color3
	if not rgb then
		return OFF
	end
	return Color3.fromRGB(rgb // 65536 % 256, rgb // 256 % 256, rgb % 256)
end

-- The kaiju and bosses the screens show, from the game's data (once).
function LedScreens.info()
	if cached then
		return cached
	end
	local okK, Kaiju = pcall(require, ReplicatedStorage.Shared.Kaiju)
	local okR, RiftRun = pcall(require, ReplicatedStorage.Shared.RiftRun)
	local order = {}
	if okR and RiftRun and RiftRun.Ladders then
		for _, element in { "Fire", "Frost", "Shock", "Poison" } do
			for _, id in RiftRun.Ladders[element] or {} do
				table.insert(order, id)
			end
		end
	end
	cached = Led.catalog(function(name)
		local species = okK and Kaiju and Kaiju.Species and Kaiju.Species[name]
		return species and species.Role
	end, function(id)
		return okR and RiftRun and RiftRun.bossById(id)
	end, order)
	return cached
end

local function build(panel: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LedGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.MaxDistance = LedScreens.Drop
	gui.ClipsDescendants = true
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = gui
	gui.Adornee = panel
	gui.Parent = panel
	return {
		Panel = panel,
		Gui = gui,
		Back = back,
		Dots = {},
		BuiltRows = 0,
		Board = panel:GetAttribute("Board") or "Guide",
		Scenes = Led.scenes(panel:GetAttribute("Board") or "Guide", LedScreens.info()),
		Scene = 1,
		T = 0,
		Frame = math.huge,
		Shown = {},
		Wiping = nil,
		Visible = true,
	}
end

-- A few rows of LEDs more (all of them built over a few frames).
local function buildRows(screen)
	local w, h = Led.W, Led.H
	local size = UDim2.fromScale(LedScreens.Dot / w, LedScreens.Dot / h)
	local last = math.min(h, screen.BuiltRows + LedScreens.RowsPerFrame)
	for y = screen.BuiltRows, last - 1 do
		for x = 0, w - 1 do
			local dot = Instance.new("Frame")
			dot.BorderSizePixel = 0
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromScale((x + 0.5) / w, (y + 0.5) / h)
			dot.Size = size
			dot.BackgroundColor3 = OFF
			dot.Parent = screen.Back
			screen.Dots[y * w + x + 1] = dot
		end
	end
	screen.BuiltRows = last
end

-- Lights columns [from, to) of the screen as `frame` has them.
local function paint(screen, frame, from: number, to: number)
	local w = Led.W
	for x = from, math.min(to, w) - 1 do
		for y = 0, Led.H - 1 do
			local i = y * w + x + 1
			local want = frame and frame.P[i]
			if screen.Shown[i] ~= want then
				screen.Shown[i] = want
				local dot = screen.Dots[i]
				if dot then
					dot.BackgroundColor3 = color(want)
				end
			end
		end
	end
end
LedScreens._paint = paint

local function drop(panel: BasePart)
	local screen = screens[panel]
	screens[panel] = nil
	if screen and screen.Gui then
		screen.Gui:Destroy()
	end
end

function LedScreens.clear()
	for panel in screens do
		drop(panel)
	end
end

-- One step of a screen's show: the scene's frame now (a few a second), the
-- next scene when this one's over, wiping in.
local function play(screen, dt: number)
	screen.T += dt
	local current = screen.Scenes[screen.Scene]
	if screen.T >= current.Duration then
		screen.Scene = screen.Scene % #screen.Scenes + 1
		screen.T = 0
		screen.Wiping = if screen.Visible then 0 else nil
		current = screen.Scenes[screen.Scene]
	end
	-- (behind you: time goes on, nothing's painted)
	if not screen.Visible then
		screen.Frame = math.huge
		return
	end
	local frame = math.floor(screen.T * LedScreens.Fps)
	if frame == screen.Frame and not screen.Wiping then
		return
	end
	screen.Frame = frame
	local ok, buffer = pcall(current.Draw, frame / LedScreens.Fps)
	if not ok then
		return
	end
	if screen.Wiping then
		local upto = math.floor(math.clamp(screen.T / LedScreens.Wipe, 0, 1) * Led.W + 0.5)
		paint(screen, buffer, 0, upto)
		screen.Wiping = if upto >= Led.W then nil else upto
	else
		paint(screen, buffer, 0, Led.W)
	end
end

function LedScreens.step(dt: number)
	since += dt
	if since >= LedScreens.Every then
		since = 0
		if not folder or not folder.Parent then
			local settlement = workspace:FindFirstChild("Settlement", true)
			folder = settlement and settlement:FindFirstChild("LedScreens")
		end
		local camera = workspace.CurrentCamera
		local seen = {}
		for _, d in if folder then folder:GetDescendants() else {} do
			if d:IsA("BasePart") and d.Name == "LedPanel" and camera then
				local to = d.CFrame.Position - camera.CFrame.Position
				local far = to.Magnitude
				if screens[d] then
					seen[d] = far < LedScreens.Drop
				elseif far < LedScreens.Reach then
					screens[d] = build(d)
					seen[d] = true
				end
				local screen = screens[d]
				if screen then
					local ahead = far < 1 or camera.CFrame.LookVector:Dot(to / far) > LedScreens.Behind
					if screen.Visible ~= ahead then
						screen.Visible = ahead
						screen.Gui.Enabled = ahead
					end
				end
			end
		end
		for panel in screens do
			if not seen[panel] then
				drop(panel)
			end
		end
	end
	for _, screen in screens do
		if screen.BuiltRows < Led.H then
			buildRows(screen)
			continue
		end
		play(screen, dt)
	end
end

-- For tests.
LedScreens._screens = screens

return LedScreens
