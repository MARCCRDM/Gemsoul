--[[
	The UI's images fetched ahead, in the background, so a screen that shows
	one doesn't open with blank squares that pop in once it's downloaded (on
	a phone that can take a good few seconds).

	  ImagePreload.add(ids)   image asset ids (numbers; 0 for "not uploaded"
	                          is skipped) to fetch, each once
]]
local ImagePreload = {}

local seen: { [number]: boolean } = {}
local queued: { string } = {}
local running = false

function ImagePreload.add(ids: { number })
	for _, id in ids do
		if typeof(id) == "number" and id > 0 and not seen[id] then
			seen[id] = true
			table.insert(queued, "rbxassetid://" .. id)
		end
	end
	if running or #queued == 0 then
		return
	end
	running = true
	task.defer(function()
		local ok, provider = pcall(game.GetService, game, "ContentProvider")
		while ok and #queued > 0 do
			local batch = queued
			queued = {}
			pcall(provider.PreloadAsync, provider, batch)
		end
		running = false
	end)
end

return ImagePreload
