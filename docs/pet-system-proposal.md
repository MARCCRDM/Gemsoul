---
title: Pet System Proposal (v1.5 draft) — Alien Critters of the Outpost
summary: Marc's Oct 13 request formalized - alien animals roam the lobby, capturable through a sneak-and-lure minigame. Species catalog (12 launch critters), bonding via Gem Dust (a new junk-gem sink), pet roles (companion/sniffer/forager/guard), channels (capture is free play, accessories are store, tradeable pods are Market), and hard rules keeping pets out of PvP math. Concept art in repo docs/pet-concepts/.
---

# Pet System Proposal — Alien Critters of the Outpost (v1.5 draft)

**Status:** Superseded by [kaiju.md](kaiju.md): mini kaiju replace the critter pets.

**Earlier status:** Proposal for discussion — nothing Adopted until Marc signs off. Extends [authoritative-spec.md](authoritative-spec.md) v1.4. Concept art: `docs/pet-concepts/` in the Gemsoul repo (6 renders).

## 1. Why pets, structurally

Three gaps pets fill at once:

1. **The lobby is dead air.** It's a menu with matchmaking buttons. Roaming, capturable critters turn it into a *place* — players linger between matches, and lingering is where social pressure, envy loops, and "wait what's THAT" moments live.
2. **Junk gems need a third sink.** Fusion and Recut eat surplus stones, but the lowest-tier commons are still near-worthless. Feeding pets **Gem Dust** (milled from junk stones) makes every mined Common matter — the "27 Commons = 1 Ultra Rare" story gets a companion: "or feed your fox."
3. **The collection layer is missing.** Skins are the fashion layer; pets are the *companion* layer — a second collectible vertical that never touches combat math, so it monetizes without ever being pay-to-win.

## 2. Hard rules (non-negotiable)

1. **Pets never grant combat stats.** No damage, no resist, no Charge, no cooldowns, no crit — in PvP or PvE. A pet is never a build choice. In duels, your pet auto-perches on your shoulder/pack (pure cosmetic, still visible for the envy loop) and cannot be targeted.
2. **Capture is play, not pay.** Species are never sold for Robux. What's sold is fashion (accessories) and convenience (extra active slots).
3. **Faucet discipline:** Forager coin trickle is capped daily and joins the rival-duel anti-farm curve as a stage-4 simulation input. Pets must not become a bot farm.
4. **Element colors stay sacred:** a pet's palette hints at its origin habitat, but pets never affect element scouting — they're scenery in bracket reads.

## 3. Finding critters in the lobby

**Habitats:** the lobby has five micro-habitats, each spawning its own species pool: the **Garden Bay** (bio-dome corner), **Cargo Crates** (loading zone), **Vent Field** (floor grates), **Garden Overlook** (upper catwalk), and the **Deep Bench** (shadowed lower lounge). Species spawn on a table per habitat with a soft day/night cycle (server-time windows — the "night-only" species gives the lobby a time-of-day texture with zero new art).

**The capture minigame (skill-gated, not shop-gated):**
1. **Spot** — critters idle near their habitat. Rare ones flee at a longer detection radius.
2. **Sneak** — crouch-walk to close distance. Walk normally and it bolts (despawns for 3-10 min).
3. **Lure** — toss a **Gem Dust biscuit** (milled from any junk gem, 3 Dust each) into its path. The critter approaches cautiously.
4. **Toss** — a timing-bar throw of the capture net: hit the sweet zone. Commons have a wide zone; Legendary has a razor-thin one and a 2-attempt limit before it flees.
5. **Bond intro** — captured critter lands in your **Stasis Pod** (pet inventory); first feeding unlocks its name.

Failsafe: nothing is missable forever. Fled critters respawn on their habitat's timer; a species you *saw* gets a Pokédex-style entry ("Spotted: Frostkit — Vent Field, night cycle") so the hunt continues on a later pass.

## 4. The launch species catalog (12)

| Species | Rarity | Habitat | Behavior / capture difficulty | Pet role |
|---|---|---|---|---|
| **Pebble Crab** | Common | Crates | Sits still; wide timing zone. The tutorial pet | Companion |
| **Vent Mouse** | Common | Vents | Skittish, short detection radius | Forager |
| **Dust Fluff** | Common | Deep Bench | Sleeps in shadows; must sneak | Companion |
| **Ember Fox** | Uncommon | Crates (day) | Circles the lure before committing | Sniffer |
| **Frost Kit** | Uncommon | Vents (night) | Freezes mid-approach if you move | Companion+ |
| **Static Moth** | Uncommon | Overlook | Hovers; throw timing is aerial | Sniffer |
| **Venom Grub** | Uncommon | Garden Bay | Slow but eats the lure — re-lure once | Forager |
| **Garden Squid** | Rare | Garden Bay | Sprays ink on fail (screen blur 2s) | Guard |
| **Moon Moth** | Rare | Overlook (night only) | The night-cycle chase; always flees on first approach | Sniffer+ |
| **Prism Worm** | Rare | Deep Bench | Reflects light — visible only via its glints | Forager+ |
| **Echo Hound** | Ultra Rare | Any (after a boss kill that session) | Requires biscuit + a 3-hit timing chain | Guard |
| **Voidmaw** | Legendary | Vents (night, 0.5% spawn) | The white whale; 2-attempt razor zone, flees 30 min | Companion++ (all flourishes) |

Rarity here = capture difficulty and flourish quality, **never** utility power (roles stay flat — see §5). "++" species get richer idle animations and trail options, not stronger effects.

## 5. Pet roles (utility that can't become power)

All utility is **out-of-combat only**, flat potency (no rarity scaling), one active pet at a time (extra active slots are a store convenience):

| Role | What it does | Where it works |
|---|---|---|
| **Companion** | Follows you, lobby trail particles, shoulder-perch in duels | Everywhere (cosmetic) |
| **Sniffer** | Points/paws toward the nearest ore vein pulse when you enter the mine | Mining only |
| **Forager** | Scavenges a small capped coin trickle while you're in the lobby (idle reward) | Lobby only, daily-capped |
| **Guard** | Barks/glares when a hostile mob or sneak-player is near in dungeons | PvE only (alert, no combat) |

A pet's role is fixed per species — no respec needed, no meta optimization, deliberately simple.

## 6. Bonding — the Gem Dust sink

Feeding a pet Gem Dust raises **Bond 1→5**: 1 = follow unlocked, 2 = role unlocked, 3 = name + idle flourish, 4 = trail particle option, 5 = species "ultimate flourish" (Voidmaw hums with the mine's ambient score; Ember Fox's tail flame trails during victory poses).

Dust economics: 1 junk gem → 5 Dust (milled at any pet bench); a biscuit costs 3 Dust; bond-to-5 costs ~150 Dust ≈ 30 junk gems per pet. Twelve species fully bonded ≈ 360 junk gems of demand — real absorption for the Commons tier that Fusion barely touches. (Numbers = stage-4 simulation inputs, same as every other faucet/sink.)

## 7. Channels & monetization (mirrors the skin model)

| Channel | What | Price / rule |
|---|---|---|
| **CAPTURE (free)** | All 12 species, the whole minigame | Play only. Never purchasable |
| **EARNED** | FTUE grants a Pebble Crab pod after the starter bracket ("everyone leaves with a pet") | Free |
| **STORE (Robux)** | Pet accessories (hats, scarves, lanterns, mini family shields — R$20-60); **extra active-pet slots** (2nd R$150, 3rd R$300); Stasis Pod skins | Bound, giftable once |
| **MARKET** | Captured pets are tradeable as **Stasis Pods** (kept pet + bond level + accessories attached, dusted off). Seller-funded dropper-commission model applies | Tradeable |
| **EVENT** | One seasonal species per season (S1: **Lunar Hopper**, lunar frontier variant) | Never sold, never returns |
| **SEASON** | Pet accessory sets on the Lunar Frontier tracks | Track rewards |

Tradeable pets deserve a line of their own: a fully-bonded, accessorized Voidmaw pod is a top-tier Market good — the pet layer inherits the skin system's "play buys status" spine, and capture skill becomes a marketable profession (like boss supplying).

## 8. Social layer (the lobby payoff)

- **Petting:** you can pet anyone's active pet (hold E). Both players get a tiny "Bonded: petted [name]'s Frost Kit" toast. The cheapest social hook in the game.
- **Pods on display:** your lobby bench shows your 3 favorite pods — a display shelf players inspect, exactly like gear inspect.
- **Critter chatter:** pets emote ambient reactions (they notice duels ending, notice rare spawns, hide from Voidmaw).
- **v2 candidates (not v1):** pet races (staged lanes in the lobby, coin side-bets capped), critter photography mode, species pair-ups (two owners' pets play together → small shared Dust bonus, encouraging lobby mingling).

## 9. What this does NOT change

PvP math and normalization (pets perch, cosmetic-only), gem power rules (Gem Dust only mills junk stones; a socketed/milled boundary — socketed gems can't be milled, matching the migration rule's spirit), the no-crafting rule (milling is a sink, not a production chain — Dust makes nothing but biscuits and bond levels), boss/Market economies (pets are a new Market good, not a new faucet beyond the capped Forager trickle).

## 10. Open questions for Marc

1. **Do pets enter dungeons visibly in v1** (as cosmetic followers), or lobby-only until a polish pass? Cosmetic-only is the safe default.
2. **Species count at launch:** 12 feels right for coverage without art starvation; could ship 8 and add 2 per season. Your call.
3. **Should capture stats show on the pod** (times spotted, attempts, "first captured by [name]") — the engraved-name habit applied to pets? I think yes.
4. **Voidmaw:** keep as the 0.5% lobby unicorn, or tie it to a hidden quest chain (3 night-cycle hunts) for a guaranteed (but long) path? Lottery vs journey.

## 11. Concept art

Six renders in `docs/pet-concepts/`: ember-fox, frost-kit, static-moth, venom-grub, pebble-crab, capture-scene (the lobby sneak-and-lure moment).
