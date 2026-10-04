--[[
	Elements against armor. The element of the gem in a fighter's armor (the
	chest piece) decides how elements hit them:

	  Resist  the armor's own element does 75%
	  Weak    the element that beats it does 125%
	          Thermal beats Cryo, Cryo beats Ion, Ion beats Corrosive,
	          Corrosive beats Thermal

	The same rules for players, rival miners and dungeon creatures (whose
	element and weakness come from their roster entry). Pure, for tests.

	  ElementMatchup.multiplier(attack, armor) -> number, "Resist" | "Weak" | nil
	  ElementMatchup.versus(attack, armorElement, weakness?) same, with an
	      explicit weakness (dungeon creatures)
	  ElementMatchup.weakTo(armor) -> the element that beats it
]]
local ElementMatchup = {}

ElementMatchup.Resist = 0.75
ElementMatchup.Weak = 1.25
ElementMatchup.Beats = { Fire = "Frost", Frost = "Shock", Shock = "Poison", Poison = "Fire" }

function ElementMatchup.weakTo(armor: string?): string?
	for attack, victim in ElementMatchup.Beats do
		if victim == armor then
			return attack
		end
	end
	return nil
end

function ElementMatchup.versus(attack: string?, armor: string?, weakness: string?): (number, string?)
	if not attack or not armor then
		return 1, nil
	end
	if attack == (weakness or ElementMatchup.weakTo(armor)) then
		return ElementMatchup.Weak, "Weak"
	end
	if attack == armor then
		return ElementMatchup.Resist, "Resist"
	end
	return 1, nil
end

function ElementMatchup.multiplier(attack: string?, armor: string?): (number, string?)
	return ElementMatchup.versus(attack, armor, nil)
end

return ElementMatchup
