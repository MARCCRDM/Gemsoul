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

Gemsoul is a walled village on a sunny afternoon, laid out like an Oblivion town. You spawn in the market square by the fountain. The main street runs south to the gatehouse and drawbridge, and three more roads lead off the square, lined with timber-and-stone houses:

| Where | What's there | Shopkeeper |
|---|---|---|
| North road | Mining Guild and daily quota terminal, then the quarry with static gem nodes and the VIP energy gate | Garrick, Mining Foreman |
| North road | Craft & Cut workshop: holographic cutting bench and laser cutter out front | Ilsa, Master Gemcutter |
| Market square | Stalls with trade kiosks and the holographic P2P listing board | Tamsin, Trade Broker |
| East road | Arcanum tower with glowing runes and floating containment fields | Vey, Arcanist |
| West road | Obsidian arena with PvP and PvE queue screens | Brutus, Arena Master |

Every shop has a robot shopkeeper outside. Walk up and press **E** to talk, then pick a question from the dialogue box. Mining, the Mining Store and gem cutting work now; the other shops explain what's coming.

Streets and building plots are painted terrain (cobblestone, pavement, dirt), so grass only grows in the gardens, the farm field and outside the walls.

## Gems

Gemstones follow the *GemSoul Gemstone Property & Generation Architecture* design:

- **Element and colour:** Fire, Frost, Shock or Poison, each with Common, Uncommon and Rare (Fire, Frost) or Ultra-Rare (Shock, Poison) colours. Roughly 71% common, 25% uncommon, 2.5% rare, 1.6% ultra-rare.
- **Clarity and size:** graded 1-10 on generation, high grades rarer. Size raises value exponentially and makes hand-cutting harder.
- **Cut:** stones start rough. Ilsa's hand-cutting minigame grades 1-8 by accuracy, 9 for mastery and 10 (Gem Mint) for a flawless cut. Her lasers cut 5-8, 9 or 10 for 40, 150 or 400 coins.
- **Sources:** mining nodes (limited by free daily and weekly mines), Garrick's Mining Store (coins for a random rough stone), PvE drops (`Gems.dropFromMonster`) and PvP wagers (`PlayerData.transferGem`, which keeps every property). Luckier sources (VIP pit, store, tougher monsters) roll better stones.

Press **G** or the corner button to open your gem pouch. Coins, gems and quotas save between sessions; in Studio this needs *Game Settings > Security > Enable Studio Access to API Services*.

Tunable numbers live in `src/shared/Config.luau` (quotas, prices, starting coins) and `src/shared/GemConfig.luau` (colour tiers, odds, cut difficulty, values).

## Code layout

```
src/
  server/                     -> ServerScriptService.Server
    Main.server.luau          builds the world, then starts the systems
    World/
      Builder.luau            shared pieces: houses, shopkeepers, walls, neon, CRT screens, signs, trees
      Lighting.luau           daytime sky, clouds, haze, bloom
      Hub.luau                square centrepiece: obelisk, fountain, benches, spawn
      Town.luau               village layout: streets, houses, lamps, farm, gardens
      Kingdom.luau            town walls, towers, gatehouse, drawbridge
      Landscape.luau          terrain: plains, moat, hills, mountains, forest
      WorldBuilder.luau       builds everything in order
      Zones/                  one file per shop
        Mining.luau  Crafting.luau  Marketplace.luau  Enchanting.luau  Arena.luau
    Systems/
      GemGenerator.luau       rolls gems and grades cuts (pure logic)
      Gems.luau               awards generated gems to players (all sources)
      PlayerData.luau         saved coins, gem inventory, free-mining quota
      Mining.luau             quarry nodes: free mines give rough stones
      Shop.luau               store purchases, laser cuts, hand-cut minigame
      Remotes.luau            client/server remotes
      Vip.luau                IsVIP attribute (game pass, or everyone in Studio)
  client/                     -> StarterPlayerScripts.Client
    Dialogue.client.luau      shopkeeper dialogue box and actions, quota terminal display
    Hud.client.luau           coins/gems button, opens the pouch ([G])
    Modules/                  gem pouch, gem art (icons + 3D models), cutting minigame, UI helpers
    Effects.client.luau       spinning, bobbing, pulsing, flickering, shopkeepers turning
    VipGate.client.luau       lets VIPs walk through the energy gate
  shared/                     -> ReplicatedStorage.Shared
    Config.luau               tunable numbers (quotas, prices, saving, VIP pass id)
    GemConfig.luau            gem colours, tiers, odds, cut grades, value formula
    Vendors.luau              shopkeeper names, greetings and dialogue options
    Tags.luau                 CollectionService tag names
```

Interactive parts are tagged (see `Tags.luau`), so new systems find them with `CollectionService:GetTagged(...)` instead of hard-coded paths.
