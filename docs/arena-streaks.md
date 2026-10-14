# Ranked win streaks: Arena Caches (2026-10-14)

Win Ranked 1v1 matches in a row. Every milestone opens an **Arena Cache**: a
spread of **Rare and Ultra-Rare** pieces, gems and gear. You **keep two**; the
rest go up on the Market from the **Arena Vault**, for anyone to buy. Coins
and (at the big milestones) a title come straight away.

The higher the streak, the more of the cache is Ultra-Rare: one piece at 10
wins, all ten at 200.

| Streak | Name | Pieces offered | Ultra-Rare | Rare | You keep | Gear quality | Coins | Title |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10 | Contender | 4 | 1 | 3 | 2 | 2 | 2,500 | |
| 20 | Challenger | 4 | 1 | 3 | 2 | 2 | 5,000 | |
| 30 | Gladiator | 5 | 2 | 3 | 2 | 3 | 7,500 | GLADIATOR |
| 40 | Vanquisher | 5 | 2 | 3 | 2 | 3 | 10,000 | |
| 50 | Warlord | 6 | 3 | 3 | 2 | 3 | 15,000 | WARLORD |
| 60 | Juggernaut | 6 | 3 | 3 | 2 | 4 | 20,000 | |
| 70 | Ironclad | 6 | 4 | 2 | 2 | 4 | 25,000 | |
| 80 | Dreadnought | 7 | 4 | 3 | 2 | 4 | 30,000 | |
| 90 | Conqueror | 7 | 5 | 2 | 2 | 4 | 40,000 | |
| 100 | Centurion | 8 | 6 | 2 | 2 | 4 | 60,000 | CENTURION |
| 150 | Untouchable | 9 | 7 | 2 | 2 | 4 | 100,000 | UNTOUCHABLE |
| 200 | Arena Legend | 10 | 10 | 0 | 2 | 4 | 150,000 | ARENA LEGEND |

From 100 wins the gems are **Flawless**.

(250 to 1000 come later: add rows to `Shared.ArenaStreak.Milestones`.)

- **Pieces:** about half gems, half gear, with the Ultra-Rare ones shared out
  between the two. Gear is drawn from every Rare (tier 3) or Ultra-Rare
  (tier 4) piece (weapons, shields, helmets, armour, gloves, boots), never the
  same one twice in a cache. A **Flawless** gem has Size, Clarity and Cut at 10
  and its surge at the top rank. Each card is drawn in its rarity's colour.
- **What counts:** Ranked 1v1 wins only. A loss ends the streak. Beating the
  same player twice in a row doesn't add (no trading wins with a friend).
- **Once a season:** each milestone pays once per season; a second streak to
  the same mark that season pays nothing more.
- **Claiming:** the cache waits, saved, until you open it. A gold "ARENA CACHE
  READY" button shows in the lobby; it also opens by itself right after the
  match that earned it. Pick two, CLAIM. Your bags need room first.
- **The Arena Vault:** leftovers are listed on the Market under
  "Arena Vault · <name>'s <N>-win cache". Gear by rarity and quality: Rare
  4,000 to 7,500 coins, Ultra-Rare 8,000 to 15,000. Gems at three times their
  worth, at least 4,000 (Rare) or 8,000 (Ultra-Rare). If the Market
  can't be reached, they wait and go up when you next join.

All the numbers live in `src/shared/ArenaStreak.luau`.

## The roll

The first time a cache opens, it rolls. Every card flicks through Rare and
Ultra-Rare gems and gear (real gem shades and real gear names), slowing as its
turn comes. The cards then land one by one, left to right, on what the server
rolled. An Ultra-Rare lands with a pink flash and a shine. CLAIM unlocks once
everything has landed, and a tap during the roll lands it all at once. The
pieces are rolled on the server when the milestone is reached, so the
animation only reveals them.

## Testing it (DEV panel)

Test admins get an **ARENA CACHE** row in the DEV panel with
**10 · 20 · 30 · 40 · 50**. Each button rolls a fresh test cache for that
milestone and opens it, roll and all (`DevStreakCache` in
`Systems/ArenaStreaks`).

- Test caches pay no coins or title, and don't count as paid for the season.
- The two you keep go into your bags, so you can see them in your inventory.
- The rest are dropped. They never go up on the Market.
- A new test cache replaces the last one.
