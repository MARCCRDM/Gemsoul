local count = 0
local function check(value, message)
	assert(value, message)
	count += 1
end
for element, ids in GemRoller.PrototypeIds do
	for index, id in ids do
		local gem = {Element=element, Surge=id, SurgeTier=1, SurgeRank=1, Size=1, Clarity=1, Cut=1}
		check(Tech.canSocket(gem, "Q", {}) == (index ~= 3), id .. " Q role")
		check(Tech.canSocket(gem, "E", {}) == (index ~= 3), id .. " E role")
		check(Tech.canSocket(gem, "R", {}) == (index == 3), id .. " R role")
		check(not Tech.canSocket(gem, "invalid", {}), "invalid slot")
		check(not Tech.canSocket(gem, "Q", {Surge2Gem=gem}), "duplicate or Shift rejected")
		local definition = Tech.surgeStats(gem)
		check(Atlas.Index[Icons.idOf(definition)] ~= nil, id .. " painted icon")
		check(Atlas.Index[Icons.idOf(id)] ~= nil, id .. " icon by ID")
		if index == 3 then
			local rare = table.clone(gem)
			rare.SurgeRank, rare.Size, rare.Clarity, rare.Cut = 3, 10, 10, 10
			local upgraded = Tech.surgeStats(rare)
			for _, field in {"Distance", "MoveTime", "Cooldown", "Recovery"} do
				check(upgraded[field] == definition[field], id .. " fixed " .. field)
			end
			check(upgraded.Cost <= definition.Cost, "Shift cost progression")
		end
	end
end
check(Tech.surgeGem({}, "R").Surge == "DefaultShift", "neutral fallback")
check(Tech.surgeGem({}, "Q") == nil, "no free attack")
local saved = {Surge="ThermalBurst", Element="Fire", Cut=5}
local mapped = Tech.prototypeGem(saved, "R")
check(mapped.Surge == "FurnaceRush", "legacy Shift projection")
check(saved.Surge == "ThermalBurst", "saved gem preserved")
check(ElementCombos.check({Element="Fire"}, {Shredded=true}) == nil, "prototype reactions disabled")
print("PASS: " .. count .. " prototype role, legacy, icon and Shift scaling checks")
