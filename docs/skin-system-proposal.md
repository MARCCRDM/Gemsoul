---
title: Skin System Proposal (v1.5 draft) — Cosmetic Catalog, Channels & Pricing
summary: Marc's Oct 13 request formalized - full cosmetic skin catalog for Saga Miners: armor lines, weapon/shield skins, gem skins, trails and poses, each assigned an acquisition channel (free, earned, season, store, loot, market, event) with Robux price bands and tradeability rules. Concept art in repo docs/skin-concepts/.
---

# Skin System Proposal — the Cosmetic Catalog (v1.5 draft)

**Status:** Proposal for discussion — nothing Adopted until Marc signs off. Extends [authoritative-spec.md](authoritative-spec.md) v1.4 without touching any gameplay rule. Concept art for all 8 launch lines: `docs/skin-concepts/` in the Gemsoul repo.

## 1. Ground rules (from the adopted spec)

1. **Cosmetics only, ever.** No skin grants stats, traits, proc chances, cooldowns, or resistances. The moment a skin does damage, the Market and the Arena both break.
2. **Silhouette first.** A skin may restyle a family's armor but never blur the Prospector/Skirmisher/Juggernaut read — bracket identification ("who is the Juggernaut?") is the envy loop's fuel. Body-altering skins (petite/tall) are off the table for v1.
3. **Element colors are gameplay.** Element identity (orange/cyan/yellow/green) stays tied to socketed gems and their VFX. Skins may *theme* toward an element's look, but the gem's own glow color remains the scouting truth. This keeps the counter-cycle readable at all spending levels.
4. **Already adopted precedent:** Legendary surge **signatures** are cosmetic skin layers on base surges (name/model/VFX/audio only). This proposal is that rule, extended to everything else.
5. **Store policy stays staged:** direct-purchase cosmetics launch *with* the stage-5 Robux turn-on, priced from real data. Nothing here sells before the economy metrics hold.

## 2. The channels (one table, every skin belongs to exactly one)

| Channel | How you get it | Tradeable on Market? | Who it's for |
|---|---|---|---|
| **DEFAULT** | Owned by everyone from minute one | No | Baseline identity |
| **EARNED (free)** | Achievement-style grants (FTUE, milestones, veteran rewards) | No | Engagement & loyalty |
| **SEASON (free track)** | Lunar Frontier 30-level track, free side | No | Casuals who show up |
| **SEASON (premium track)** | Same 30 levels, paid side | No | The $5-8 commitment |
| **STORE (direct buy)** | Robux, permanent catalog | **Giftable once, not resellable** | The main revenue line |
| **LOOT (earned by play)** | Boss drops, deep-vein mining, Legendary fusion | **Yes — fully tradeable** | The player-run economy's luxury tier |
| **EVENT (limited)** | Tournaments, playtest, one-time windows | No (bound) | Scarcity, prestige, FOMO |

The one structural decision: **STORE skins are bound (one-time gift only); LOOT skins are fully tradeable.** Dev revenue stays intact, while loot cosmetics become Market luxury goods that make being a supplier even more of a profession — and the existing dropper commission applies to their first sale like any Market item.

## 3. Armor skin lines (v1 launch catalog)

Every line ships for all 3 families (Prospector/Skirmisher/Juggernaut), sold as single pieces *or* the full 5-piece line. Swapping a line keeps your stats, traits, and set bonus intact.

| Line | Look | Channel | Price / drop rate |
|---|---|---|---|
| **Standard Issue** | The default grey/navy kit | DEFAULT | Free, everyone |
| **Outpost Recruit** | Clean starter look, teal recruit patch | EARNED | Complete the FTUE starter bracket (free) |
| **Playtester 2026** | White/amber holo-weave, floating 2026 badge | EVENT | Play in the controlled test. Never sold, never returns — the original flex |
| **Lunar Frontier** | Moon-dust white, amber cracks, crescent emblem | SEASON premium | S1 paid track, plus one piece on the free track (taste the line) |
| **Stardust Duelist** | Silver/teal, constellation etching, star trail on dodge | STORE | R$250/piece · R$900 full line |
| **Void Baron** | Void-purple + gold trim, flagship premium line | STORE | R$400/piece · R$1,500 full line |
| **Bossforged (×4)** | One variant per boss: Sahur's ember plate, Tralalero's frost shell, Bombardiro's storm rig, Patapim's rotwood bark | LOOT | Boss pools can roll a cosmetic slot instead of an armor piece (~10% pool roll, rarity-weighted); fully tradeable |
| **Trim Tokens (ongoing)** | Accent recolors: swap trim/glow on any line you own | STORE | R$20-40 — the impulse tier |

Post-launch cadence: **one new STORE line per season** (alternating mid-tier and flagship), **one new SEASON line per season** (track reward), **new Bossforged variants** when bosses get variants. That's a self-refreshing catalog without content-starving v1.

## 4. Weapon & shield skins — "Forgelite" line

The sword and shield are the two most *seen* items in every duel, so they get their own line: four element-themed pairs (Flamebite, Frostrend, Stormguard, Venomcore) plus a neutral Prospector pickaxe-pair.

| Item | Channel | Price |
|---|---|---|
| Forgelite pairs (4 elements) | STORE | R$80 per sword+shield pair |
| **Bossforged weapon pair** (matching the boss that dropped it) | LOOT | Tradeable |
| Champion's Resolve (gold pair) | EVENT | Win a starter/mid bracket tournament |

## 5. Gem skins — the cheap-feeling-premium tier

Gem cosmetics ride the *stone itself* (they travel with the gem when traded — engraved names and all):

- **Faceted variants** (cut styles: Brilliant, Ember Cut, Deep-Step) — mining milestones, free, non-tradeable on the skin but the gem still trades.
- **Prismatic** (holographic refraction, the chase cosmetic) — **LOOT only**, deep-vein rare roll (~0.5% of stones), fully tradeable. The Market's Veblen good: a Prismatic Flawless Legendary is this game's Rolex.
- **Gem score frame** — S-grade and Flawless get a free card-frame glow upgrade automatically (earned, cosmetic, legible flex).

## 6. Trails, VFX & poses (fill the low & high ends)

| Item | Channel | Price |
|---|---|---|
| Stardust trail (movement particles) | STORE | R$60 |
| Boss-ash trail (element-colored, from the boss you beat) | LOOT | Tradeable |
| Meteor comet trail | SEASON premium | Track reward |
| Victory poses (pickaxe-rest, sword-plant, bracket-point) | STORE | R$40 each |
| Guard emotes (taunt *during* the pivot window — the mind-game tier) | STORE | R$40 each |
| Kill/shatter effect (your finishing blow detonates in your element's color) | STORE | R$100 |

## 7. Revenue shape & guardrails

- **Price bands:** impulse R$20-40 (trims/poses), core R$60-100 (weapons/trails), line R$250-400/piece, flagship R$1,000-1,500/line. Season premium track R$500-800 (industry-normal "battle pass" band).
- **Every channel has a free path:** defaults for everyone, FTUE + free track + loot for non-spenders. A player who never pays can still earn Recruit, Lunar free piece, Bossforged, gem faceting, boss-ash trail, Prismatic. **No "pay to look like a player" gap.**
- **Prestige is earned, not just bought:** Playtester 2026, Bossforged, Champion's Resolve, Prismatic, and S/Flawless frames can NEVER appear in the store. Money buys style; play buys status.
- **No loot boxes for money.** All LOOT cosmetics are earned by playing (boss kills, mining, fusion). Tradeable-on-Market is the monetization of loot goods — players transact, the dev doesn't sell the roll.
- **Scarcity discipline:** EVENT items never return (stated publicly); STORE lines are permanent except seasonal skins, which leave the store at season's end but remain tradeable if owned. One re-run per year maximum if ever.
- **Metric:** skins attach to the stage-5 turn-on — target: average session length up (showing off), ranked queue up (playing to be seen), zero impact on the 4 economy metrics (they're coins-neutral by design).

## 8. Open questions for Marc

1. Roblox **UGC creator skins** (player-made cosmetic submissions with revenue share) — in scope for later or never?
2. Should the **season premium track** be one purchase (R$500-800) or tie into the Core Battery pass as a bundle?
3. Do armor skin lines apply to **preset previews/inspect screens** for free (they should — the envy loop needs spenders' looks to be seen in bracket inspects)?

## 9. Concept art

Eight launch-line concepts (1024×1024, blocky low-poly amber/teal style matching the loading screens) are in the repo at `docs/skin-concepts/`: void-baron.png, stardust-duelist.png, lunar-frontier.png, bossforged-thermal.png, outpost-recruit.png, playtester-2026.png, forgelite-weapons.png, gem-skins.png.
