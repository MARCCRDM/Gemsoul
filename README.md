# Gemsoul

A Roblox game. Code lives in `src/` as Luau files and is synced into Roblox Studio with [Rojo](https://rojo.space).

## Setup (once, on your Windows/Mac computer)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run `rokit install` (installs Rojo, StyLua, Selene).
2. In Roblox Studio, install the Rojo plugin: Plugins tab → search "Rojo", or run `rojo plugin install`.

## Every time you work on it

1. `git pull` to get the latest code.
2. `rojo serve` in this folder.
3. Open a Baseplate in Studio → Plugins → Rojo → **Connect**.
4. Press **Play**. Walk into the glowing gems and watch your Gems count go up.

## The town

The world is built by code when the server starts, so **it only appears after you press Play**. In edit mode you'll just see the empty baseplate.

The town is a walled kingdom on a sunny afternoon. A sixteen-sided stone wall with blue-roofed towers and a moat surrounds everything; the main gate and drawbridge are to the south, where a tree-lined avenue runs from the plaza. Outside the walls are rolling hills, forest, a country road and snow-capped mountains (all Roblox terrain).

A central plaza with a CRT obelisk and fountain sits in the middle, with neon roads out to five zones:

| Zone | Direction | What's there |
|---|---|---|
| Mine | North | Neon-lit quarry, static gem nodes (don't regenerate), daily quota terminal, VIP energy gate |
| Craft & Cut | Northeast | Stone workbench with holographic displays (QTE cutting), forge, laser cutters tiers 1-3 |
| Bazaar | Southeast | Wooden stalls with trade kiosks, drone lanterns, holographic P2P listing board |
| Arcanum | Southwest | Octagonal chamber, pulsing runes, floating containment fields, enchanting altar |
| Arena | Northwest | Obsidian colosseum, glowing grid floor, PvP collateral and PvE queue terminals |

Only mining works so far. The other stations show "coming soon" when used.

## Code layout

```
src/
  server/                     -> ServerScriptService.Server
    Main.server.luau          builds the world, then starts the systems
    World/
      Builder.luau            shared pieces: walls, pillars, neon, CRT screens, holograms, signs
      Lighting.luau           daytime sky, clouds, haze, bloom
      Hub.luau                plaza, obelisk, fountain, spawn, roads
      Kingdom.luau            outer walls, towers, gatehouse, gardens
      Landscape.luau          terrain: plains, moat, hills, mountains, forest
      WorldBuilder.luau       zone list and ring layout
      Zones/                  one file per building
        Mining.luau  Crafting.luau  Marketplace.luau  Enchanting.luau  Arena.luau
    Systems/
      Leaderboard.luau        Gems stat, quota tracking
      Mining.luau             spawns gem nodes on NodeSpawner pads
      Vip.luau                IsVIP attribute (game pass, or everyone in Studio)
  client/                     -> StarterPlayerScripts.Client
    Effects.client.luau       spinning, bobbing, pulsing, flickering
    Interactions.client.luau  quota terminal, "coming soon" prompts
    VipGate.client.luau       lets VIPs walk through the energy gate
  shared/                     -> ReplicatedStorage.Shared
    Config.luau               tunable numbers (quota, gem values, VIP pass id)
    Tags.luau                 CollectionService tag names
```

Interactive parts are tagged (see `Tags.luau`), so new systems find them with `CollectionService:GetTagged(...)` instead of hard-coded paths.
