# Ranked win streaks: Arena Caches (2026-10-14)

Win Ranked 1v1 matches in a row. Every milestone opens an **Arena Cache**:

- **Gems, free:** every gem in the cache is yours.
- **Six pieces of gear to choose from** (Rare and Ultra-Rare): you **keep
  three**. The other three go up on the Market from the **Arena Vault**, and
  **when one sells you get 25% of its price** (a commission, paid even if
  you're offline when it sells, the next time you're on).

Coins and (at the big milestones) a title come straight away.

| Streak | Name | Free gems | Gear: Ultra-Rare / Rare | You keep | Gear quality | Coins | Title |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 10 | Contender | 1 Rare | 1 / 5 | 3 of 6 | 2 | 2,500 | |
| 20 | Challenger | 1 Rare | 1 / 5 | 3 of 6 | 2 | 5,000 | |
| 30 | Gladiator | 2 Rare | 2 / 4 | 3 of 6 | 3 | 7,500 | GLADIATOR |
| 40 | Vanquisher | 2 Rare | 2 / 4 | 3 of 6 | 3 | 10,000 | |
| 50 | Warlord | 2 Ultra-Rare | 3 / 3 | 3 of 6 | 3 | 15,000 | WARLORD |
| 60 | Juggernaut | 2 Ultra-Rare | 3 / 3 | 3 of 6 | 4 | 20,000 | |
| 70 | Ironclad | 3 Ultra-Rare | 4 / 2 | 3 of 6 | 4 | 25,000 | |
| 80 | Dreadnought | 3 Ultra-Rare | 4 / 2 | 3 of 6 | 4 | 30,000 | |
| 90 | Conqueror | 3 Ultra-Rare | 5 / 1 | 3 of 6 | 4 | 40,000 | |
| 100 | Centurion | 3 Flawless Ultra-Rare | 5 / 1 | 3 of 6 | 4 | 60,000 | CENTURION |
| 150 | Untouchable | 4 Flawless Ultra-Rare | 6 / 0 | 3 of 6 | 4 | 100,000 | UNTOUCHABLE |
| 200 | Arena Legend | 5 Flawless Ultra-Rare | 6 / 0 | 3 of 6 | 4 | 150,000 | ARENA LEGEND |

(250 to 1000 come later: add rows to `Shared.ArenaStreak.Milestones`.)

- **Pieces:** the free gems, then six pieces of gear (each card shows its stat
  rolls, passive and affixes). Gear is drawn from every Rare (tier 3) or Ultra-Rare
  (tier 4) piece (weapons, shields, helmets, armour, gloves, boots), never the
  same one twice in a cache. A **Flawless** gem has Size, Clarity and Cut at 10
  and its surge at the top rank. Each card is drawn in its rarity's colour.
- **What counts:** Ranked 1v1 wins only. A loss ends the streak. Beating the
  same player twice in a row doesn't add (no trading wins with a friend).
- **Once a season:** each milestone pays once per season; a second streak to
  the same mark that season pays nothing more.
- **The commission:** each leftover's listing carries your cut
  (`MarketBoard.vaultList`'s commission). When it sells, a "Commission" note
  goes to your Market mailbox and is paid when you're next settled up, once
  only, even if the note is seen again.
- **Claiming:** the cache waits, saved, until you open it. A gold "ARENA CACHE
  READY" button shows in the lobby; it also opens by itself right after the
  match that earned it. Pick three pieces of gear, CLAIM: they and every
  gem arrive. Your bags need room for all of them first.
- **The Arena Vault:** leftovers are listed on the Market under
  "Arena Vault · <name>'s <N>-win cache". Gear by rarity and quality: Rare
  4,000 to 7,500 coins, Ultra-Rare 8,000 to 15,000 (you get 25% of that).
  If the Market can't be reached, they wait and go up when you next join.

All the numbers live in `src/shared/ArenaStreak.luau`.

## The roll

The first time a cache opens, the whole grid rolls at once
(`src/client/Modules/CacheLottery.luau`). Every card has its own round reel,
the mining find's display (`MiningReveal`) made small, and they all spin
together. Each slows as its turn comes and lands in order: the free gems
first, then the gear, 0.4 s apart.

- **Gem reels** roll through gems of every rarity, like a real find, and land
  on yours. Size, Clarity and Cut fill in as bars.
- **Gear reels** roll through the cache's own armour and weapons in 3D and
  land on each piece. Its quality bar fills in (out of 4), then its stat
  rolls, passive and affixes appear.

While it rolls, each card shows the rarity and name rolling past. Tapping a
card or the button lands everything at once. Once all have landed, the same
grid is the pick screen. The pieces are rolled on the server when the
milestone is reached, so the reels only reveal them. Opening a cache again in
the same session shows it already landed.

Every piece is shown in 3D: gems from their data, gear from a preview the
server builds on its mannequin (the same as the Market's,
`Equipment.groupPreviews`, group "A"). Gear has its look (finish, visor and
roll) rolled when the cache is rolled, at its own tier as the Forge does, so
the model you see is exactly the piece you get. Previews are built when the
cache list loads. The gear reels wait for them (3 s at most from opening;
the gems spin meanwhile), so they roll the real models.

## Testing it (DEV panel)

Test admins get an **ARENA CACHE** row in the DEV panel with
**10 · 20 · 30 · 40 · 50**. Each button rolls a fresh test cache for that
milestone and opens it, roll and all (`DevStreakCache` in
`Systems/ArenaStreaks`).

- Test caches pay no coins or title, and don't count as paid for the season.
- The three pieces you keep and the gems go into your bags, so you can see them in your inventory.
- The rest are dropped. They never go up on the Market.
- A new test cache replaces the last one.
