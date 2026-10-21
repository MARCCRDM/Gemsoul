# The Kaiju Arena: downstairs, rows of courts, stakes and arrows on the ground

Kaiju battles now have a home of their own. Take the stairs down from the
Shelter and you're on the balcony of the **Kaiju Arena**: a hall with eight
courts in two rows, like ping-pong tables. Each court has a pad at either
end:

1. Stand on a pad and you're waiting for a challenger.
2. Someone steps onto the other pad and says FIGHT.
3. You both get 25 seconds to drag your kaiju into place.
4. Your kaiju fight it out on that court while everyone else watches from
   the aisles and the balcony.

You can play for coins or a gem, shown on the court's board and pedestal
for everyone to see. And in every battle:

- **Full health, then back.** Every kaiju fights at full health, even one
  that was knocked out. When it's over, each goes back to the health it had
  before, win or lose.
- **The overview camera.** Once the fight starts, the camera rises over
  your end of the court like a spectator's. Drag to look round it, scroll
  or pinch to zoom.
- **BLUE against RED.** The pads, the court's halves, a ring under every
  kaiju, the placing board, the battle bar and the result all use the two
  sides' colours.
- **REMATCH.** Both press it within 12 seconds of the result and you go
  again, on the same court, for the same stake.
- **COACH-4.** A guide robot on the balcony explains battles, placing,
  the kinds of kaiju, elements and stakes, and gives a battle tip whenever
  you ask.

Subtle yellow arrows on the floor lead you where to go: to the stairs when
someone's waiting downstairs, to a free pad once you're there, and through
the Rift's caves.

![The way down from the Shelter, the hall from the balcony, from above, and a court's corner](kaiju-arena/hall.jpg)

The 3D pictures are offline renders of the parts the server builds
(`Server/World/KaijuPitWorld`, `Server/World/OutpostWorld`), drawn by the
trailer renderer. They are **not Roblox screenshots**: lighting, glass and
neon are only roughly matched, and the boards' and signs' text (SurfaceGuis)
isn't drawn. The screen shots are the real client code rendered by the UI
harness. A kaiju's portrait there is a stand-in gem, because the harness
can't draw a ViewportFrame's 3D model. In the game it's the kaiju's own
model.

## The way down

- **In the Shelter.** A stairwell is cut into the hall's floor on the west
  side, by the old arena stage. The stage's sign now reads **DOWNSTAIRS:
  TAKE THE WEST STAIRS**.
  - 13 steps go down to a landing and a lit doorway.
  - Over the doorway: **KAIJU ARENA / DOWNSTAIRS: KAIJU BATTLES**.
  - A rail runs round the other three sides of the well, with hazard
    paint round its lip.
- **Going down.** Walk onto the landing. A moment's cover (**KAIJU ARENA**)
  and you're on the hall's balcony, facing the courts.
  - Your kaiju come with you.
  - You can't take a mech down: "Hop out of the mech first: it won't fit
    down the stairs."
- **Coming back up.** The lit doorway behind the balcony (**UP TO THE
  SHELTER**) takes you back to the top of the stairs.
  - Walking up mid-battle forfeits it.
- **Where it is.** The hall is 150 studs under the Shelter, inside the Core.
  The frontier (critters, rifts, raids) leaves it alone, and so does the
  Outpost's "stranded" check.

## The hall

- **Size.** 216 × 160 studs and 36 high.
- **The balcony.** A deck along the north wall, 12 up, with a glass rail.
  A 20-step stair runs down off it to the floor. **COACH-4**, the arena's
  guide, stands on it by its kiosk (**ARENA GUIDE**), just to the right of
  where you arrive, facing you.
- **The courts.** Eight of them, in two rows of four, with wide aisles
  between. Each court has:
  - bleachers along both sides;
  - floodlights over it;
  - a board over it;
  - a pedestal by its side.
- **Signs.**
  - **KAIJU ARENA** on the north and south walls. The north wall's two say
    **STAND ON A PAD TO BATTLE** and **EVERY KAIJU FIGHTS AT FULL HEALTH**.
  - **STAND ON A PAD · WAIT FOR A CHALLENGER · 25 S TO PLACE YOUR KAIJU**
    facing you as you arrive.
  - **HOW IT WORKS** on the balcony's face beside the stairs, off the floor
    and out of the way.

## A court

- **The mat.** 34 × 22 studs, half blue and half red, with each side's six
  places painted on it and the court's number in the middle. Rails, and
  invisible walls on them, keep the kaiju in.
- **The pads.** A ring at each end: blue (A) to the north, red (B) to the
  south. A pad lights up while someone's on it.
- **The board** shows, on both faces:
  - **COURT n**;
  - what's happening: **OPEN**, **WAITING FOR A CHALLENGER**, **CHALLENGER
    STEPPED UP**, **PLACING** with its clock, **FIGHTING** with its clock,
    then **X WINS** or **A DRAW**;
  - both players' names, or "STEP ON THE BLUE PAD" for an empty one;
  - while they fight, each side's health left as a bar;
  - the stake: **250 COINS EACH · WINNER TAKES 500 COINS**.
- **The pedestal** shows the stake for everyone: a stack of coins, or the
  gem itself turning in its element's colour, with a **STAKE** billboard
  over it.

## Waiting, challenging, and stakes

![Waiting with coins; staking a gem; a challenger's card; matching a gem](kaiju-arena/pads.jpg)

**On a pad, waiting.** Your card reads **WAITING ON COURT n**. Choose
what to play for:

- **NO STAKE**.
- **50, 100, 250, 500 or 1000 coins**: only amounts you have.
- **A GEM**: opens your loose gems. Pick one to stake.

What you chose is spelled out (**YOUR STAKE: RARE THERMAL GEM**) and shown on
the board and pedestal. Only whoever got there first sets the stake. Step
off for a moment and your wait is over.

**On the other pad, challenging.** Your card reads **SAM IS WAITING** and
says what for: "For 250 coins each: the winner takes 500 coins."

- **FIGHT!** puts both stakes in and starts the battle on that court.
- **For a gem stake,** your gems that can match it are shown, weakest
  first, and you pick one. A match is the same rarity or better.
- **If you can't match it,** the card says why: "You need 1000 coins to
  match the stake." or "You need an Uncommon gem or better to match the
  stake." FIGHT stays dark.
- **Saying no:** step off the pad.

The waiting player is told "Sam stepped up. Place your kaiju!"

**The stakes are safe.**

- Both stakes are taken in at FIGHT: coins off both, gems out of both
  pouches.
- Each is checked again just before. If one can no longer be covered, the
  other is given straight back.
- The winner takes both. A draw gives each their own back.
- If the server closes mid-battle, both stakes are returned.

## Placing your kaiju (25 seconds)

![The placement board: your half of the court, your three kaiju, the clock](kaiju-arena/placing.jpg)

![On a phone, in English and in Spanish](kaiju-arena/placing-phone.jpg)

**PLACE YOUR KAIJU**, against whom, the stake, and a big countdown with a
bar draining toward the fight.

- **Your half of the court**, drawn as you see it: three places in the
  front row, three behind, each showing the kaiju in it with its portrait.
  **Your foe's side stays hidden till the fight.**
- **Your three kaiju as cards:**
  - its portrait, name, level and role (FRONT LINE or SHOOTER);
  - its health;
  - where it stands now.
- **Moving them.** There are two ways:
  - **Drag** a card, or a kaiju already on the court, onto a place. A
    ghost follows your finger or mouse and the place under it lights up.
    Drop it onto another kaiju and the two swap.
  - **Tap** a kaiju, then a place.
- **Your side.** A pill by the clock says **YOU'RE BLUE** or **YOU'RE RED**.
  Your half of the court is drawn in your colour (**YOUR SIDE: BLUE**), your
  foe's in theirs, and the places on the ground too.
- **Full health.** Every kaiju on your team is here, at full health, even
  one that was knocked out before.
- **AUTO** puts them back in the default (the sturdy ones in front, a
  Razorback behind).
- **READY** from both of you starts the fight at once. When your foe is
  ready first, the hint says so.
- **LEAVE** forfeits.

## The battle

![The battle camera's view of a court: BLUE's half nearest, each kaiju on its side's ring](kaiju-arena/overview.jpg)

(An offline render of the hall's parts and the game's own kaiju models, seen
from where `KaijuBattleCam.view` puts the camera, with the rings at their
code's size and colours. It isn't a Roblox screenshot.)

![The battle bar: on a desktop as BLUE, on a phone as RED](kaiju-arena/battle.jpg)

- **The camera.** When the fight starts, the camera rises over your end of
  the court, 25 studs back and 17 up, and looks down on the whole court:
  your kaiju nearest, your foe's beyond. It eases in, leans a little after
  the fight as it moves, and stays inside the hall whichever court you're
  on (`Client/KaijuBattleCam`).
  - **Drag** (the right mouse button, or a finger off the thumbstick) to
    swing round the court, up to 60° either way.
  - **Scroll or pinch** to come in or back a little.
  - It stays on through the result, and gives you your own camera back
    when the battle's gone, or as soon as you're well away from the court
    (up the stairs, say).
- **The lobby HUD steps aside.** While you're in a battle, the lobby's
  buttons hide, so the court and the battle's own bar and result have the
  screen.
- **On the court.** Every kaiju starts at its place, facing the other side,
  and fights by itself as before (`KaijuFighter`).
- **Rings.** Each kaiju in a battle stands on a ring in its side's colour:
  a bright rim round a darker fill, a little wider than the kaiju
  (`Client/KaijuTeamRings`). Everyone sees them, players and onlookers
  alike.
- **Kept in.** A kaiju that strays past the court's edge walks back in. One
  more than 3 studs out is put straight back.
- **The bar at the top:**
  - a face and health gauge for each of the six kaiju, yours on the left,
    each outlined and filled in its side's colour;
  - **YOU'RE BLUE** or **YOU'RE RED** over the clock, in your colour;
  - the clock;
  - what you're playing for (**FOR 500 COINS**).
  - It's sized to clear the lobby's side panels on a desktop and to fit a
    phone.
- **Watching.** Anyone downstairs can watch from the aisles, the bleachers
  or the balcony. The board shows both sides' health.

**Who wins** is decided as before: the side with kaiju still standing, or
the one with more health left when time runs out. Walking off the field,
going back upstairs, leaving the Outpost or the game, or LEAVE all hand the
other side the win.

**After it.**

![The result: VICTORY with a rematch asked for, DEFEAT waiting on the other, in Spanish, and no rematch](kaiju-arena/result.jpg)

- **VICTORY, DEFEAT or DRAW**, then **BLUE WINS** or **RED WINS** in the
  winner's colour (**NEITHER SIDE WINS** for a draw), and the EXP.
- **KAIJU HEALTH BACK TO BEFORE THE MATCH**, for both of you.
- **What happened to the stake:** **YOU WON 500 COINS**, **YOUR STAKE IS
  THEIRS** or **STAKES RETURNED**. The winner is also told "You won 1000
  coins!" or "You won Sam's Rough Plasma Crimson (Thermal)!", and the loser
  "Sam took your …".
- **REMATCH.** The result stays up for 12 seconds (the bar's clock counts
  them down), with a **REMATCH** button and what it would take: **FOR 250
  COINS**, or the gem of yours that would go in.
  - Press it and it reads **WAITING FOR SAM**. Sam is told "Marc wants a
    rematch!" and sees **MARC WANTS A REMATCH!**, the button lit gold.
  - Both pressed: the stakes are taken again and you're straight back to
    placing, on the same court, on the same sides, every kaiju full again.
  - A gem stake is matched again with a gem each as rare as the first: your
    weakest loose one that is.
  - **No rematch** when one of you closes the result or leaves ("No
    rematch: Sam left."), or can't cover the stake ("No rematch: Sam can't
    cover the stake."). Whoever pressed first gets their stake back.

**CLOSE** puts the result away. To go again with someone new, step off your
pad and back on.

## Full health, and back

A battle never costs your kaiju health.

- **When it starts** (`KaijuServer.battleStart`), each kaiju on both teams
  has its health kept on its record (`BattleKeep`, saved with your kaiju).
  Then all of them are brought to full, and one that was knocked out comes
  back out for the battle.
- **A kaiju knocked out in the battle** is out of it quietly. There's no
  "knocked out" notice and no critter raid for a team all down, and no
  revive timer starts.
- **When it's over** (`KaijuServer.battleEnd`, as the result appears), each
  goes back to exactly the health it had before, win or lose. One that was
  knocked out before is down again, with the same wait as before.
- **If something cuts it short**, the kept health is put back anyway. That
  covers leaving the game mid-battle or a server shutting down. Your saved
  kaiju still carry what they had, and the next time the server looks at
  your team, out of a battle, they're put back.
- **A revive bought during a battle** applies to the kaiju as it was before.
- **What you need to battle** is your kaiju out (not put away). Knocked-out
  ones count, since the battle brings them back for itself.

## COACH-4, the arena's guide

Talk to it (E) on the balcony (`Shared/Vendors.ArenaGuide`). Like INFO-9
upstairs, its answers keep to the game's rules.

- **Give me a battle tip:** the next of 15 tips, from a random start.
  - **Elements:** Thermal beats Cryo, Cryo beats Ion, Ion beats Corrosive,
    Corrosive beats Thermal.
  - **Damage:** 125% from the element that beats a kaiju's own, 75% from its
    own.
  - **Kinds:** Carapaces shrug off a quarter of each blow and Bulwarks a
    tenth; a Razorback shoots from the back row.
  - **Time and READY:** out of time, more health left wins; press READY
    to start at once.
  - **Other tips:** REMATCH, the camera controls, EXP for each result, Q
    at level 5 and R at level 10, hidden places, and watching.
- **How battles work:**
  - starting one;
  - what happens in one (25 seconds to place, up to 90 to fight, who wins);
  - full health and back;
  - the rematch.
- **Placing and elements:**
  - front row or back row;
  - how to place;
  - which kaiju is which;
  - which element beats which, and by how much.
- **Sides, stakes and rewards:**
  - which side you are, and the camera;
  - what you can play for;
  - who gets the stake (only loose gems, never your gear's);
  - EXP: 40 for a win, 24 for a draw, 14 for a loss.

## Asking from a player card

**KAIJU** on another miner's card still works. Once they accept, you're
both brought down to a free court and onto its pads, and the battle runs
there like any other. If every court is taken: "Every court in the Kaiju
Arena is taken. Try again in a moment."

## Yellow arrows on the ground

![The arrows from the foot of the stairs to a free court's pad](kaiju-arena/arrows.jpg)

A short trail of yellow chevrons on the floor (`Client/GroundGuide`):

- They start a few studs ahead of you and drift the way to go.
- They fade in and out at each end, and they're see-through, so they're
  easy to ignore.
- They follow the floor, take the way round walls (PathfindingService, or
  straight there when there's no path), and go away when you arrive.

Where they lead, the first of these that wants you somewhere:

| Where you are | They lead to |
| --- | --- |
| Downstairs | The free pad across from someone waiting. Just after you arrive (18 seconds), the nearest open court's pad. Nothing while you're on a pad or in a battle. |
| In the Rift | Through a wall of fire that's just gone out (15 seconds), and to the way home once the boss is down. |
| In the Shelter | The stairs down, for 25 seconds after someone starts waiting for a challenger downstairs. A toast says "Sam is waiting for a kaiju battle downstairs. Follow the arrows!", at most once a minute. |

## Files

| File | What |
| --- | --- |
| `src/shared/KaijuPit.luau` (new) | The rules: the hall, the courts and where they are, pads, where you arrive and leave, in a court or the hall, keeping a kaiju in, stakes (what you can stake, why a challenger can't match it, their gems that can, what's said), the pot |
| `src/server/World/KaijuPitWorld.luau` (new) | Builds the hall under the Shelter: walls, roof, balcony and stairs, the way up, signs, lights, COACH-4's kiosk and spot (`Guide`), and each court (mat, places, rails and keep walls, pads, board, pedestal, bleachers, floodlights) |
| `src/server/Systems/KaijuPitServer.luau` (new) | The stairs both ways, the pads, waiting and challenging, stakes in and paid out, the boards' attributes, bringing a card's battle down to a court, refunds on shutdown; a rematch's stakes taken again; COACH-4 built on the balcony |
| `src/server/Systems/KaijuBattles.luau` | Battles on a court (its field, `Bounds`), `findCourt`, `onOver` (the payout), `inPit`, full health and back for both sides (`KaijuServer.battleStart` / `battleEnd`), each kaiju marked with its side (`KaijuTeam`), the rematch (`KaijuBattleRematch`, `KaijuBattles.again`, `rematchOn` / `rematchCost`), the stake in what the client is sent |
| `src/server/Systems/KaijuServer.luau` | A battling kaiju kept inside its court; `battleStart`, `battleEnd` and `battleable`; the kept health (`BattleKeep`) put back after a rejoin; quiet knockouts in a battle |
| `src/shared/KaijuBattle.luau` | 25 seconds to place, 12 for the result (and a rematch), the sides' names and colours (`Sides`) |
| `src/client/Modules/KaijuBattleCam.luau` (new) | The overview camera: where it looks from (`view`), easing in, leaning after the fight, dragging and zooming, handing your camera back |
| `src/client/Modules/KaijuTeamRings.luau` (new) | The ring under each kaiju in a battle, in its side's colour |
| `src/client/Lobby.client.luau` | Starts the rings; the lobby HUD hides during a kaiju battle |
| `src/client/Dialogue.client.luau` | COACH-4's tips (`ArenaTip`) |
| `src/server/World/OutpostWorld.luau` | The Shelter's stairwell (the floor, hall and keel built around it), its steps, rails, signs and door; the stage's sign |
| `src/server/Systems/OutpostServer.luau` | Downstairs isn't stranded |
| `src/client/Modules/KaijuBattleUI.luau` (rebuilt) | The placement board (drag and drop, portraits, cards, AUTO, READY, the clock, your side), the battle bar (by side), the result card (who won, health back, REMATCH) |
| `src/client/Modules/KaijuPitClient.luau` (new) | The courts' boards, lit pads, the stake on the pedestal, your pad's card, the crossing cover, the toast upstairs |
| `src/client/Modules/GroundGuide.luau` (new) | The arrows on the ground |
| `src/shared/Vendors.luau` | INFO-9's tips: where battles are now, 25 seconds, full health and back, stakes. COACH-4 (`ArenaGuide`) and its tips (`ArenaTips`) |

A player downstairs carries `KaijuPit` (and keeps `Outpost`). Each
court's model carries what its board shows (`State`, `AName`, `BName`,
`AId`, `BId`, `Stake`, `StakeKind`, `StakeCoins`, `StakeTier`,
`StakeElement`, `StakeGem`, `Pot`, `Phase`, `EndsAt`, `AShare`, `BShare`,
`Winner`). The client is told about its pad and the stairs on the Social
remote (`KaijuPitPad`, `KaijuPitCross`), and asks with `KaijuPitStake` and
`KaijuPitFight`. In a battle, each kaiju's model carries its side
(`KaijuTeam`: `A` or `B`), the battle's state carries `Restored` and
`Rematch` (`{ A, B, Off, Cost }`), and the client asks for a rematch with
`KaijuBattleRematch`.

## Spanish

Everything above is in `Shared.LangEs`: the placement board, the battle bar
and result (the sides, the rematch and why there isn't one), the pad cards,
the stakes (each rarity's wording), the server's messages, the toast, the
courts' boards, and everything COACH-4 says. The boards are in the
world, not on screen, so the client translates them itself. The hall's
signs (and COACH-4's kiosk) stay in English, like the Shelter's. Gem names stay in English: they're
names.

## Tests

| Suite | What it checks |
| --- | --- |
| `run_kaiju_battle` (`kaiju_battle_cases`) | The arena's rules: eight courts in two rows, inside the hall and the Core, clear of each other and of the stairs, every place inside its court; the pads; arriving on the balcony facing the courts; a stray kaiju clamped back in; the nearest pad; what can be staked; matching coins and gems (same rarity or better, weakest first); what's said ("an Uncommon gem each"). The arrows: spaced along the way from just ahead of you, facing along it, never past its end, round a corner, flat on a slope; each chevron points the way it leads; subtle. The sides: BLUE and RED, a ring a little wider than its kaiju. The camera: for every court and side, swung either way and zoomed in or out, it stays inside the hall, over your end, past the floodlights and looking down, with all twelve places in view on a 16:10 screen below the battle bar |
| `run_kaiju` (`kaiju_server_cases`) | The arena on the server: down the stairs and back up; COACH-4 on the balcony, off the stairs, facing you; pads, the stake and the board; a challenger who can't cover it, then FIGHT; every kaiju of both teams at full health (one knocked out brought back), each marked with its side; 25 seconds to place, every kaiju placed inside its court, a stray one put back; the fight on the court; afterwards every kaiju back as it was (the hurt one hurt, the one down before down again with the same wait), no raid for a team knocked out in it, both told; the coins paid out (1250 and 350); the board's winner; a rematch (asked, told, both, the same court and sides, the stakes taken again, everyone full again), forfeited, then refused when one can't cover the stake (the asker's coins back) and ended when one closes; the court freed and the sides unmarked; stepping off and back on; a gem stake; walking upstairs forfeits; the winner gets both gems; a kept health put back by itself out of a battle; a card's battle brought down to a court. The older open-field battle: the losers' kaiju back as they were |
| `run_outpost` (`outpost_cases`) | COACH-4's dialogue fits the dialogue's rows, its tip action exists, and all of its lines and tips are in Spanish |
| `run_moon_quarry_scene`, `run_shelter_life` | The Shelter with its stairwell: spawn, stations, the stage and its hologram, the part budget |
| `run_lang` | Every new Spanish entry follows the rules |

None of this has been played in Roblox Studio. Before publishing, play a
battle on a court with two players, on a desktop and a phone, and check:

- the camera takes over when the fight starts, drags and zooms, and hands
  back cleanly after the result, after CLOSE and after walking upstairs;
- the rings follow the kaiju on the court's floor;
- the health comes back right after a win, a loss, a forfeit and a rejoin;
- a coin rematch and a gem rematch.
