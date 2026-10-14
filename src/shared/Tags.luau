-- CollectionService tags placed by the world builder. Gameplay systems find
-- their parts through these tags instead of hard-coded paths.
return {
	-- Mining
	NodeSpawner = "NodeSpawner",
	QuotaTerminal = "QuotaTerminal",
	VipGate = "VipGate",

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
	-- A skin's seam and edge outlines (SelectionBoxes): Roblox draws those even
	-- round a hidden part, so the client shows each only while its part shows
	-- (SeamVisibility).
	SkinSeam = "SkinSeam",
}
