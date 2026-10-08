# Fast Loop onboarding

The existing mining/socket tutorial now continues through the full loop:

1. Five nearby personal rocks grant Thermal/Cryo/Ion Common gear gems, Common Ember Lance, and Uncommon Chain Lightning. Mining displays world bursts without the large reveal card.
2. Inventory opens on Gems; socket Chest, Sword, Shield with target highlights. Real rating gains flash; signature armor shows its actual enchantment effect instead of a fictional Health gain.
3. Equip Q then E. Close inventory; both icons remain visible while approaching the queue pad.
4. Personal glowing pad starts a server-timed three-second practice queue.
5. Practice partner: one hit, one slow blocked swing, Q finisher. Common sword kit, wooden weapon appearance, no shield. Charge supplied for the final lesson. Existing pod entrances and ability effects retained.
6. One-time 50 coins and Common Prospector chest reward. Return button fades back to Outpost.
7. PROBE-7 private Market stock: three Common pieces at 15 coins each, one tutorial purchase. Close Market, press PLAY. Mode gates open.

State and rewards are server owned. Reconnecting during Fight allows requeue; finished accounts are not restarted. Skip grants missing gems, Q/E if empty, and the one-time victory kit, and leaves practice. The older combat-only skip has its own request name to avoid overwriting onboarding Skip.

## Validation

Run `tests/run_tutorial.py` for ordered progression, reach checks, duplicate rewards, queue timing, Q/E requirements, purchase validation and skip. Run `tests/run_combat.py` for the existing combat regression suite.

Studio validation still required: fresh account on desktop and touch; complete each beat; reconnect during mining, inventory and fight; skip during fight; inspect wooden rival and Q impact timing; confirm PROBE-7 proximity and viewport layout. No live publishing is performed by this change.

The proposed beat estimates total 210 seconds (3.5 minutes); under three minutes remains a playtest target, not a measured claim.
