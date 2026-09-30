-- Server entry point: build the world, then start the gameplay systems that
-- hook into it through CollectionService tags.
local WorldBuilder = require(script.Parent.World.WorldBuilder)
local PlayerData = require(script.Parent.Systems.PlayerData)
local Vip = require(script.Parent.Systems.Vip)
local Mining = require(script.Parent.Systems.Mining)
local Shop = require(script.Parent.Systems.Shop)
local Intro = require(script.Parent.Systems.Intro)
local Enchanting = require(script.Parent.Systems.Enchanting)
local Equipment = require(script.Parent.Systems.Equipment)

WorldBuilder.build()
PlayerData.start()
Vip.start()
Mining.start()
Shop.start()
Intro.start()
Enchanting.start()
Equipment.start()
