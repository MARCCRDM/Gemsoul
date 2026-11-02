# Intro rounds

After the first fight, a new miner can stay in the Arena for a ladder of six
rounds. Each win rolls a piece of gear for the next slot, puts it on at once,
and the rival for the next round is harder (and wears rarer cosmetics).

| Round | Rival | Hits (of an Arena rival) | Swings | Health | Pays | Rival's look |
|---|---|---|---|---|---|---|
| 1 | the first fight's sparring partner | 50% | slower | 90% | Sword | default |
| 2 | Vera Coppercoil, the Tinkerer | 68% | slower | 100% | Shield | Copper Coil suit, Copper Wire blade, Hi-Vis Lime visor |
| 3 | Sable, the Shadow | 82% | slower | 112% | Chest (+ a gem to socket) | Stealth Black, Toxic Ooze, Twilight |
| 4 | Korr, the Stormcaller | 96% + lunge | even | 125% | Gloves | Storm Conductor, Plasma Edge, Ion Storm, Arena Plume |
| 5 | Magmar, the Forgeborn | 110% + lunge | faster | 140% | Boots | Obsidian Lava, Molten Core, Thermal Core, Shogun Kabuto |
| 6 | Nova, the Champion | 125% + lunge | faster | 160% | Helmet (+500 coins: the set) | Nebula Suit, Solar Flare, Supernova, Wyrmking, Gem Halo |

- **Harder each round:** each rival hits harder, swings faster and has more
  health than the last, by more than the piece you just won adds; the last
  two outhit a full Arena rival. Each loss of a round eases its next try
  (15% less damage, 10% slower, 10% less health, down to a floor).
- **On the card:** the roll plays first: a strip of the pieces that round
  can give (Uncommon, a Rare now and then) spins past a marker, slows and
  stops on yours, then it shows in 3D.
- **The roll:** Uncommon, with a 15% chance of Rare. If no Rare has come by
  round 6, round 6 is Rare. The sword round only gives one-handed swords.
- **Optional:** between rounds a card shows the piece, the six-slot set and
  who's next: NEXT ROUND (starts by itself after 3 s in the Arena) or LEAVE.
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

## The Intro Rounds funnel

Sent to Roblox as a one-time funnel named **IntroRounds** (Creator Dashboard >
Analytics > Funnels; one session per player), and shown in the in-game
ANALYTICS window as INTRO ROUNDS FUNNEL. Twelve steps, each logged once per
player:

| Step | Name | When |
|---|---|---|
| 1 | R1 start · Sword | the first fight starts (round 1 is the first fight) |
| 2 | R1 won · Sword | it's won |
| 3, 5, 7, 9, 11 | R2..R6 start · Shield, Chest, Gloves, Boots, Helmet | NEXT ROUND (or TRY AGAIN) starts it, against the rival or a waiting player |
| 4, 6, 8, 10, 12 | R2..R6 won · ... | it's won (12: the whole set) |

A big drop from a **won** step to the next **start** means players leave at
the card between rounds. A big drop from a **start** to its **won** means the
round is too hard (or they quit mid-fight).


## Between rounds: three ways on

The card between rounds offers **CONTINUE INTRO ROUNDS** (or TRY AGAIN after a loss; it starts by itself after `IntroRoundsUI.AutoNext`, 10 s, in the Arena), **GO TO LOBBY** (the set waits; PLAY carries on) and **FIRST DUNGEON** (the Rot Beachhead: docs/brainrot-dungeons.md; shown to those it's open to, `Config.Features.FirstDungeon`). The set done: TO THE FIRST DUNGEON with GO TO LOBBY beside it, or GO TO LOBBY alone.
