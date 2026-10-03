--[[
	The combat log: every hit, block, absorb, dodge, heal and kill is sent to
	the players involved as a CombatFx "Log" event, for the HUD's combat log
	and its fight details.

	Damage code doesn't know which ability it belongs to, so whoever starts
	an ability sets the context first:

	  local previous = DamageLog.push("Heavy Blow", "Fire")
	  ... deal damage ...
	  DamageLog.pop(previous)

	An entry:
	  Dir       "Out" (you to them), "In" (them to you), "Foe" (they did it
	            to themselves, e.g. a heal)
	  Kind      "Hit", "Dodge", "Heal", "Kill", "Death"
	  Who       the other fighter's name
	  Ability   e.g. "Swing", "Solar Flare", "Burning"
	  Element   "Fire", "Frost", "Shock", "Poison" or nil
	  Amount    damage or healing that landed
	  Crit, Blocked, Absorbed, Parried, GuardBroken
]]
local Remotes = require(script.Parent.Remotes)

local DamageLog = {}

local current: { Ability: string?, Element: string? }? = nil

function DamageLog.push(ability: string?, element: string?)
	local previous = current
	current = { Ability = ability, Element = element }
	return previous
end

function DamageLog.pop(previous)
	current = previous
end

-- The ability (and its element) dealing damage right now, if any.
function DamageLog.context(): (string?, string?)
	if current then
		return current.Ability, current.Element
	end
	return nil, nil
end

local function round(value: number?): number?
	return if value then math.floor(value + 0.5) else nil
end

local function isPlayer(fighter: any): boolean
	if typeof(fighter) == "Instance" then
		return fighter:IsA("Player")
	end
	-- Test doubles: a table that looks like a player.
	return type(fighter) == "table" and fighter.UserId ~= nil and fighter.Model == nil
end

function DamageLog.send(player: any, entry)
	if not isPlayer(player) then
		return
	end
	local ability, element = DamageLog.context()
	entry.Ability = entry.Ability or ability
	entry.Element = entry.Element or element
	entry.Amount = round(entry.Amount)
	entry.Blocked = if entry.Blocked and entry.Blocked >= 0.5 then round(entry.Blocked) else nil
	entry.Absorbed = if entry.Absorbed and entry.Absorbed >= 0.5 then round(entry.Absorbed) else nil
	Remotes.CombatFx:FireClient(player, "Log", entry)
end

-- A display name for a player or an enemy.
function DamageLog.nameOf(fighter: any): string?
	if isPlayer(fighter) then
		return fighter.DisplayName or fighter.Name
	elseif type(fighter) == "table" and fighter.Model then
		return fighter.Model:GetAttribute("RivalName") or (fighter.Kind and fighter.Kind.Name) or fighter.Model.Name
	end
	return nil
end

return DamageLog
