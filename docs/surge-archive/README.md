# Surge archive (before the Attack / Defense / Shift rework)

Everything about the surges and rig maneuvers as they stood before the rework,
kept so nothing is lost. The rework adds to the catalog; it does not delete.

| What | Where |
| --- | --- |
| Every ability: numbers, element, rarity tier, base / variant / resonance line, icon cell, every file that uses it | `legacy-surges.md` (readable), `legacy-surges.json` (full data) |
| Behaviour (code) | `src/shared/CombatTechnology.luau`, `src/shared/CombatActions.luau`, `src/server/Systems/CombatServer.luau`, `src/client/Combat.client.luau` |
| How gems roll them | `src/shared/GemRoller.luau` (`Surges`, `SurgeVariants`, `Resonance`, `ResonanceVariants`) |
| Icons | `assets/images/ability_icons.png` (cell = `Icon` in the inventory), map in `src/client/Modules/AbilityIconAtlas.luau`, made by `tools/make_ability_icons.py` |
| Effects and sounds | `src/client/Modules/CombatVfx.luau`, `CombatFx.luau`, `CombatSound.luau`; `assets/sounds/combat/` |
| The exact code and assets | commit `88a6299` on `main` (local tag `surges-legacy-v1`) |

Rules during the rework:

- An archived ability is never deleted. It is kept, repurposed into a new
  ability or facet, or retired from mining (no longer rolled) while still
  resolving, so gems players already own keep working.
- `tests/run_legacy_surges.py` fails if any archived id, its name or its
  icon disappears.
- To regenerate the inventory: `lune run tools/archive_surges.luau .`
- To see or restore the old version of any file:
  `git show 88a6299:<path>` or `git checkout 88a6299 -- <path>`.
