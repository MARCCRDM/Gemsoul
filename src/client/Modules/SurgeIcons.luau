-- Surge icons. Every surge, original or new, shows the Icon glyph from its
-- definition (Shared.CombatTechnology), so they all share one style. The
-- callers set the glyph; this keeps their labels tidy: it clears any drawn
-- symbol left from the old line-art icons and fills an empty label.
local Icons = {}

function Icons.apply(label, definition, _color)
	local old = label:FindFirstChild("SurgeSymbol")
	if old then
		old:Destroy()
	end
	if type(definition) == "table" and definition.Icon and label.Text == "" then
		label.Text = definition.Icon
	end
end

return Icons
