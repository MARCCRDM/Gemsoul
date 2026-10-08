# Objectives: permanent tasks

19 tasks across Mining, Equipment, Combat, PvP, PvE and Market. These replace the nine-row Training panel while preserving existing completion IDs and rewards. Weekly tasks and a dedicated Missions screen are not part of this update.

## Experience
- Open Objectives in the Outpost to go directly to the first unfinished task page.
- Tasks shows the first unfinished page and advances automatically when its objectives are complete.
- Rewards arrive automatically once per account. No claim button or forced task order.
- The panel fits the viewport, task cards scroll vertically, and action buttons have 44px touch targets.
- Hide the HUD during combat, guided tutorial, and Inventory to avoid overlays.

## Award rules
Existing nine learning rewards remain unchanged (290 coins total). New tasks: mined gem 25, Rare-or-better find 60, Legendary find 150, timed block 40, completed player 1v1 40, first player 1v1 win 100, boss defeat 125, dungeon completion 100, Market purchase 35, Market sale 75. Total catalog: 1,140 coins per account.

Mining rarity rewards require a real mining drop; higher rarity can complete both rarity milestones. Boss credit goes to living party members in the encounter; developer dungeon tests do not count. Dungeon completion uses the existing living-member reward eligibility. Sale credit occurs when a sold listing is settled, never on listing creation, cancellation, refund or expiration. Purchases exclude the scripted tutorial Market. No history backfill is inferred for existing profiles.

## Verification
Pure Luau reward tests cover duplicate payouts, stable old rewards, unique equipment slots, saved/rejoined profiles and any-order completion. Compile and Rojo build validate source integration. Studio/device visual testing remains necessary: small landscape phone, portrait phone, desktop, category navigation, saved tracking, Market mailbox settlement and a real dungeon clear.

## Sequential Tasks UI
Objectives opens the task checklist directly, starting with Mining and resuming at the first unfinished page. The Tasks/Missions selection and Back navigation have been removed. Tasks has no filters, category tabs, or tracking. It displays the first unfinished page in Mining, Equipment, Combat, PvP, PvE, Market, Discoveries order. Rare and Legendary finds belong to Discoveries so luck does not block basic learning. All current-page items remain visible until completion, then the view advances and scrolls to the top. Previously earned later-page credit remains valid. The tracking endpoint is removed; old saved tracking fields are ignored.
