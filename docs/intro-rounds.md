# Intro rounds

After the first fight, a new miner can stay in the Arena for a ladder of six
rounds. Each win rolls a piece of gear for the next slot, puts it on at once,
and the rival for the next round is harder (and wears rarer cosmetics).

| Round | Rival | Pays | Rival's look |
|---|---|---|---|
| 1 | the first fight's sparring partner | Sword | default |
| 2 | Vera Coppercoil, the Tinkerer | Shield | Copper Coil suit, Copper Wire blade, Hi-Vis Lime visor |
| 3 | Sable, the Shadow | Chest (+ a gem to socket) | Stealth Black, Toxic Ooze, Twilight |
| 4 | Korr, the Stormcaller | Gloves | Storm Conductor, Plasma Edge, Ion Storm, Arena Plume |
| 5 | Magmar, the Forgeborn | Boots | Obsidian Lava, Molten Core, Thermal Core, Shogun Kabuto |
| 6 | Nova, the Champion | Helmet (+500 coins: the set) | Nebula Suit, Solar Flare, Supernova, Wyrmking, Gem Halo |

- **The roll:** Uncommon, with a 15% chance of Rare. If no Rare has come by
  round 6, round 6 is Rare. The sword round only gives one-handed swords.
- **Optional:** between rounds a card shows the piece, the six-slot set and
  who's next: NEXT ROUND (starts by itself after 10 s in the Arena) or LEAVE.
  The NEXT STEP card offers WIN YOUR INTRO SET (FIGHT) until it's done.
- **Any win counts:** a queued Casual or Ranked 1v1 won pays the round's piece
  in place of that win's usual reward. NEXT ROUND joins a real player who's
  waiting alone in a 1v1 queue; otherwise the round's rival steps in at once.
- **Nobody gets stuck:** a lost round knocks you down (not out), you stay in the
  Arena, and each loss makes that round's next try easier (less damage, slower
  swings, no dash-ins).
- **Who:** accounts the onboarding funnel counts (new players), until the set
  is won. Each round is sent to Analytics as an `IntroRound` event.
- **Arena barrier:** while you fight on the Arena floor, a force field round
  its edge (built on your own screen) keeps you from walking off by accident.

Code: `Shared/IntroRounds.luau` (rules), `Server/Systems/IntroRoundsServer.luau`,
`Server/Systems/Duelist.luau` (the rivals), `Server/Systems/Duels.luau` (queued
wins), `Client/Modules/IntroRoundsUI.luau` (the card),
`Client/Modules/ArenaBarrier.luau`. Tests: `python3 tests/run_intro_rounds.py`.
