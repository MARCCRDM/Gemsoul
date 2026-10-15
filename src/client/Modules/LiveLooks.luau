--[[
	Copies of gear move as the gear itself does.

	Your first-person sword, the Inventory's and the Shop's 3D previews and
	gear art are all clones of real parts. The animated looks on them (a
	skin's seams with a SeamFx, SeamVisibility; Prismatic plates,
	PrismaticShimmer) were found only by CollectionService tag, and a clone
	can't be counted on to bring its tags along, so the copies stood still
	while everyone else saw the gear move. A clone always keeps its
	attributes: whoever makes a copy watches it here, and its parts are
	handed to the animators by attribute.

	A copy also isn't where the world's camera is. A preview (in a
	ViewportFrame) moves while it's on screen, however far off the camera
	is; the first-person copy (in the camera) always moves; and parts that
	aren't drawn anywhere (the Shop's mannequins in ReplicatedStorage) are
	left alone.

	  LiveLooks.watch(root)           a copy: its animated parts move (call it
	                                  before or after the copy is placed)
	  LiveLooks.track(attribute, fn)  (the animators) fn(part) for each part
	                                  carrying `attribute` in a watched copy
	  LiveLooks.follow(part, moved, gone)
	                                  (the animators) moved() as the part moves
	                                  in the game, gone() once it leaves it
	  LiveLooks.place(instance)       where it's drawn: "View" (a preview),
	                                  "Camera", "World" or "Away" (nowhere)
	  LiveLooks.viewOf(instance)      the preview (ViewportFrame) it's in
	  LiveLooks.onScreen(view)        whether a preview shows: it and every
	                                  frame round it visible, its ScreenGui on
]]
local LiveLooks = {}

type Tracker = { Attribute: string, Add: (Instance) -> () }
local trackers: { Tracker } = {}
local roots: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function offer(instance: Instance, only: Tracker?)
	for _, tracker in if only then { only } else trackers do
		if instance:GetAttribute(tracker.Attribute) ~= nil then
			tracker.Add(instance)
		end
	end
end

function LiveLooks.watch(root: Instance)
	if roots[root] then
		return
	end
	roots[root] = true
	offer(root)
	for _, descendant in root:GetDescendants() do
		offer(descendant)
	end
	root.DescendantAdded:Connect(function(descendant)
		offer(descendant)
	end)
end

function LiveLooks.track(attribute: string, add: (Instance) -> ())
	local tracker = { Attribute = attribute, Add = add }
	table.insert(trackers, tracker)
	-- (Copies watched before this animator started.)
	for root in roots do
		offer(root, tracker)
		for _, descendant in root:GetDescendants() do
			offer(descendant, tracker)
		end
	end
end

-- A copy made outside the game and placed later (the lottery's reward art)
-- isn't gone until it has been in the game and left it.
function LiveLooks.follow(instance: Instance, moved: () -> (), gone: () -> ()): RBXScriptConnection
	local entered = instance:IsDescendantOf(game)
	return instance.AncestryChanged:Connect(function()
		if instance:IsDescendantOf(game) then
			entered = true
			moved()
		elseif entered then
			gone()
		else
			moved() -- (still being put together: wherever it is, it's Away)
		end
	end)
end

function LiveLooks.viewOf(instance: Instance): ViewportFrame?
	return instance:FindFirstAncestorWhichIsA("ViewportFrame") :: ViewportFrame?
end

function LiveLooks.place(instance: Instance): "View" | "Camera" | "World" | "Away"
	if LiveLooks.viewOf(instance) then
		return "View"
	end
	local camera = workspace.CurrentCamera
	if camera and instance:IsDescendantOf(camera) then
		return "Camera"
	end
	return if instance:IsDescendantOf(workspace) then "World" else "Away"
end

function LiveLooks.onScreen(view: Instance): boolean
	local node: Instance? = view
	while node do
		if node:IsA("LayerCollector") then
			return (node :: any).Enabled == true
		elseif node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return false -- (not under any ScreenGui: not drawn)
end

return LiveLooks
