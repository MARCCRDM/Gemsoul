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
| North road | Mining Guild and daily quota terminal, then the quarry with gem nodes (they regrow 45-90 s after mining) and the VIP energy gate | Garrick, Mining Foreman |
| North road | Gem Cutter stall beside the Mining Guild: holographic cutting bench and laser cutter | Ilsa, Master Gemcutter |
| North road | Crafting Hall: stone exchange and materials stall out front, Borin's open-air forge next door | Hilde, Guild Quartermaster; Borin, Master Smith |
| Market square | Stalls with trade kiosks and the holographic P2P listing board; Tamsin buys stones for coins | Tamsin, Trade Broker |
| East road | Arcanum tower with glowing runes and floating containment fields | Vey, Arcanist |
| West road | Obsidian arena with PvP and PvE queue screens | Brutus, Arena Master |

Every shop has a robot shopkeeper outside. Walk up and press **E** to talk, then pick a question from the dialogue box. Mining, the Mining Store and gem cutting work now; the other shops explain what's coming.

Streets and building plots are painted terrain (cobblestone, pavement, dirt), so grass only grows in the gardens, the farm field and outside the walls.

## New players: the intro

Players who haven't finished the intro see it when they join (over a flyover of the kingdom):

1. **Welcome** to Gemsoul.
2. **Class:** Warrior, Wizard, Archer or Tank, each with a role, stats, difficulty and three core abilities.
3. **Weapon** and 4. **Armor:** three playstyles each per class. A live preview shows your own avatar wearing your picks.
5. **Starter gems:** a lottery spin for three already-cut gems (at least one Uncommon or better).
6. **Gem school:** cut a rough stone yourself while each property is explained, plus where gems go in town.
7. **Enchant:** socket a cut gem into your weapon; it glows in the gem's colour. The armor socket opens at Vey's Arcanum.
8. **Ready:** character sheet, then into the game wearing your gear.

Classes, gear and upcoming specializations are defined in `src/shared/Classes.luau`. Combat isn't built yet: abilities are listed but not active.

## Gems

Gemstones follow the *GemSoul Gemstone Property & Generation Architecture* design:

- **Element and colour:** Fire, Frost, Shock or Poison, each with Common, Uncommon and Rare (Fire, Frost) or Ultra-Rare (Shock, Poison) colours. Roughly 71% common, 25% uncommon, 2.5% rare, 1.6% ultra-rare.
- **Clarity and size:** graded 1-10 on generation, high grades rarer. Size raises value exponentially and makes hand-cutting harder.
- **Cut:** stones start rough. Ilsa's hand-cutting minigame grades 1-8 by accuracy, 9 for mastery and 10 (Gem Mint) for a flawless cut. Her lasers cut 5-8, 9 or 10 for 40, 150 or 400 coins.
- **Sources:** mining nodes (limited by free daily and weekly mines), Garrick's Mining Store (coins for a random rough stone), PvE drops (`Gems.dropFromMonster`) and PvP wagers (`PlayerData.transferGem`, which keeps every property). Luckier sources (VIP pit, store, tougher monsters) roll better stones.

Every gem is shown in 3D and its look follows its properties: rough stones are water-worn pebbles unique to each gem, cut stones are round brilliants whose symmetry and facets improve with the cut grade (sparkling at 9-10), size sets how big it is, and clarity sets how clear or cloudy it is (low clarity shows inclusions).

## Character screen and enchanting

Press **C** (or the CHARACTER button) for a Diablo-style character screen: your avatar with the weapon and armor slots either side, a gem socket under each, attributes and active enchantments below, and a grid inventory of every gem. Click a gem or socket to inspect it.

Each piece of gear has one socket, for cut gems only. An enchanted item takes on its gem's element:

- **Name:** Diablo-style affixes, e.g. *Venomous Longsword*, *Iron Plate of Storms*.
- **Effect:** a weapon gem adds its element to your hits (Burning, Frostbite, Arcing, Venom); an armor gem wards you against it (+resistance, +max health).
- **Stats:** each element raises its own attributes, scaled by the gem's potency (mostly size, then clarity and cut). Fire gives Power; Frost gives Defense; Shock gives Speed; Poison gives Health. See `GemConfig.EnchantStats`.
- **Looks:** the item's glowing trim turns the element's colour, the gem lights up, and particles pour off it (flames, frost motes, sparks, poison fumes). Frost also rimes the blade.

Attributes are ratings (20 per class/gear point, plus gem bonuses) and they're live: Speed sets walk speed and Health sets max health (`Classes.walkSpeed` / `Classes.maxHealth`). After the intro, sockets are changed at Vey's Arcanum on the east road ("Enchant my gear").

## The Crafting Hall: selling stones, materials and gear

The Crafting Hall on the north road (east side) is for crafting only; gem cutting is across the road at Ilsa's stall beside the Mining Guild.

- **Guild Marks:** the hall's own currency. You earn Marks only by selling stones to **Hilde** at the stone exchange out front (60% of a stone's value), and spend them on materials and forge fees. Coins aren't used in the hall. Hilde can also salvage stones into Gem Shards. Selling and salvaging ask you to confirm; *All rough* and *All common* select in bulk.
- **Materials:** Hilde's stall sells Iron, Timber, Leather, Cloth and Mithril for Marks. Each class uses its own set (Warrior/Tank: iron, timber, leather; Wizard: timber, cloth, leather; Archer: timber, leather, cloth). Gem Shards can't be bought.
- **Crafting:** at **Borin's** anvil next door, forge any weapon or armor for your class, then upgrade it through four qualities: Standard (white), Fine (green), Superior (blue, needs Mithril) and Masterwork (orange, needs Mithril and Gem Shards). Each step adds Power to weapons or Defense and Health to armor, and changes the look: polished, then mithril blue-silver, then blackened steel with gold trim. *Buy missing* tops up materials in one click. Equip gear at the hall, or click a gear slot on the character screen.

Recipes, prices and quality bonuses live in `src/shared/Crafting.luau`. Selling, buying and crafting only work at the hall (the server checks). Marks show on the leaderboard and the HUD.

## Coins, Marks and getting started

- **Two currencies.** *Coins* buy rough stones from Garrick and laser cuts from Ilsa. You get them from a **daily reward** (75 coins, plus 25 more for each day of your streak, up to a week) and by selling stones to **Tamsin** at the Market (50% of value). *Guild Marks* are only for the Crafting Hall and come from selling stones to Hilde (60% of value).
- **The guide.** After the intro, a NEXT STEP panel and a glowing trail lead new players through the loop: mine, cut, sell, craft, enchant. Each step completes when you first do it. Returning players' earlier progress counts. Press **H** to hide it.

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
        Mining.luau  Cutting.luau  Crafting.luau  Marketplace.luau  Enchanting.luau  Arena.luau
    Systems/
      GemGenerator.luau       rolls gems and grades cuts (pure logic)
      Gems.luau               awards generated gems to players (all sources)
      PlayerData.luau         saved coins, Guild Marks, gems, materials, gear, free-mining quota
      Mining.luau             quarry nodes: free mines give rough stones
      Shop.luau               store purchases, laser cuts, hand-cut minigame
      Intro.luau              intro steps: loadout, starter spin, first stone
      Enchanting.luau         socketing gems into weapon and armor (at Vey's)
      Forge.luau              the Crafting Hall: selling stones for Marks, materials, crafting, equipping
      Nearby.luau             is a player standing near a shopkeeper?
      Equipment.luau          builds class weapons onto avatars, and socketed gems
      ArmorKits.luau          the 12 low-poly armor sets: helms, hoods, pauldrons
      Remotes.luau            client/server remotes
      Vip.luau                IsVIP attribute (game pass, or everyone in Studio)
  client/                     -> StarterPlayerScripts.Client
    Dialogue.client.luau      shopkeeper dialogue box and actions, quota terminal display
    Hud.client.luau           corner buttons: character screen ([C]) and gem pouch ([G])
    Guide.client.luau         NEXT STEP panel and trail for new players ([H] hides)
    Intro.client.luau         new-player intro screens
    Modules/                  character screen, Crafting Hall screen, gem pouch, 3D gem shapes and models, cutting minigame, UI helpers
    Effects.client.luau       spinning, bobbing, pulsing, flickering, shopkeepers turning
    VipGate.client.luau       lets VIPs walk through the energy gate
  shared/                     -> ReplicatedStorage.Shared
    Config.luau               tunable numbers (quotas, prices, saving, VIP pass id)
    GemConfig.luau            gem colours, tiers, odds, cut grades, value formula
    Classes.luau              classes, weapons, armor, abilities, specs, ratings
    Crafting.luau             materials, gear quality, recipes, gem sell prices
    Vendors.luau              shopkeeper names, greetings and dialogue options
    Tags.luau                 CollectionService tag names
```

Interactive parts are tagged (see `Tags.luau`), so new systems find them with `CollectionService:GetTagged(...)` instead of hard-coded paths.
