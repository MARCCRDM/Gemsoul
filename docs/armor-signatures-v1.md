# Armor signatures v1

Eight launch signatures are defined in `src/shared/ArmorSignatures.luau`.
Each server-created armor roll stores Signature and SignatureVersion. Existing owned rolls migrate once without changing stats, affixes, finish, serial, ownership, or gems. Signatures travel with the saved roll through trades and market escrow. Weapons do not roll armor signatures.

## Launch pool

| Slot | Signatures |
|---|---|
| Helmet | Charge Gain, Countercharge |
| Chest (Armor) | Life Steal, Barrier |
| Gloves | Riposte |
| Boots | Stamina Refund, Pursuit |
| Shield | Guard Efficiency |

Seven later PDF buffs remain deferred. Existing family set tiers are retained.

## Strength

Rarity floor = (rarity - 1) * 5%, clamped to 0-20% of the Base-to-Max span.
Gem quality = average(Size, Clarity, Cut) / 10, clamped to 0-1.
Unenchanted = Base + (Max - Base) * rarity floor.
Enchanted = min(Max, Unenchanted + (Max - Unenchanted) * quality * (1 + matching affinity)).
Only the strongest matching defensive affinity on that piece contributes, capped at 20%; duplicate affixes never multiply together. Saved offensive affinities retain their existing weapon-gem function. Defensive affinity labels now describe signature enhancement. There are no extra perfect-gem behaviors. Ranked normalizes the signature to Common floor, 50% quality, no affinity boost.

Migrated armor sockets replace old bundled armor-gem effects and passive per-piece elemental resistance. Legacy unconverted rolls retain compatibility until migration. Weapon gems, the 36 Surges, and their rarity scaling remain intact.

## Combat rules

Life Steal uses actual HP lost and obeys anti-heal and healing-received multipliers; actual armor healing is capped at 15% max HP per rolling 10 seconds. Bonus armor Charge is capped at 30 per rolling 10 seconds. These caps do not include independent weapon or Surge effects.
Barrier: non-stacking, 3 seconds, 6-second cooldown, up to 15 absorption. It is separate from other shield pools and shown in shield status.
Stamina Refund: 10-30% of the actual paid dodge cost, once per dodge, only when an attack is avoided, 3-second cooldown. No refund for empty movement.
Riposte: timed-block window of 1.5 seconds, 4-second cooldown. Pursuit: heavy sword hit grants 2 seconds of movement, 6-second cooldown.
Only direct sword strikes trigger offensive signatures; reflected damage, Surge damage and damage-over-time do not. AI rivals share the same signature functions and caps.
Charge now starts at zero. Existing passive regeneration is retained; this update does not redesign Surge costs.

## Combat UI follow-up

Player Rig Maneuvers are retired in desktop/touch controls, guides, loadout panels and augment purchasing. Saved ranks remain available for the existing reset flow. Normal Rivals stop choosing maneuvers; dungeon/raid encounter moves remain boss mechanics.
One combat nameplate owns enemy health display and suppresses the legacy bar. Name and health are anchored in world-space above the head; status chips sit higher. Damage edges use a dedicated full-screen ScreenGui outside safe-area insets.

## Validation

Run `tests/run_combat.py`, `tests/run_equipment.py`, and `tests/run_combat_hud.py`. Compile changed Luau scripts and build the Rojo project. Studio/device visual playtesting is still required; these automated mocks do not render Roblox UI.
