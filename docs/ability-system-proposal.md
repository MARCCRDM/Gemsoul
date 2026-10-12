---
title: Ability System Proposal (v1.5) — Three-Trait Stones and the Mandated Q/E/R Grammar
summary: Marc's Oct 12 proposal formalized - every stone carries three ability traits (Offense/Secondary/Defense) mapped to the mandated Q/E/R keys, each element gets a 5/5/5 ability catalog, rarity dictates output. Replaces the rolled-Kind system and triples gem demand.
---

# Ability System Proposal — Three-Trait Stones (v1.5 draft)

**Status:** Proposal for discussion. Nothing here is Adopted until Marc signs off. Where this conflicts with [authoritative-spec.md](authoritative-spec.md) v1.4, this page is *proposing the change*, not silently overriding.

**Marc's directive (Oct 12, verbatim intent):** three traits — offense, ability, defense — on Q/E/R. Sword has a special ability plus enchantment buffs. Defense can be active-while-tanking, absorbing, or a frozen shield wall. Each stone still has its 3 traits: a blue stone has an offense ability, a secondary ability, and a defensive ability. Every element needs 5 offensive, 5 secondary, 5 defensive abilities. Output % dictated by gem rarity, Common to Legendary. This is the gem-demand hook.

---

## 1. The one-line pitch

**One stone type. Three traits. Three mandated keys.**

Every elemental stone carries three abilities — one **Offense** trait, one **Secondary** trait, one **Defense** trait — and the *socket decides which trait is live*. Rarity scales all three. The Kind system (Core/Surge/Edge/Ward rolls) dissolves: there are no dead drops, because any stone powers any slot.

---

## 2. The mandated Q/E/R grammar

The three keys stop being "three surge slots" and become the combat grammar — fixed purposes, readable at a glance:

| Key | Lane | What it is | Resource |
|---|---|---|---|
| **Q — Offense** | Offense trait | The sword special: an always-available signature move (family weapon special). The socketed stone's **Offense trait** rides it as the elemental layer, plus enchantment buffs from grades. | Charge (low: ~30) |
| **E — Ability** | Secondary trait | The player's **chosen elemental surge** — the flexible slot. Secondary traits can lean offense, defense, or passive, so the E stone is a playstyle statement, not just a damage button. | Charge (mid: ~50) |
| **R — Defense** | Defense trait | The shield move: active while tanking — walls, absorption shells, resist-all stances, retaliation modes. **Frozen Shield Wall** is the archetype (Cryo R-trait). | Charge (mid: ~50) |

Why mandate the lanes: with Q always offensive and R always defensive, no build can stack three offense moves; the ceiling of any kit is bounded by design. Every player reads every opponent instantly ("their Q is Thermal, their R is Cryo — expect a wall"). This is the "limited but more balanced place" the directive asks for, achieved structurally rather than through tuning.

**Cost economy stays intact:** all three keys draw Charge, so turtling on R starves your Q — defense still has to be *earned through aggression*, the game's core loop. R moves have uptime/downtime (walls have HP, stances have durations) so defense is a window, not a state.

---

## 3. The stone: one element, three traits

A stone is now: **Element + Rarity + grades (Size/Clarity/Cut) + one ability from each lane.**

- Its **Offense trait** is drawn from that element's Offense catalog (5 abilities).
- Its **Secondary trait** from the Secondary catalog (5 abilities).
- Its **Defense trait** from the Defense catalog (5 abilities).

The existing grades keep their fixed meanings and map cleanly per lane:

| Grade | On an Offense trait | On a Secondary trait | On a Defense trait |
|---|---|---|---|
| **Size** | magnitude (damage, radius) | magnitude/effect strength | absorb amount, wall HP |
| **Clarity** | cooldown | duration/cooldown | uptime vs downtime |
| **Cut** | rider proc chance | proc/utility chance | trigger/retaliation chance |

**Rarity = output.** The existing formula carries over unchanged, per trait: `output = base × rank multiplier × Size multiplier × (1 + Core Power)`, with `cooldown = base × Clarity multiplier × (1 − Haste)`, total CDR still capped at 30%. A Common stone's Frozen Wall absorbs a sliver; a Legendary's stops a boss charge. The rarity bands already in the spec (points 2→5 Common … 12→20 Legendary; rank 1.00/1.25/1.50) apply to all three traits — **one Legendary stone is a Legendary Q, E, and R.**

### Socket map (recommended, replaces the 9-socket Kind map)

| Socket | Held by | Activates |
|---|---|---|
| Sword socket | Weapon | stone's **Offense** trait → rides Q |
| Kit socket | Chest (replaces the 3 surge sockets) | stone's **Secondary** trait → is E |
| Shield socket | Shield | stone's **Defense** trait → powers R |
| 4 armor sockets (helm/gloves/boots + 1) | Armor | **Core stat stones — unchanged** (Power/Vitality/Haste/Precision chassis layer) |

7 sockets total (down from 9), one stone type in 3 of them. Socket the same element in all three ability sockets → a mono-element kit with full attunement synergy. Mix them → reactions and coverage. **The stone is socket-agnostic:** move your blue stone from sword to shield and its frost slash becomes a frozen wall. Re-socketing, not re-rolling, is how players experiment.

### Attunement (recast)

Attunement now counts your three *ability-socket* stones: 2 matching elements = +10% resist, 3 matching = +20% resist and +10% to that element's Core stat (the Pure tier, rebased from 4 Cores to 3 sockets). Armor innate traits, 4-piece set bonuses, and armor base stats are untouched by this proposal.

---

## 4. The catalog: 60 abilities (4 elements × 5/5/5)

v1 ships 5 per lane per element. Later waves expand each lane — the catalog is the content pipeline. Drafts below; every number is a playtest starting point, not a promise.

### THERMAL — burn, pressure, explosion

**Offense (Q riders)**
1. **Cinder Arc** — wide fiery slash; cone burn on hit
2. **Meteor Thrust** — lunging stab; highest single-target burst
3. **Ashen Breaker** — overhead slam with small AoE explosion
4. **Flame Rush** — dash-through strike leaving a burning trail
5. **Solar Detonation** — charged point-blank blast; slow, huge

**Secondary (E choices)**
1. **Ember Storm** — pulsing burn aura around you (offense-lean)
2. **Wildfire Link** — mark a target; your hits spread its burn to nearby foes (offense-lean)
3. **Molten Core** — buff: sword specials gain +burn for 8s (offense-lean)
4. **Heat Sink** — passive: +Charge generation while a foe is burning (passive-lean)
5. **Flare Nova** — knockback burst around you (defense-lean)

**Defense (R moves)**
1. **Scorch Wall** — wall of fire; crossing enemies burn
2. **Retaliating Flame** — for 5s, blocks reflect damage + apply burn
3. **Mantle of Ash** — absorb shell; when it breaks, it explodes outward
4. **Pyre Guard** — stance: +resist-all while blocking, 6s
5. **Cauterize** — stance: bleeds/burns on you are cleansed on block

### CRYO — freeze, slow, armor

**Offense (Q riders)**
1. **Glacial Edge** — frozen slash; chill on hit
2. **Icicle Lance** — piercing ranged shard
3. **Frostbite Combo** — 3-hit flurry; each hit stacks chill
4. **Avalanche Slam** — ground-pound knockdown cone
5. **Shatter Strike** — bonus damage vs chilled targets (execution-lean)

**Secondary (E choices)**
1. **Rime Pulse** — AoE slow burst around you (defense-lean)
2. **Deep Chill** — buff: your next hit freezes (defense-lean)
3. **Frost Nova** — brief freeze of all nearby (control)
4. **Sleet Step** — speed buff leaving ice patches (mobility-lean)
5. **Cold Focus** — passive: cooldowns tick faster while no foe is within melee range (passive-lean)

**Defense (R moves)**
1. **Frozen Shield Wall** — the archetype: a hard ice wall with HP
2. **Frost Shell** — absorb shield; breaking it freezes adjacent attackers
3. **Chill Aura** — stance: enemies attacking you are slowed
4. **Glacier Guard** — stance: +resist-all and immune to knockback while blocking
5. **Snowblind Veil** — brief mist; enemies lose target on you

### ION — chain, speed, interruption

**Offense (Q riders)**
1. **Arc Slash** — crackling slash; hits chain to one nearby target
2. **Thunder Lunge** — teleport-stab to the nearest enemy
3. **Static Flurry** — rapid 3-hit combo with rising speed
4. **Voltaic Breaker** — slam that stuns in a small radius
5. **Storm Lance** — thrown bolt that chains on impact

**Secondary (E choices)**
1. **Overcharge** — buff: +Charge generation for 8s (economy-lean)
2. **Static Field** — zone: enemies casting inside are interrupted (control)
3. **Conduit** — passive: your blocks build Charge (defense-lean passive)
4. **Arc Sprint** — extended dash; next hit deals bonus shock (mobility-lean)
5. **Discharge** — knockback burst that interrupts active surges (defense-lean)

**Defense (R moves)**
1. **Aegis Field** — brief bubble that negates ranged hits
2. **Static Guard** — blocking builds a charge; release to stun the attacker (parry-style)
3. **Grounded** — stance: +resist-all and immune to stun while active
4. **Deflector Mode** — for 5s, reflect ranged attacks
5. **Circuit Shield** — absorb shield that chains damage back to attackers

### CORROSIVE — poison, rot, decay

**Offense (Q riders)**
1. **Rot Slash** — wound applying poison DoT
2. **Acid Spray** — cone that shreds resist
3. **Bile Smash** — splash leaving a rotting pool
4. **Venom Fang** — fast thrust; stacking poison
5. **Decay Driver** — drill strike; damage rises as target HP falls

**Secondary (E choices)**
1. **Corrosive Cloud** — lingering debuff zone (defense-lean)
2. **Envenom** — buff: next 3 hits apply poison (offense-lean)
3. **Blight Mark** — mark: marked foe takes +damage from all sources (offense-lean)
4. **Miasma Step** — dash leaving a poison trail (mobility-lean)
5. **Spore Bloom** — passive: poisoned foes that die spread a weak rot burst (passive-lean)

**Defense (R moves)**
1. **Toxic Bramble** — wall/zone poisoning enemies that touch it
2. **Corrosive Carapace** — absorb shield; attackers become corroded (+damage taken)
3. **Decay Aura** — stance: nearby enemies deal less damage
4. **Rot Ward** — stance: +resist-all; activating it cleanses one debuff
5. **Fetid Bulwark** — block mode: blocked hits stack poison on the attacker

**Design rule for the catalog:** every lane has exactly one passive-lean option, one mobility/control option, and the rest pure lane identity — so the E slot is a real spec choice, and R is never just "more mitigation" (Cryo's Snowblind and Ion's Static Guard bring counterplay texture).

---

## 5. What this changes in the existing system

| Current (v1.4 spec) | Proposed (this doc) |
|---|---|
| Kind roll at mining (Core 40 / Surge 30 / Edge 15 / Ward 15) | **Retired.** Stones roll element + rarity + grades only. Every drop is socketable somewhere. |
| Role-locked Q/E/R surge sockets (Strike/Guard/Shift) | **Replaced by mandated lanes:** Q=Offense, E=Secondary (chosen surge), R=Defense. |
| 9 sockets (4 Core, 3 Surge, 1 Edge, 1 Ward) | **7 sockets:** 4 Core stat sockets (unchanged) + 3 ability sockets (sword/kit/shield). |
| 12-surge catalog (4 elements × 3 roles) | **60-ability catalog** (4 elements × 5/5/5). Surge gems become lane traits. |
| Edge on-hit procs, Ward on-block procs | **Folded in:** Offense traits carry on-hit riders; Defense traits are the on-block layer. Proc math (20% + 1%/Cut) carries over. |
| Attunement: 2/4 matching Cores | **Rebased:** 2/3 matching ability-socket stones (armor Cores stay pure stats). |
| Fusion: 3 same-Kind-same-element → next rarity | **Same, simpler:** 3 same-element stones → 1 next-rarity stone; all three traits upgrade. 27 Commons → 1 Ultra Rare math unchanged. |
| Recut: changes Kind | **Repurposed:** changes the stone's *element* (keeps rarity/grades) — or retires if element-respec goes to Fusion. Open question. |
| Migration: Kind choice, seeded rolls, Re-Kind token | **Simpler migration:** every existing gem converts to a full 3-trait stone of its element at its rarity; its former Kind's lane keeps the ability it had, other two lanes roll within its band. No player loses anything; most gain two abilities. |

**What does NOT change:** Charge economy and the land-hits-to-earn loop; Stamina (heavy/block/dodge) and Perfect Release; PvP normalization (health/charge/stamina fixed; passive-lean E options disabled in Ranked like today's passive augments — R-lane moves are actives, so they stay legal); 30s pivot windows and preset-only swapping (a preset is now a stone loadout); boss pick-one drops and the Market; armor base stats, innate traits, and 4-piece bonuses; the rarity/grade formulas verbatim.

---

## 6. Why this fixes the gem economy (the hook)

1. **No dead drops.** Today a Ward gem for a player who wants offense is trash. Under 3-trait stones, every mined stone is potentially Q, E, or R gear. The 40/30/15/15 Kind odds — and all the junk-feeling they produce — vanish.
2. **Demand triples.** A mono-element build needs **three** same-element stones (Q, E, R sockets), each ideally at your best rarity. Where the old system sold players one perfect surge, this sells a set of three.
3. **The chase is legible.** "One Legendary stone = a Legendary Q, E, and R" is a sentence a 12-year-old understands and wants. Rarity now upgrades your *entire kit's element* — the cleanest hook in the game.
4. **Fusion gets a story.** Fusing isn't "make one gem slightly better," it's "upgrade all three of your moves at once."
5. **Market depth.** Stones are interchangeable across sockets, so the Market's inventory is all demand-side, all the time.

---

## 7. Balance guardrails

- **Mandated lanes cap degeneracy structurally:** no three-offense kits, no full-time turtle (R uptime windows + Charge costs), no passive stacking (max one passive-lean ability active; passives disabled in Ranked).
- **Resist budget:** R stances grant +resist-all while active (draft: 15%); stance + Attunement together cannot exceed 30% — one cap, shared, like today's CDR cap.
- **Wall HP scaling:** walls (Frozen Shield Wall, Scorch Wall, Toxic Bramble) have HP that scales with Size and rarity band; they block movement for both sides (no perfectly safe turtling — you're walled in too).
- **CC discipline (unchanged guardrail):** no trait grants hard stun longer than 0.75s; no trait grants unconditional immunity; interrupts (Static Field, Discharge) respect the 0.9s surge lockout.
- **Readability:** opponent inspect shows element per lane (Q/E/R colors), never the exact trait — scouting stays "what color is their wall," per the PvP thesis.

---

## 8. Open questions for Marc

1. **Do armor Core stat stones survive as-is** (Power/Vitality/Haste/Precision feeding the formulas), or do the 4 armor sockets also take 3-trait stones with traits converting to passive effects? Recommendation: keep Cores pure — one stone type with two jobs is how "one job per Kind" broke before.
2. **Does the sword special differ per family weapon** (Prospector/Skirmisher/Juggernaut swords), with the stone rider shared? Recommendation: yes — family identity stays on the gear, element identity on the stone.
3. **Recut's fate:** element-change or retirement?
4. **Starter kit under this system:** FTUE rolls sword/kit/shield stones of 2-3 mixed elements, C/B quality — same balanced-random rules, now with all three lanes visible in the reveal ("your sword freezes, your wall burns, your surge chains" teaches the grammar instantly).
5. **Vaulted 16 ability variants:** do any return as catalog entries (e.g. the *second wave* of 5-per-lane expansions)?

---

## 9. Migration summary (if adopted)

1. Spec bump to **v1.5**: this page replaces the Sockets row, Kind row, surge catalog row, and Attunement row of the decision table.
2. Engineering: one stone type; socket→lane activation; 60-ability static catalog; conversion script for existing gems (element + rarity preserved, former Kind lane keeps its ability, other lanes roll in-band).
3. Rollout order: prototype one element (Thermal) end-to-end on the aggressive style lane, then expand.
