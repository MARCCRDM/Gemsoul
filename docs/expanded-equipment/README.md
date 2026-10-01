# GemSoul expanded equipment direction



## Delivered artwork

Seven concept sheets depict all 60 equipment designs and 10 visor treatments from the supplied matrix. The artwork uses human proportions, sculpted armor, worn metals, restrained emissive accents and original science fantasy designs. Generated with the built-in Image Generation tool.



These are concept images, not game-ready meshes. The Roblox equipment still uses existing procedural geometry mapped to the new identities. A sculpted 3D replacement needs modeling, retopology, rigging and Roblox asset import. The images are not automatically displayed in the live menu.



## Implemented new account draw

Each of the six equipment slots draws independently from its ten matrix entries. Roll rarity first, then pick either of the two entries in that rarity. Weights are Common 40%, Uncommon 25%, Rare 20%, Ultra Rare 10%, Legendary 5%. The source Rare weight was 15%; raising it to 20% completes the missing 5%.



All starting items use Standard quality. Rarity-specific bonus stats, a visor treatment, finish, helmet variant and panel variant are saved on the item. Helmet visor treatment controls its actual glow color and is shown in inspection. Existing accounts keep their saved loadouts; rejoining does not reroll. Each slot remains independently enchantable and tradable.



Seven equipment signatures are currently supported: Intableed critical chance, Metron cooldown reduction, Jutaim damage reduction, Cryo pistol slow, Radiation pistol vulnerability, Standard Sidearm base damage and Pulse-Laser fire-rate tradeoff. Radiation is an adaptation: the existing Sunder system grants +15% damage vulnerability per hit, up to +45%, for 5 seconds; it is not a literal 15% armor reduction. Other source signature effects are planned metadata, visibly labeled in the armory. Visor buffs are planned; the current visor feature is cosmetic.



## Recommended next design pass

Keep a complete usable starting kit for everyone. Mix families freely and reserve family identity for silhouette and lore rather than mandatory matching bonuses. Present the six rolled items in a short first-login reveal with a skip button, their actual active bonus and a clear rarity label.



Keep visor color cosmetic so a preferred color does not force a weaker build. Put elemental affinity on gems: Plasma, Cryo, Volt and Radiation. Distinguish a gem's affinity from an item's family color. Cosmetics and armor paint are suitable monetization; paid rarity rerolls would undermine fair starts and trading.



Before PvP, budget the total power of a starting kit. Higher rarity should add a distinctive choice, not stack several unrestricted advantages. Proposed starting targets are at most +10% critical chance from gear, 20% cooldown reduction and 20% combined passive damage reduction. These are recommendations, not implemented caps. Prefer resistance over total hazard immunity, triggered healing over permanent 1% per second regeneration, and a proc cooldown for reflection or first-hit negation. Mining yield bonuses require an economy simulation before activation.



## Implementation status

60 catalog identities and weighted new-account selection are implemented. Existing legacy IDs remain valid. Seven signatures use available mechanics; the remaining 53 equipment signatures and all 10 visor buffs require systems work. Art is concept direction. No sculpted 3D models, mesh imports or live Studio visual playtest have been completed in this pass.



## Validation

Equipment and expedition regressions pass. A new simulation covers 60,000 equipment draws and 10,000 visor draws, checks all 60 equipment and ten visor entries are reachable, verifies weighted distributions, pistol attack contracts, consistent saved rarity and no reroll on rejoin. Selene and Rojo build checks are also used.



## Runtime balance update October 1 2026

Passive equipment damage reduction and matching gem resistance now share a combined 20% ceiling, applied after the armor rating formula. Temporary ability defenses and shields retain separate behavior. Equipment cooldown reduction caps at 20%. Total critical chance caps at 10%; baseline chance is 5%, Speed contributes at most 2.5 percentage points at Speed / 4000, and equipment fills the remaining headroom.



Planned hazard traits now use resistance or slower resource decay with a maximum 60% protection. They do not grant immunity and remain inactive until hazard handlers exist. Planned reflection uses a 25 second shared player cooldown; phase dodge and first hit protection use 30 seconds. The server time utility gate is implemented and boundary tested, but the missing utilities themselves are not activated. Cooldowns are shared by utility across equipped items so item swapping cannot bypass them.



Mixed families remain unrestricted. The September artbook is a historical source snapshot; this section describes the newer balance contract. Sculpted meshes, missing signatures and functional visor buffs remain outstanding.



## Simplified assets October 1 2026

Three procedural asset families now replace the six old space suit builders: Utility Miner, Frontier Ranger and Heavy Vanguard. They use a rounded pressure helmet with a single visor band, compact beveled chest and limb plates, continuous fabric sleeves and legs, plain soles and one life support pack. Shoulder coverage and thigh protection distinguish heavier equipment without crests, capes, wings or decorative stacks.



The new-player equipment matrix maps its 50 non-weapon identities onto those families. Legacy suit look IDs are aliased to the same builders, so existing accounts get the visual update without a saved-data reset. All Vanguard pistols use a compact CleanSidearm asset; independent shields use the new restrained cleanShield builder. Saved stats, item identities, trading and enchantment slots remain supported. Paint variation is subtle and old extra weapon attachments are disabled for the compact sidearm.



Geometry previews show unenchanted Standard-quality R6 examples with 42, 44 and 50 armor parts respectively. R6 and R15 modular-slot tests pass with a ceiling of 65 parts per full armor family. These are actual native Roblox part builders; no sculpted mesh or asset upload is claimed. Live Studio appearance still needs verification.





### Proportion revision — October 1



The three runtime families now use stepped voxel helmets and layered armor again, rather than the rounded pressure-suit geometry. Visible armor is narrowed independently of the animation and collision rig: smaller helmet, tapered waist, slimmer upper arms, forearms, thighs, calves, hands and boots. Joint heights stay unchanged; modular pieces share the same proportions. Legacy suit IDs resolve to these families. Random equipment rolls and saved stats are unchanged.



Actual standard-quality exports contain 80 parts for Utility Miner, 78 for Frontier Ranger and 80 for Heavy Vanguard; this supersedes the earlier 42/44/50 counts and rounded-helmet description. R6/R15 modular builds, saved randomized loadouts, Selene and Rojo build passed. Preview renders show actual procedural geometry, not a live Studio playtest.



### Sword and rarity asset pass - October 1

Vanguard weapons now resolve to swords while preserving saved item IDs, quality, rarity and sockets. Ten matrix swords remain in the weighted random pool. Standard swords: 18 damage, 0.65-second interval, 7-stud range. Scout sword: 15 damage, 0.52 seconds, 6 studs. Heavy swords: 23 damage, 0.85 seconds, 7.5 studs. All use the existing server melee cone and three-strike combo with gem hit effects. UI slot: Weapon.

Armor rarity adds helmet fittings, overlapping shoulders, chest reinforcement, segmented gauntlets and greaves. Visors remain clear. FrontierAssets builds five rarity levels of swords and stepped shields with grip wraps, reinforced guards, energy insets and legendary alloy trim. Detail adds no stat multiplier. Actual full-loadout preview counts: 94/128/166/190/231 parts. Regression checks cover geometry, rarity progression, weighted pools and saved weapon compatibility; Selene and Rojo build pass. Live Studio animation and appearance remain unverified.


Correction: swords are ADDITIONAL weapons. The ten original MatrixWeapons IDs retain their pistol names, ranged attacks and signatures. Ten new MatrixSwords IDs join the same weighted pool, for 70 total matrix items. Weapon rarity odds stay 40/25/20/10/5; each rarity has two pistols and two swords. Existing pistol ownership and sockets remain pistols.
