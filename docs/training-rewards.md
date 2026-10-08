# Training rewards v1

Optional, permanent, account-wide learning achievements. Automatic coin delivery; no claim remote, no repeatable payout, no imposed order. Progress begins with new successful actions after this feature is installed; historic activity is not guessed or retroactively paid.

| Objective | Confirmed action | Coins |
|---|---|---:|
| First discovery | Break one real Outpost rock | 25 |
| Keep digging | Break three real Outpost rocks | 35 |
| Power up your gear | Successfully enchant gear through the player socket action | 25 |
| Build your loadout | Enchant three distinct equipment slots | 50 |
| Ready a Surge | Successfully equip a Surge through the player socket action | 20 |
| Make contact | Land a light/heavy weapon attack | 20 |
| Stand your ground | Guard absorbs damage from an incoming hit | 35 |
| Unleash your gem | Successfully begin a validated Surge cast | 30 |
| First Rival victory | Defeat a Rival in practice or Arena | 50 |

Total: 290 coins per account. TrainingRewards.Counts, Slots and Paid live with the same profile as Coins, protected by the existing save/session ownership system. Developer intro restart does not clear this ledger. Automatic starter equipment does not earn manual-enchant objectives.

The TRAINING button in the Outpost lists progress, concise action hints, reward amounts and paid status. It hides during combat, the guided tutorial and Inventory to avoid overlay clutter. The first incomplete objective is suggested on the collapsed button. Closing the list does not interrupt progress.

This change does not implement the proposed illustrated intro/lottery or Legendary discovery milestones; this is the requested initial training achievement track. Studio desktop/touch visual testing and publishing remain separate.

Checks: tests/run_training_rewards.py; tests/run_combat.py. New rules are also compiled with the bundled Luau compiler and included by the Rojo project.
