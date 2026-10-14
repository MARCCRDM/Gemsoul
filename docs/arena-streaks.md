# Ranked win streaks: Arena Caches (2026-10-14)

Win Ranked 1v1 matches in a row. Every milestone opens an **Arena Cache**: a
spread of Legendary pieces, gems and gear. You **keep two**; the rest go up on
the Market from the **Arena Vault**, for anyone to buy. Coins and (at the big
milestones) a title come straight away.

| Streak | Name | Pieces offered | You keep | Gear quality | Gems | Coins | Title |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 10 | Contender | 4 | 2 | 2 | Legendary | 2,500 | |
| 20 | Challenger | 4 | 2 | 2 | Legendary | 5,000 | |
| 30 | Gladiator | 5 | 2 | 3 | Legendary | 7,500 | GLADIATOR |
| 40 | Vanquisher | 5 | 2 | 3 | Legendary | 10,000 | |
| 50 | Warlord | 6 | 2 | 3 | Legendary | 15,000 | WARLORD |
| 60 | Juggernaut | 6 | 2 | 4 | Legendary | 20,000 | |
| 70 | Ironclad | 6 | 2 | 4 | Legendary | 25,000 | |
| 80 | Dreadnought | 7 | 2 | 4 | Legendary | 30,000 | |
| 90 | Conqueror | 7 | 2 | 4 | Legendary | 40,000 | |
| 100 | Centurion | 8 | 2 | 4 | Flawless Legendary | 60,000 | CENTURION |
| 150 | Untouchable | 9 | 2 | 4 | Flawless Legendary | 100,000 | UNTOUCHABLE |
| 200 | Arena Legend | 10 | 2 | 4 | Flawless Legendary | 150,000 | ARENA LEGEND |

(250 to 1000 come later: add rows to `Shared.ArenaStreak.Milestones`.)

- **Pieces:** about half gems, half gear. Gear is drawn from all 24 Legendary
  pieces (weapons, shields, helmets, armour, gloves, boots), never the same one
  twice in a cache. A **Flawless** gem has Size, Clarity and Cut at 10 and its
  surge at the top rank.
- **What counts:** Ranked 1v1 wins only. A loss ends the streak. Beating the
  same player twice in a row doesn't add (no trading wins with a friend).
- **Once a season:** each milestone pays once per season; a second streak to
  the same mark that season pays nothing more.
- **Claiming:** the cache waits, saved, until you open it. A gold "ARENA CACHE
  READY" button shows in the lobby; it also opens by itself right after the
  match that earned it. Pick two, CLAIM. Your bags need room first.
- **The Arena Vault:** leftovers are listed on the Market under
  "Arena Vault · <name>'s <N>-win cache": gear at 12,000 to 22,000 coins by
  quality, gems at three times their worth (12,000 at least). If the Market
  can't be reached, they wait and go up when you next join.

All the numbers live in `src/shared/ArenaStreak.luau`.
