# First steps: the NEXT STEP card

New players were dropping between finding their first gem and socketing it
(the onboarding funnel, Creator Dashboard > Analytics > Funnels: step 9
"Socketed" lost half). Nothing on the play screen said what to do with a gem:
the Tasks list only opens from its menu tile, and on a phone the lobby's side
board is off the screen.

## The card

`Client/Modules/FirstStepsCoach.luau` (rules: `Shared/FirstSteps.luau`): one
card at the top of the play screen, for accounts the funnel counts, after the
first fight, until their second duel:

| Step | Card | Button |
|---|---|---|
| 1 | BREAK A GLOWING ROCK | HOW? (a toast) |
| 2 | SOCKET YOUR GEM | SOCKET IT: EQUIP BEST, the best gems into your gear |
| 3 | READY A SURGE | SET IT: UPGRADE SURGES |
| 4 | TRY YOUR GEMS IN A DUEL | PLAY: the PLAY menu |

Steps 2 and 3 wait for something to put in (UpgradeHints), and are skipped
when there's nothing better. It pops each time the step changes (the first
gem landing reads as "now socket it"), hides under any window and the PLAY
menu, and × hides it for the session.

## Counting auto-socketed gems

AUTO EQUIP, EQUIP BEST and UPGRADE SURGES (Server.Forge) socketed gems without
counting them: no Tasks progress or coins, and no funnel step (Socketed,
Surge ready). They now count exactly like a gem dragged in
(Server.Enchanting). Part of the step 9 drop was players who used EQUIP BEST.

## Tests

`python3 tests/run_first_steps.py` (the card's order and who sees it),
`python3 tests/run_auto_equip.py` (auto-socketed gems count).
