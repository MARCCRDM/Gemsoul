-- CollectionService tags placed by the world builder. Gameplay systems find
-- their parts through these tags instead of hard-coded paths.
return {
	-- Mining
	NodeSpawner = "NodeSpawner",
	QuotaTerminal = "QuotaTerminal",
	VipGate = "VipGate",
	-- The DEV desk's gate in the Shelter: solid for all but the Owners.
	DevGate = "DevGate",

	-- Marketplace
	TradeKiosk = "TradeKiosk",
	TradeBoard = "TradeBoard",

	-- Shopkeepers (models; the torso carries a VendorId attribute)
	Vendor = "Vendor",

	-- Visual effects (animated on each client)
	Flicker = "Flicker",
	ArcaneRune = "ArcaneRune",
	ContainmentField = "ContainmentField",
	Spin = "Spin",
	Bob = "Bob",
	Laser = "Laser",

	-- Gem outlines on enchanted gear (Highlights): the client keeps only the
	-- nearest ones on, under Roblox's limit (OutlineBudget).
	GemOutline = "GemOutline",
	-- Coloured plates of a Prismatic roll: their hue shimmers on every client.
	Prismatic = "Prismatic",
	-- A skin's seams and edges (neon strips, or SelectionBoxes on older
	-- gear): animated on every client, and a box shown only while its part
	-- shows (SeamVisibility).
	SkinSeam = "SkinSeam",
	-- The Thunderclap pickaxe's live parts (ThunderArc "Core" or "Tip") and
	-- the Stormcaller Wings' ("WingCore", "Wing"): arcs crackle between them
	-- on every client (ThunderArcs).
	ThunderArc = "ThunderArc",
	-- A socketed stone's light (PointLight): it breathes its element's way
	-- on every client (GemLights), from its PulseBase, PulsePeriod and
	-- PulseDim attributes.
	GemGlow = "GemGlow",
}
