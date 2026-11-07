--[[
	Your pod's style (Server.PodServer builds it; MY POD, Client.PodUI, picks
	it; saved on the profile as Pod) and the pod pieces you own (PodOwned):
	the hull's colour, its glow (beacon, trim, name), the kaiju on the
	showcase pedestal in its front yard, and what stands in the yard's two
	front corners.

	Every piece has a rarity, Common to Legendary. A few are yours from the
	start (Free); the rest come from the pod roll: your pod's first landing
	rolls one (PodStyle.roll: a rarity by Weight, then a piece of it you
	don't have yet if there is one), unlocks it and wears it, flickering
	through the others on the way down (Client.PodArrival shows the roll).

	  PodStyle.Hulls, .Glows, .Decor   { { Id, Name, Rarity, Blurb, Color?, Roof?, Frame?, Material? } }
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
	  PodStyle.roof(style) / .frame(style) -> Color3?   nil: the hull's own / the default frame
]]
local PodStyle = {}

PodStyle.Rarities = {
	{ Id = "Common", Name = "COMMON", Weight = 55, Color = Color3.fromRGB(200, 204, 212) },
	{ Id = "Uncommon", Name = "UNCOMMON", Weight = 25, Color = Color3.fromRGB(110, 230, 130) },
	{ Id = "Rare", Name = "RARE", Weight = 12, Color = Color3.fromRGB(90, 170, 255) },
	{ Id = "Epic", Name = "EPIC", Weight = 6, Color = Color3.fromRGB(190, 110, 255) },
	{ Id = "Legendary", Name = "LEGENDARY", Weight = 2, Color = Color3.fromRGB(255, 190, 60) },
}

-- (Roof: the roof's colour if not the hull's; Frame: the dark frame's, end
-- panels, band and legs; Material: the hull's finish. Blurb: what MY POD
-- says about it.)
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
PodStyle.Hulls = {
	{ Id = "Frost", Name = "FROST WHITE", Rarity = "Common", Color = rgb(226, 228, 232), Blurb = "Factory white, straight off the line." },
	{ Id = "Graphite", Name = "GRAPHITE", Rarity = "Common", Color = rgb(70, 74, 86), Blurb = "Dark grey. Hides the crater dust." },
	{ Id = "Sand", Name = "DUNE SAND", Rarity = "Common", Color = rgb(214, 190, 150), Blurb = "The colour of the quarry floor." },
	{ Id = "Sky", Name = "SKY", Rarity = "Common", Color = rgb(150, 190, 225), Blurb = "Pale blue, like the day sky." },
	{ Id = "Moss", Name = "MOSS", Rarity = "Uncommon", Color = rgb(86, 116, 78), Blurb = "Field green, built for the wilds." },
	{ Id = "Navy", Name = "DEEP NAVY", Rarity = "Uncommon", Color = rgb(44, 62, 112), Blurb = "Deep blue, night-shift paint." },
	{ Id = "Arctic", Name = "ARCTIC", Rarity = "Uncommon", Color = rgb(232, 238, 244), Roof = rgb(84, 184, 228), Blurb = "White hull under an ice-blue roof." },
	{ Id = "Rust", Name = "RUST", Rarity = "Uncommon", Color = rgb(150, 84, 54), Material = "CorrodedMetal", Blurb = "Weathered plate. Seen some storms." },
	{ Id = "Crimson", Name = "CRIMSON", Rarity = "Rare", Color = rgb(176, 52, 60), Blurb = "Deep red, impossible to miss." },
	{ Id = "Racer", Name = "RACER", Rarity = "Rare", Color = rgb(236, 238, 242), Roof = rgb(204, 38, 48), Frame = rgb(22, 22, 26), Blurb = "Race livery: white, a red roof, a black frame." },
	{ Id = "Plate", Name = "TREAD PLATE", Rarity = "Rare", Color = rgb(150, 156, 166), Material = "DiamondPlate", Frame = rgb(30, 32, 38), Blurb = "Tread plate all over. Built to take hits." },
	{ Id = "Midnight", Name = "MIDNIGHT", Rarity = "Rare", Color = rgb(26, 32, 66), Frame = rgb(226, 178, 72), Blurb = "Midnight blue in a gold frame." },
	{ Id = "Chrome", Name = "CHROME", Rarity = "Epic", Color = rgb(196, 204, 216), Material = "Metal", Blurb = "Polished to a mirror." },
	{ Id = "Foil", Name = "COBALT FOIL", Rarity = "Epic", Color = rgb(58, 108, 232), Material = "Foil", Blurb = "Crinkled cobalt foil, like a probe's." },
	{ Id = "Magma", Name = "MAGMA", Rarity = "Epic", Color = rgb(90, 40, 28), Material = "CrackedLava", Frame = rgb(24, 20, 20), Blurb = "Lava glowing through cracked rock." },
	{ Id = "Glacier", Name = "GLACIER", Rarity = "Epic", Color = rgb(176, 222, 248), Material = "Ice", Roof = rgb(232, 246, 255), Blurb = "A hull of solid glacier ice." },
	{ Id = "Gilded", Name = "GILDED", Rarity = "Legendary", Color = rgb(255, 192, 72), Material = "Metal", Blurb = "Solid gold. For the very best miners." },
	{ Id = "Obsidian", Name = "OBSIDIAN", Rarity = "Legendary", Color = rgb(20, 20, 26), Roof = rgb(255, 192, 72), Frame = rgb(255, 192, 72), Blurb = "Volcanic black, crowned and framed in gold." },
}
PodStyle.Glows = {
	{ Id = "Cyan", Name = "CYAN", Rarity = "Common", Color = rgb(110, 220, 255), Blurb = "The Outpost's own blue." },
	{ Id = "Gold", Name = "GOLD", Rarity = "Common", Color = rgb(255, 196, 80), Blurb = "Warm lamp gold." },
	{ Id = "White", Name = "WHITE", Rarity = "Common", Color = rgb(236, 242, 255), Blurb = "Plain white light." },
	{ Id = "Lime", Name = "LIME", Rarity = "Uncommon", Color = rgb(150, 255, 120), Blurb = "Bright lime green." },
	{ Id = "Magenta", Name = "MAGENTA", Rarity = "Uncommon", Color = rgb(255, 110, 210), Blurb = "Hot pink-purple." },
	{ Id = "Coral", Name = "CORAL", Rarity = "Uncommon", Color = rgb(255, 128, 104), Blurb = "Soft coral orange." },
	{ Id = "Violet", Name = "VIOLET", Rarity = "Rare", Color = rgb(180, 130, 255), Blurb = "Rift violet." },
	{ Id = "Teal", Name = "TEAL", Rarity = "Rare", Color = rgb(60, 232, 190), Blurb = "Deep sea teal." },
	{ Id = "Rose", Name = "ROSE", Rarity = "Rare", Color = rgb(255, 84, 140), Blurb = "A sharp rose red." },
	{ Id = "Ember", Name = "EMBER", Rarity = "Epic", Color = rgb(255, 120, 70), Blurb = "Like coals in a forge." },
	{ Id = "Toxic", Name = "TOXIC", Rarity = "Epic", Color = rgb(186, 255, 40), Blurb = "Corrosive green. Don't touch." },
	-- (its colour runs round the rainbow: Client.PodShowcase)
	{ Id = "Prism", Name = "PRISM", Rarity = "Legendary", Color = rgb(255, 255, 255), Prism = true, Blurb = "Runs round the whole rainbow." },
}
PodStyle.Decor = {
	{ Id = "None", Name = "NOTHING", Rarity = "Common", Blurb = "Leave the spot clear." },
	{ Id = "Lamps", Name = "TWIN LAMPS", Rarity = "Common", Blurb = "Two lamps in your glow." },
	{ Id = "Crates", Name = "SUPPLY CRATES", Rarity = "Common", Blurb = "Crates and a drum, fresh off the shuttle." },
	{ Id = "Bench", Name = "BENCH", Rarity = "Common", Blurb = "Somewhere to sit and watch the duels." },
	{ Id = "Planter", Name = "CRYSTAL PLANTER", Rarity = "Uncommon", Blurb = "Crystals growing in a box." },
	{ Id = "Flag", Name = "BANNER", Rarity = "Uncommon", Blurb = "A banner in your glow." },
	{ Id = "Dish", Name = "SAT DISH", Rarity = "Uncommon", Blurb = "Listening to orbit." },
	{ Id = "Scope", Name = "TELESCOPE", Rarity = "Rare", Blurb = "For watching the sky." },
	{ Id = "Drill", Name = "MINI DRILL", Rarity = "Rare", Blurb = "A drill rig for the yard." },
	{ Id = "Cart", Name = "GEM CART", Rarity = "Rare", Blurb = "A mine cart heaped with gems." },
	{ Id = "Spire", Name = "CRYSTAL SPIRE", Rarity = "Epic", Blurb = "A tall crystal, lit from inside." },
	{ Id = "Holo", Name = "HOLO SIGN", Rarity = "Epic", Blurb = "A hologram panel in your glow." },
	{ Id = "Statue", Name = "GOLDEN KAIJU", Rarity = "Legendary", Blurb = "A golden kaiju rearing up." },
	{ Id = "Meteor", Name = "METEORITE", Rarity = "Legendary", Blurb = "A fallen star, still glowing." },
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
function PodStyle.roof(style): Color3?
	local entry = PodStyle.find("Hull", style and style.Hull)
	return entry and entry.Roof
end
function PodStyle.frame(style): Color3?
	local entry = PodStyle.find("Hull", style and style.Hull)
	return entry and entry.Frame
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
