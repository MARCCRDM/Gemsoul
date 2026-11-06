--[[
	The Outpost's LED screens, lit (World.OutpostWorld builds them: giants
	in the sky round the whole settlement, facing in, each a LedPanel with
	its Board attribute; Shared.Led draws the pages; Server.Boards sends
	their data on ReplicatedStorage.LedBoards).

	Every screen is a grid of LEDs (Led.W x Led.H), each its own dot, dim
	when it's off. A screen shows its board's pages one at a time, Hold
	seconds each, the next wiping in across it column by column. A screen's
	LEDs are only built while you're within Reach of it (and go past Drop).

	  LedScreens.step(dt)   each frame while you're in the Outpost
	  LedScreens.clear()    all of them off (you've left)
]]
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Led = require(ReplicatedStorage.Shared.Led)

local LedScreens = {}
LedScreens.Hold = 5 -- seconds a page stays up
LedScreens.Wipe = 0.45 -- seconds for the next to wipe across
LedScreens.Reach = 1100 -- studs: built within this (they're seen from all over the Outpost)
LedScreens.Drop = 1250 -- studs: taken down past this
LedScreens.Every = 0.5 -- seconds between looks round
LedScreens.Dot = 0.72 -- of a cell, an LED's size
LedScreens.RowsPerFrame = 6 -- LED rows built a frame (no hitch)

local OFF = Color3.fromRGB(22, 25, 34)

-- [panel] = { Gui, Dots = { Frame }, Built, Board, Pages, Page, Shown = { rgb }, Since, Wiping }
local screens: { [BasePart]: any } = {}
local since = math.huge
local folder: Instance? = nil
local data: { [string]: any } = {}

local function color(rgb: number?): Color3
	if not rgb then
		return OFF
	end
	return Color3.fromRGB(rgb // 65536 % 256, rgb // 256 % 256, rgb % 256)
end

local function boardData(board: string): any
	local box = ReplicatedStorage:FindFirstChild("LedBoards")
	local raw = box and box:GetAttribute(board)
	if type(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok then decoded else nil
end

local function makePages(screen)
	local raw = boardData(screen.Board)
	screen.Pages = Led.pages(screen.Board, raw)
	if screen.Page > #screen.Pages then
		screen.Page = 1
	end
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
	local screen = {
		Panel = panel,
		Gui = gui,
		Back = back,
		Dots = {},
		BuiltRows = 0,
		Board = panel:GetAttribute("Board") or "Ranked",
		Page = 1,
		Shown = {},
		Since = 0,
		Wiping = nil,
	}
	makePages(screen)
	return screen
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

-- Lights columns [from, to) of the screen as page `page` has them.
local function paint(screen, page, from: number, to: number)
	local w = Led.W
	for x = from, math.min(to, w) - 1 do
		for y = 0, Led.H - 1 do
			local i = y * w + x + 1
			local want = page and page.P[i]
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
				local far = (d.CFrame.Position - camera.CFrame.Position).Magnitude
				if screens[d] then
					seen[d] = far < LedScreens.Drop
				elseif far < LedScreens.Reach then
					screens[d] = build(d)
					seen[d] = true
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
			if screen.BuiltRows >= Led.H then
				paint(screen, screen.Pages[screen.Page], 0, Led.W)
			end
			continue
		end
		screen.Since += dt
		if screen.Wiping then
			-- (the next page wiping in, column by column)
			local t = math.clamp(screen.Since / LedScreens.Wipe, 0, 1)
			local upto = math.floor(t * Led.W + 0.5)
			paint(screen, screen.Pages[screen.Page], screen.Wiping, upto)
			screen.Wiping = upto
			if t >= 1 then
				screen.Wiping = nil
				screen.Since = 0
			end
		elseif screen.Since >= LedScreens.Hold then
			-- the next page, its board's data as it is now
			makePages(screen)
			screen.Page = screen.Page % math.max(1, #screen.Pages) + 1
			screen.Since = 0
			screen.Wiping = 0
		end
	end
end

-- For tests.
LedScreens._screens = screens

return LedScreens
