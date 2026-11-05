--[[
	Your pod's style (Server.PodServer builds it; MY POD, Client.PodUI, picks
	it; saved on the profile as Pod): the hull's colour, its glow (beacon,
	trim, name), the kaiju on the showcase pedestal in its front yard, and
	what stands in the yard's two front corners.

	  PodStyle.Hulls, PodStyle.Glows   { { Id, Name, Color } }
	  PodStyle.Decor                   { { Id, Name } } ("None" leaves it bare)
	  PodStyle.Slots                   the yard's spots, in the pad's frame
	                                   (x right, z out toward the Heart)
	  PodStyle.default() -> style
	  PodStyle.clean(style, owns) -> style   a style with only what's real:
	                                   known colours and decor, a showcase
	                                   kaiju only one `owns(id)` says is yours
	  PodStyle.hull(style) / PodStyle.glow(style) -> Color3
]]
local PodStyle = {}

PodStyle.Hulls = {
	{ Id = "Frost", Name = "FROST WHITE", Color = Color3.fromRGB(226, 228, 232) },
	{ Id = "Graphite", Name = "GRAPHITE", Color = Color3.fromRGB(70, 74, 86) },
	{ Id = "Sand", Name = "DUNE SAND", Color = Color3.fromRGB(214, 190, 150) },
	{ Id = "Crimson", Name = "CRIMSON", Color = Color3.fromRGB(176, 52, 60) },
	{ Id = "Navy", Name = "DEEP NAVY", Color = Color3.fromRGB(44, 62, 112) },
	{ Id = "Moss", Name = "MOSS", Color = Color3.fromRGB(86, 116, 78) },
}
PodStyle.Glows = {
	{ Id = "Cyan", Name = "CYAN", Color = Color3.fromRGB(110, 220, 255) },
	{ Id = "Gold", Name = "GOLD", Color = Color3.fromRGB(255, 196, 80) },
	{ Id = "Magenta", Name = "MAGENTA", Color = Color3.fromRGB(255, 110, 210) },
	{ Id = "Lime", Name = "LIME", Color = Color3.fromRGB(150, 255, 120) },
	{ Id = "Violet", Name = "VIOLET", Color = Color3.fromRGB(180, 130, 255) },
	{ Id = "Ember", Name = "EMBER", Color = Color3.fromRGB(255, 120, 70) },
}
PodStyle.Decor = {
	{ Id = "None", Name = "NOTHING" },
	{ Id = "Lamps", Name = "TWIN LAMPS" },
	{ Id = "Planter", Name = "CRYSTAL PLANTER" },
	{ Id = "Flag", Name = "BANNER" },
	{ Id = "Crates", Name = "SUPPLY CRATES" },
	{ Id = "Drill", Name = "MINI DRILL" },
	{ Id = "Scope", Name = "TELESCOPE" },
}
-- The yard (on the pad, in front of and beside the pod): the showcase's
-- pedestal by the pod's left side, a decor spot each side of the stair.
PodStyle.Slots = {
	Showcase = { X = -9.2, Z = -1.5 },
	Left = { X = -6.4, Z = -9.6 },
	Right = { X = 6.4, Z = -9.6 },
}

local function find(list, id)
	for _, entry in list do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

function PodStyle.default()
	return { Hull = "Frost", Glow = "Cyan", Left = "Lamps", Right = "Planter", Showcase = nil }
end

function PodStyle.clean(style: any, owns: ((string) -> boolean)?)
	local out = PodStyle.default()
	if type(style) ~= "table" then
		return out
	end
	if find(PodStyle.Hulls, style.Hull) then
		out.Hull = style.Hull
	end
	if find(PodStyle.Glows, style.Glow) then
		out.Glow = style.Glow
	end
	for _, slot in { "Left", "Right" } do
		if find(PodStyle.Decor, style[slot]) then
			out[slot] = style[slot]
		end
	end
	if type(style.Showcase) == "string" and owns and owns(style.Showcase) then
		out.Showcase = style.Showcase
	end
	return out
end

function PodStyle.hull(style): Color3
	local entry = find(PodStyle.Hulls, style and style.Hull) or PodStyle.Hulls[1]
	return entry.Color
end

function PodStyle.glow(style): Color3
	local entry = find(PodStyle.Glows, style and style.Glow) or PodStyle.Glows[1]
	return entry.Color
end

return PodStyle
