--[[
	Element combos: one effect sets up another. The same rules apply to
	everyone (players and the rival), on weapon blows, maneuvers and surges.

	  Shatter       a heavy blow on a Frozen target: +60% damage, and the
	                ice breaks (the freeze ends)
	  Combustion    Fire damage on a target with its armor shredded
	                (Poison): +35% damage
	  Superconduct  Shock damage on a Slowed target (Frost, Armor Melt):
	                a 0.6s stun

	  ElementCombos.check(hit, target)  pure: the combo a hit sets off, or nil
	    hit     { Element = "Fire" | ..., Heavy = boolean }
	    target  { Frozen = boolean, Shredded = boolean, Slowed = boolean }
	    returns id, { Mult = number?, EndFreeze = boolean?, Stun = number? }
]]
local ElementCombos = {}

ElementCombos.List = {
	Shatter = {
		Name = "Shatter",
		Text = "SHATTER!",
		Color = Color3.fromRGB(150, 210, 255),
		Mult = 1.6,
		EndFreeze = true,
	},
	Combustion = {
		Name = "Combustion",
		Text = "COMBUSTION!",
		Color = Color3.fromRGB(255, 140, 60),
		Mult = 1.35,
	},
	Superconduct = {
		Name = "Superconduct",
		Text = "SUPERCONDUCT!",
		Color = Color3.fromRGB(255, 225, 90),
		Stun = 0.6,
	},
}

function ElementCombos.check(hit, target)
	if not hit or not target then
		return nil, nil
	end
	local id = if hit.Heavy and target.Frozen
		then "Shatter"
		elseif hit.Element == "Fire" and target.Shredded then "Combustion"
		elseif hit.Element == "Shock" and target.Slowed then "Superconduct"
		else nil
	return id, if id then ElementCombos.List[id] else nil
end

return ElementCombos
