-- Server entry point: build the town, then start the gameplay systems that
-- hook into it through CollectionService tags.
local WorldBuilder = require(script.Parent.World.WorldBuilder)
local Leaderboard = require(script.Parent.Systems.Leaderboard)
local Vip = require(script.Parent.Systems.Vip)
local Mining = require(script.Parent.Systems.Mining)

WorldBuilder.build()
Leaderboard.start()
Vip.start()
Mining.start()
