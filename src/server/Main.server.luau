-- Server entry point: build the world, then start the gameplay systems that
-- hook into it through CollectionService tags.
local WorldBuilder = require(script.Parent.World.WorldBuilder)
local PlayerData = require(script.Parent.Systems.PlayerData)
local Vip = require(script.Parent.Systems.Vip)
local Mining = require(script.Parent.Systems.Mining)
local Shop = require(script.Parent.Systems.Shop)

WorldBuilder.build()
PlayerData.start()
Vip.start()
Mining.start()
Shop.start()
