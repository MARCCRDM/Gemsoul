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
}
