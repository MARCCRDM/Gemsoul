--[[
	Your pod's style (Server.PodServer builds it; MY POD, Client.PodUI, picks
	it; saved on the profile as Pod) and the pod pieces you own (PodOwned):
	the hull's colour, its glow (beacon, trim, name), the kaiju on the
	showcase pedestal in its front yard, and what stands in the yard's two
	front corners.

	Every piece has a rarity, Common to Legendary. A few are yours from the
	start (Free); the rest come from the pod roll: each time your pod lands
	it rolls one (PodStyle.roll: a rarity by Weight, then a piece of it you
	don't have yet if there is one), unlocks it and wears it, flickering
	through the others on the way down (Client.PodArrival shows the roll).

	  PodStyle.Hulls, .Glows, .Decor   { { Id, Name, Rarity, Color?, Material? } }
	  PodStyle.Rarities                { { Id, Name, Weight, Color } }, commonest first
	  PodStyle.Slots                   the yard's spots, in the pad's frame
	  PodStyle.default() -> style
	  PodStyle.owns(owned, kind, id) -> bool   kind "Hull" | "Glow" | "Decor"
	  PodStyle.clean(style, ownsKaiju?, owned?) -> style   only what's real and
	                                   yours (with no `owned`, nothing's checked)
	  PodStyle.roll(owned, rng) -> { Kind, Id, Rarity, Name, New }
	  PodStyle.equip(style, piece) -> style   wearing it (decor: the left spot)
	  PodStyle.find(kind, id) -> entry?
	  PodStyle.hull(style) / .glow(style) -> Color3;  .hullMaterial(style) -> string
]]
local PodStyle = {}

PodStyle.Rarities = {
	{ Id = "Common", Name = "COMMON", Weight = 55, Color = Color3.fromRGB(200, 204, 212) },
	{ Id = "Uncommon", Name = "UNCOMMON", Weight = 25, Color = Color3.fromRGB(110, 230, 130) },
	{ Id = "Rare", Name = "RARE", Weight = 12, Color = Color3.fromRGB(90, 170, 255) },
	{ Id = "Epic", Name = "EPIC", Weight = 6, Color = Color3.fromRGB(190, 110, 255) },
	{ Id = "Legendary", Name = "LEGENDARY", Weight = 2, Color = Color3.fromRGB(255, 190, 60) },
}

PodStyle.Hulls = {
	{ Id = "Frost", Name = "FROST WHITE", Rarity = "Common", Color = Color3.fromRGB(226, 228, 232) },
	{ Id = "Graphite", Name = "GRAPHITE", Rarity = "Common", Color = Color3.fromRGB(70, 74, 86) },
	{ Id = "Sand", Name = "DUNE SAND", Rarity = "Common", Color = Color3.fromRGB(214, 190, 150) },
	{ Id = "Moss", Name = "MOSS", Rarity = "Uncommon", Color = Color3.fromRGB(86, 116, 78) },
	{ Id = "Navy", Name = "DEEP NAVY", Rarity = "Uncommon", Color = Color3.fromRGB(44, 62, 112) },
	{ Id = "Crimson", Name = "CRIMSON", Rarity = "Rare", Color = Color3.fromRGB(176, 52, 60) },
	{ Id = "Chrome", Name = "CHROME", Rarity = "Epic", Color = Color3.fromRGB(196, 204, 216), Material = "Metal" },
	{ Id = "Gilded", Name = "GILDED", Rarity = "Legendary", Color = Color3.fromRGB(255, 192, 72), Material = "Metal" },
}
PodStyle.Glows = {
	{ Id = "Cyan", Name = "CYAN", Rarity = "Common", Color = Color3.fromRGB(110, 220, 255) },
	{ Id = "Gold", Name = "GOLD", Rarity = "Common", Color = Color3.fromRGB(255, 196, 80) },
	{ Id = "Lime", Name = "LIME", Rarity = "Uncommon", Color = Color3.fromRGB(150, 255, 120) },
	{ Id = "Magenta", Name = "MAGENTA", Rarity = "Uncommon", Color = Color3.fromRGB(255, 110, 210) },
	{ Id = "Violet", Name = "VIOLET", Rarity = "Rare", Color = Color3.fromRGB(180, 130, 255) },
	{ Id = "Ember", Name = "EMBER", Rarity = "Epic", Color = Color3.fromRGB(255, 120, 70) },
	-- (its colour runs round the rainbow: Client.PodShowcase)
	{ Id = "Prism", Name = "PRISM", Rarity = "Legendary", Color = Color3.fromRGB(255, 255, 255), Prism = true },
}
PodStyle.Decor = {
	{ Id = "None", Name = "NOTHING", Rarity = "Common" },
	{ Id = "Lamps", Name = "TWIN LAMPS", Rarity = "Common" },
	{ Id = "Crates", Name = "SUPPLY CRATES", Rarity = "Common" },
	{ Id = "Planter", Name = "CRYSTAL PLANTER", Rarity = "Uncommon" },
	{ Id = "Flag", Name = "BANNER", Rarity = "Uncommon" },
	{ Id = "Scope", Name = "TELESCOPE", Rarity = "Rare" },
	{ Id = "Drill", Name = "MINI DRILL", Rarity = "Rare" },
	{ Id = "Spire", Name = "CRYSTAL SPIRE", Rarity = "Epic" },
	{ Id = "Statue", Name = "GOLDEN KAIJU", Rarity = "Legendary" },
}
-- Yours from the start.
PodStyle.Free = { Hull = { Frost = true }, Glow = { Cyan = true }, Decor = { None = true, Lamps = true, Crates = true } }
-- The yard (on the pad, in front of and beside the pod): the showcase's
-- pedestal by the pod's left side, a decor spot each side of the stair.
PodStyle.Slots = {
	Showcase = { X = -9.2, Z = -1.5 },
	Left = { X = -6.4, Z = -9.6 },
	Right = { X = 6.4, Z = -9.6 },
}

local LISTS = { Hull = PodStyle.Hulls, Glow = PodStyle.Glows, Decor = PodStyle.Decor }

function PodStyle.find(kind: string, id: any)
	for _, entry in LISTS[kind] or {} do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

function PodStyle.default()
	return { Hull = "Frost", Glow = "Cyan", Left = "Lamps", Right = "Crates", Showcase = nil }
end

function PodStyle.owns(owned: any, kind: string, id: any): boolean
	if PodStyle.Free[kind] and PodStyle.Free[kind][id] then
		return true
	end
	return type(owned) == "table" and owned[kind .. ":" .. tostring(id)] == true
end

function PodStyle.clean(style: any, ownsKaiju: ((string) -> boolean)?, owned: any?)
	local out = PodStyle.default()
	if type(style) ~= "table" then
		return out
	end
	local function ok(kind, id)
		return PodStyle.find(kind, id) ~= nil and (owned == nil or PodStyle.owns(owned, kind, id))
	end
	if ok("Hull", style.Hull) then
		out.Hull = style.Hull
	end
	if ok("Glow", style.Glow) then
		out.Glow = style.Glow
	end
	for _, slot in { "Left", "Right" } do
		if ok("Decor", style[slot]) then
			out[slot] = style[slot]
		end
	end
	if type(style.Showcase) == "string" and ownsKaiju and ownsKaiju(style.Showcase) then
		out.Showcase = style.Showcase
	end
	return out
end

-- The pod roll: a rarity by weight, then a piece of it (not "None"), one you
-- don't own yet if there's one.
function PodStyle.roll(owned: any, rng: any)
	local total = 0
	for _, r in PodStyle.Rarities do
		total += r.Weight
	end
	local at = rng:NextNumber(0, total)
	local rarity = PodStyle.Rarities[1].Id
	for _, r in PodStyle.Rarities do
		at -= r.Weight
		if at <= 0 then
			rarity = r.Id
			break
		end
	end
	local fresh, any = {}, {}
	for _, kind in { "Hull", "Glow", "Decor" } do
		for _, entry in LISTS[kind] do
			if entry.Rarity == rarity and entry.Id ~= "None" then
				local piece = { Kind = kind, Id = entry.Id, Rarity = rarity, Name = entry.Name }
				table.insert(any, piece)
				if not PodStyle.owns(owned, kind, entry.Id) then
					table.insert(fresh, piece)
				end
			end
		end
	end
	local pool = if #fresh > 0 then fresh else any
	local piece = pool[rng:NextInteger(1, #pool)]
	piece.New = #fresh > 0
	return piece
end

function PodStyle.equip(style: any, piece: any)
	local out = table.clone(if type(style) == "table" then style else PodStyle.default())
	if piece.Kind == "Hull" then
		out.Hull = piece.Id
	elseif piece.Kind == "Glow" then
		out.Glow = piece.Id
	elseif piece.Kind == "Decor" then
		out.Left = piece.Id
	end
	return out
end

function PodStyle.hull(style): Color3
	return (PodStyle.find("Hull", style and style.Hull) or PodStyle.Hulls[1]).Color
end
function PodStyle.hullMaterial(style): string
	return (PodStyle.find("Hull", style and style.Hull) or PodStyle.Hulls[1]).Material or "SmoothPlastic"
end
function PodStyle.glow(style): Color3
	return (PodStyle.find("Glow", style and style.Glow) or PodStyle.Glows[1]).Color
end
function PodStyle.rarity(id: string)
	for _, r in PodStyle.Rarities do
		if r.Id == id then
			return r
		end
	end
	return PodStyle.Rarities[1]
end

return PodStyle
