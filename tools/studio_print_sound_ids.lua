-- Prints one "name=id" line for every Sound in the place, for
-- tools/apply_sound_ids.py: paste this whole file into Studio's command bar
-- (View > Command Bar) and press Enter, after inserting the imported audio
-- (View > Asset Manager > Audio: select the files, right-click > Insert; each
-- is a Sound in the Workspace named after its file). Copy the lines the
-- Output window prints into a text file.
local lines, seen = {}, {}
local function note(sound)
	local id = string.match(sound.SoundId or "", "%d+")
	if id and not seen[sound.Name] then
		seen[sound.Name] = true
		table.insert(lines, sound.Name .. "=" .. id)
	end
end
for _, object in game:GetService("Selection"):Get() do
	if object:IsA("Sound") then
		note(object)
	end
end
for _, object in workspace:GetDescendants() do
	if object:IsA("Sound") then
		note(object)
	end
end
table.sort(lines)
print(#lines .. " sounds:\n" .. table.concat(lines, "\n"))
