--[[
	The names and health bars over creatures in the Outpost, kept out of the
	way (KaijuHud applies them every few frames):

	  Mine     your own kaiju: no name (the team strip has them), and the
	           slim bar only while one's hurt
	  Other    another player's kaiju: its name and bar; on a phone only
	           from close by
	  Wild     a wild kaiju, and
	  Critter  a rift's critter: name and bar while you're not hunting (the
	           fight's own bars take over then: FoeBars); on a phone only
	           from closer, smaller

	Before this every plate showed at full size from far off (a wild one's
	from 160 studs, drawn over everything), so on a phone a few of them
	piled up over the middle of the screen.

	  Nameplates.rule(kind, phone, hurt?, shown?) -> { Show, Named, Distance, Text }
	      `shown`: whether wild plates are wanted at all (the strip's up and
	      you're not hunting); `hurt`: below full health (yours)
	  Nameplates.apply(board, rule)   sets a BillboardGui to it (its first
	                                  TextLabel is the name), changing only
	                                  what differs
]]
local Nameplates = {}

-- Studs a plate shows from, on a computer and on a phone; the name's size.
Nameplates.Distance = {
	Mine = { 70, 70 },
	Other = { 70, 30 },
	Wild = { 160, 60 },
	Critter = { 90, 45 },
}
Nameplates.Text = { 13, 11 }

export type Rule = { Show: boolean, Named: boolean, Distance: number, Text: number }

function Nameplates.rule(kind: string, phone: boolean, hurt: boolean?, shown: boolean?): Rule
	local distances = Nameplates.Distance[kind] or Nameplates.Distance.Critter
	local pick = if phone then 2 else 1
	local show = true
	if kind == "Mine" then
		show = hurt == true
	elseif kind == "Wild" or kind == "Critter" then
		show = shown == true
	end
	return {
		Show = show,
		Named = kind ~= "Mine",
		Distance = distances[pick],
		Text = Nameplates.Text[pick],
	}
end

function Nameplates.apply(board: BillboardGui, rule: Rule)
	if board.Enabled ~= rule.Show then
		board.Enabled = rule.Show
	end
	if board.MaxDistance ~= rule.Distance then
		board.MaxDistance = rule.Distance
	end
	local label = board:FindFirstChildOfClass("TextLabel")
	if label then
		if label.Visible ~= rule.Named then
			label.Visible = rule.Named
		end
		if label.TextSize ~= rule.Text then
			label.TextSize = rule.Text
		end
	end
end

return Nameplates
