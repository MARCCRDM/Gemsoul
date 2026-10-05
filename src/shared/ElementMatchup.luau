--[[
	Elements against armor. Every gem in an armor piece (helmet, chest suit,
	gloves, boots, shield) resists its own element, more for a finer gem:

	  per gem   3.5% (grades all 1) up to 8% (grades all 10) of that
	            element's damage, by the gem's average grade
	  total     capped at 35% per element

	Your main armor element (the one your gems resist most) is weak to the
	element that beats it: that element does 125%. Thermal beats Cryo, Cryo
	beats Ion, Ion beats Corrosive, Corrosive beats Thermal. Resisting the
	element you're weak to softens it.

	Dungeon creatures keep a fixed element and weakness (versus: 75% / 125%).
	Pure, for tests.

	  ElementMatchup.gemResist(gem) -> share of its element a gem resists
	  ElementMatchup.profile(loadout) -> { Resist = { [element]: share }, Main = element? }
	  ElementMatchup.against(attack, profile) -> number, "Resist" | "Weak" | nil
	  ElementMatchup.versus(attack, element, weakness?) -> number, tag (creatures)
	  ElementMatchup.weakTo(element) -> the element that beats it
]]
local ElementMatchup = {}

ElementMatchup.Resist = 0.75 -- a creature against its own element
ElementMatchup.Weak = 1.25
ElementMatchup.PerGem = { Min = 0.035, Max = 0.08 }
ElementMatchup.Cap = 0.35
ElementMatchup.Slots = { "Helmet", "Armor", "Gloves", "Boots", "Shield" }
ElementMatchup.Beats = { Fire = "Frost", Frost = "Shock", Shock = "Poison", Poison = "Fire" }

function ElementMatchup.weakTo(element: string?): string?
	for attack, victim in ElementMatchup.Beats do
		if victim == element then
			return attack
		end
	end
	return nil
end

-- A gem's average grade (1-10; a rough gem's missing Cut doesn't count).
local function grade(gem): number
	local total, count = 0, 0
	for _, metric in { "Size", "Clarity", "Cut" } do
		if type(gem[metric]) == "number" then
			total += gem[metric]
			count += 1
		end
	end
	return if count > 0 then math.clamp(total / count, 1, 10) else 1
end

function ElementMatchup.gemResist(gem): number
	if not gem or not gem.Element then
		return 0
	end
	local span = ElementMatchup.PerGem
	return span.Min + (span.Max - span.Min) * (grade(gem) - 1) / 9
end

function ElementMatchup.profile(loadout)
	local resist, main, best = {}, nil, 0
	if loadout then
		for _, slot in ElementMatchup.Slots do
			local gem = loadout[slot .. "Gem"]
			if gem and gem.Element then
				resist[gem.Element] = (resist[gem.Element] or 0) + ElementMatchup.gemResist(gem)
			end
		end
		-- The main element: resisted most (the chest suit's breaks a tie).
		local chest = loadout.ArmorGem and loadout.ArmorGem.Element
		for element, share in resist do
			if share > best + 1e-9 or (math.abs(share - best) <= 1e-9 and element == chest) then
				main, best = element, share
			end
		end
		for element, share in resist do
			resist[element] = math.min(share, ElementMatchup.Cap)
		end
	end
	return { Resist = resist, Main = main }
end

local function tagOf(mult: number): string?
	return if mult < 0.999 then "Resist" elseif mult > 1.001 then "Weak" else nil
end

function ElementMatchup.against(attack: string?, profile): (number, string?)
	if not attack or not profile then
		return 1, nil
	end
	local mult = 1 - (profile.Resist[attack] or 0)
	if profile.Main and attack == ElementMatchup.weakTo(profile.Main) then
		mult *= ElementMatchup.Weak
	end
	return mult, tagOf(mult)
end

function ElementMatchup.versus(attack: string?, element: string?, weakness: string?): (number, string?)
	if not attack or not element then
		return 1, nil
	end
	if attack == (weakness or ElementMatchup.weakTo(element)) then
		return ElementMatchup.Weak, "Weak"
	end
	if attack == element then
		return ElementMatchup.Resist, "Resist"
	end
	return 1, nil
end

return ElementMatchup
