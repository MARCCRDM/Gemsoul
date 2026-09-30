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

## Combat

Fighting is off inside the town walls, except in the **Arena** (west road), where four training dummies stand. Outside the south gate are the **Crystal Wilds**: Crystal Crawlers (quick, sometimes drop a stone) and Shard Brutes (tough, always drop one), each with an element. Monsters chase you, hit back, walk home if you drag them too far, and respawn. Kills pay coins to whoever did the most damage.

**Controls:** left click attacks (hold to keep swinging), **Q / E / R** cast your three chosen abilities, **F** is your ultimate, **K** opens the abilities screen. The hotbar at the bottom shows health, your class resource and cooldowns, and works on touch screens.

**Every class has:**

- **4 weapons.** Each has its own basic attack (melee cone with a combo finisher, or a ranged shot) and a passive: crits, armor break, bleeding, reach, splash, mana on hit, wards, chain lightning, long-range bonus, piercing, shield block, stuns or slows. New this update: Spear, Storm Scepter, Throwing Knives and Halberd.
- **3 armors**, each with a passive: Bastion (take less damage), Attuned (faster cooldowns) or Fleet (faster walking).
- **6 abilities; equip any 3** on Q / E / R, plus a class **ultimate** on F. Ability types: frontal strikes, area blasts, dashes, projectiles, self buffs and ground zones, with stuns, slows, taunts, burns, poison and executes.
- **A resource:** Rage (Warrior) and Resolve (Tank) build as you fight and fade out of combat; Mana (Wizard) and Focus (Archer) refill over time.

Gem enchantments now work in fights: weapon gems burn, slow, arc lightning or weaken, and an armor gem cuts damage from monsters of its element. Power, Defense, Speed and Health ratings (from class, gear, quality and gems) drive damage, damage taken, crit chance, max health and walk speed. Everything is in `src/shared/Classes.luau` and `src/shared/Combat.luau`; the server runs every hit (`Systems/CombatServer.luau`, `Systems/Enemies.luau`).

## Hub, Shop, Season Path, Party and Top Players

**The hub.** On the left, a big yellow SHOP button (B) over a 2x2 grid of menu tiles: Character (C), Abilities (K), Gems (G) and Party (P). Top right, gold-edged bars show your coins (the green + opens the Shop), Guild Marks and gems, with Season (J) and Top (L) buttons underneath.

**Buttons** are chunky 3D slabs, built by `IronUi.chunk`. From the outside in, each has a black outline, a darker lip underneath for depth, a light rim, and a gradient face. The face has a glossy top, diagonal light stripes and, on some buttons, a halftone dot texture. Icons are drawn big and break out of the edge. Hovering makes a button grow; pressing sinks its face into the lip. The same slabs are used for the combat hotbar (rimmed in your class colour), the gem pouch cards and tabs, shopkeeper replies and the intro. Windows share the look: a gold-rimmed frame that pops open, a glossy header with a tilted icon badge, outlined cartoon lettering and a red close slab.

**Shop** (coins today, Robux-ready). Tabs:

- **Featured:** the Geode Crate hero card: a floating crate, every prize with its odds, and buy 1, 5 (-10%) or 10 (-15%). Beside it the Masterwork Crate and the Welcome (or Legend) bundle.
- **Bundles:** big cards with value ribbons.
- **Back Pieces** and **Trims:** cosmetics with rarity-coloured tiles, a floating preview, and Buy / Equip / Take off.
- **Passes:** VIP.

**Opening crates** is full screen: light rays spin, the crate shakes harder and harder (click to hurry it), a white flash, then the prize pops out with its name, rarity and odds ("1/16.7"). Open up to 10 at once and the rest line up as cards underneath.

New players get a **Welcome Bundle** popup after the intro: 5x value, once, with a 24-hour countdown. Cosmetics use the gem rarity tiers. *Trims* recolour your class glow. *Back pieces* (Prospector's Pack, War Banner, Geode Shell, Ember Cape, Crystal Wings, Gem Halo) are worn behind your armor. To sell for Robux too, create Developer Products on Roblox and put their ids in `Store.RobuxProducts` (`src/shared/Store.luau`); the Shop shows Robux buttons and the server grants the items.

**Season Path.** Everything earns XP: mining, cutting, selling, crafting, enchanting, slaying and the daily reward. There are 30 levels, each with a reward to claim: coins, Marks, crates, materials, and exclusive trims and back pieces at levels 5, 10, 15, 20, 25 and 30. Bundles can include a 2x XP boost. Tuning is in `src/shared/Season.luau`.

**Party.** Invite up to three players in the server; they get an Accept / Decline popup. The party has a ready check, and the leader can kick members and set a **rally point** (Wilds, Arena, Quarry, Crafting Hall, Market) that draws a trail for everyone. Teammates' health shows at the top right with a marker over their heads. Monster kills reward every party member fighting nearby.

**Top Players.** Global leaderboards (best gem ever owned, Wilds kills, Season level), or the current server when data stores aren't available.

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
      CombatServer.luau       attacks, abilities, resources, buffs, damage taken
      Enemies.luau            training dummies and Wilds monsters: spawning, AI, loot
      StoreServer.luau        shop bundles, cosmetics, crates, Season Path claims, Robux receipts
      Progress.luau           season XP and levels
      Party.luau              parties: invites, ready check, rally points, shared rewards
      TopPlayers.luau         global leaderboards (ordered data stores)
      Equipment.luau          builds class weapons onto avatars, and socketed gems
      ArmorKits.luau          the 12 low-poly armor sets: helms, hoods, pauldrons
      Remotes.luau            client/server remotes
      Vip.luau                IsVIP attribute (game pass, or everyone in Studio)
  client/                     -> StarterPlayerScripts.Client
    Dialogue.client.luau      shopkeeper dialogue box and actions, quota terminal display
    Hud.client.luau           the hub: menu buttons, currencies, shop/season/top players; Welcome Bundle popup
    Guide.client.luau         NEXT STEP panel and trail for new players ([H] hides)
    Combat.client.luau        combat controls, hotbar HUD and hit effects
    Intro.client.luau         new-player intro screens
    Modules/                  shop, season, party, top players, character screen, Crafting Hall screen, gem pouch, 3D gem shapes and models, cutting minigame, UI helpers
    Effects.client.luau       spinning, bobbing, pulsing, flickering, shopkeepers turning
    VipGate.client.luau       lets VIPs walk through the energy gate
  shared/                     -> ReplicatedStorage.Shared
    Config.luau               tunable numbers (quotas, prices, saving, VIP pass id)
    GemConfig.luau            gem colours, tiers, odds, cut grades, value formula
    Classes.luau              classes, weapons, armor, abilities, specs, ratings
    Crafting.luau             materials, gear quality, recipes, gem sell prices
    Combat.luau               combat formulas, resources, where fighting is allowed
    Cosmetics.luau            trims and back pieces
    Store.luau                bundles, crates, welcome bundle, Robux product ids
    Season.luau               XP per activity, levels and rewards
    Vendors.luau              shopkeeper names, greetings and dialogue options
    Tags.luau                 CollectionService tag names
```

Interactive parts are tagged (see `Tags.luau`), so new systems find them with `CollectionService:GetTagged(...)` instead of hard-coded paths.
