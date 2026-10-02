# Saga Miners — Combat Presentation Production Blueprint

Version 1.0 · October 2, 2026 · Implementation and Studio review brief

## Direction

Make fast first-person combat readable at a glance: the opponent owns the center, health is the first peripheral signal, technique availability is explicit, and every successful hit has a short, recognizable response. Keep Saga Miners’ industrial equipment silhouettes, armor families, and gem colors. Upgrade the finish and presentation rather than replace the designs.

This brief is grounded in the repository’s current implementation. The latest request refers to a combat screenshot, but that image was not available in this turn. The layout diagram is a schematic, not a capture from Roblox Studio.

[Desktop layout schematic](combat-hud-layout.svg)

## Implemented in this revision

| Area | Production change | Purpose |
| --- | --- | --- |
| Player resources | Stronger health typography, thicker health bar, amber trailing damage fill, brighter low-health color, larger resource labels, fine sci-fi border | Make damage and remaining resources legible without covering the opponent |
| Rig / Surge cards | Separate title and status labels; READY, CHANNELING, COOLDOWN, LOW RESOURCE and GEM REQUIRED states; resource rank-adjusted cost remains visible | Explain why an ability can or cannot activate |
| Action controls | Separated key, timer and action labels; pressed state highlights; touch-specific HOLD / TAP labels; cycle targets enlarged to 44×44 | Remove overlapping text and clarify input behavior |
| Layout | Portrait action row; compact landscape layout; narrow desktop resources move left; full desktop resources remain bottom-center | Avoid collisions between resource and action clusters |
| Hit feedback | Attacker-only crosshair confirmation; gold critical marker; critical text label; floating-number scale punch | Distinguish an attempted attack from an accepted hit |
| Incoming damage | Brief camera-relative directional marker using the server’s attack origin | Show where actual health damage came from |
| Viewmodel | Dedicated pistol recoil, smoothed guard raise, restrained breathing, mild metal highlights | Give weapons weight while retaining their geometry and colors |
| Arena | Cooler, thinner floor grid, lighter blue-gray floor, four cool light fixtures | Separate navigational lines from red hostile warnings and lift character silhouettes |
| FX clarity | More transparent swing fans and radial pulses, smaller ordinary projectiles, maximum 24 concurrent floating numbers | Reduce obstruction during rapid attacks |
| Neutral NPCs | Vendor-tagged characters excluded from the enemy target card | Keep Brutus’ instructor role clear |

These changes are local source changes. They have not been published or visually playtested in Studio.

## 1. HUD hierarchy and behavior

### Player status

Health is the primary signal. Its live fill responds immediately; its amber trailing fill decays toward the new value with a frame-rate-independent exponential response (rate 3/s). Healing updates both fills immediately. At 25% health or lower, the live fill becomes brighter pink-red. Numerical HP and shield values remain present: meaning must survive color differences.

Stamina and Charge sit beneath health in stable, labeled rows. Stamina stays green; Charge stays blue. Keep their labels in the same positions while values change. The timing bar under the reticle is **attack timing**, distinct from the player’s **Charge resource**. Gold means the perfect release window; red means overcharge. Preserve that distinction in tutorials and localization.

The supporting combat hint occupies the final row. It explains the current action rather than competing with the target name. Keep messages concise: PERFECT WINDOW, GUARD UP, PARRIED, or COMBO. Avoid long explanatory paragraphs during combat; the guide remains available outside the aiming task.

### Technique cards

Title: bold 13 px, one line with truncation. Status: bold 10 px, two lines with key/action state and resource cost. Each card retains a thin colored border. This is the minimum compact layout; larger accessibility text is a follow-up, not an implemented setting.

| State priority | Label | Presentation | Activation |
| --- | --- | --- | --- |
| Missing required gem | GEM REQUIRED | Dim neutral text / rim | Server rejects incompatible activation |
| Missing required shield | SHIELD REQUIRED | Dim neutral text / rim | Equip a shield |
| Active stream | CHANNELING | Resource-colored status; HOLD shown | Release to stop |
| Remaining cooldown | COOLDOWN 2.4s | Cool gray countdown | Wait until cooldown expires |
| Insufficient resource | LOW STAMINA / LOW CHARGE | Amber warning plus resource name | Regenerate the named resource |
| Action recovery / held attack or guard | RECOVERY / RELEASE ATTACK / LOWER GUARD | Dim status and explicit action hint | Finish the current action |
| Available | READY | Resource-colored status / rim | Activate with R / F or touch |

Channel state comes from the replicated server Channeling attribute. Cost text uses the current Augment Tree rank. Streaming resource warnings compare against the quarter-second payment used by the server, while the card shows the per-second rate.

The server remains authoritative. These card states explain availability; they do not bypass costs, sockets, cooldowns, learned techniques, range, or line of sight. Techniques unlocked in the Augment Tree continue to cycle through the existing controls. AUGMENT TREE / K stays directly accessible.

### Action controls

Use separate regions for the input hint, cooldown timer and action name. Active Guard and a held left/right attack highlight the action name in gold. Cooling actions dim their name while retaining a readable numeric timer. Touch shows HOLD for attack/guard and TAP for dodge; desktop keeps Q/E, RMB and Space.

No resource or action feedback should depend on sound alone. Do not hide unavailable actions: showing the reason teaches the resource loop better than removing the button.

## 2. Resolution and spatial specification

All coordinates below are logical GUI pixels, within the Roblox ScreenGui safe-area behavior. Preserve default device insets; do not force an inset-ignoring fullscreen HUD.

| Layout | Trigger | Resource placement | Actions | Other constraints |
| --- | --- | --- | --- | --- |
| Full desktop | Width ≥1000, height ≥430 | 280×118, centered, bottom margin 58 | Right-side three-button row; Dodge above Guard | Target 260×56 top-center; leave top-right |
| Narrow desktop | Width 600–999, height ≥430 | 280×118, left margin 12, bottom margin 58 | Same right action group | Resource panel clears action group |
| Compact landscape | Width ≥600, height <430 | 220×118, upper-right at y100 | Four evenly spaced bottom actions | Leave top-right; techniques upper-left |
| Portrait | Width <600 | 280×118, centered, bottom margin 112 | Four evenly spaced bottom actions | Target ≤176 px wide; leave beside tree at y214 |

At 320 px width, portrait action targets are 72×70; technique cycle buttons are 44×44. The main technique card is 142×58. These targets retain input area rather than shrink the entire HUD into illegibility. Baseline review sizes: 320×568, 360×640, 640×360, 854×480, 1280×720, 1920×1080 and 2560×1440. Smaller portrait heights and extreme ultrawide arrangements require separate visual validation.

The reticle has a small idle dot. Only the attack timing meter, brief hit confirmation, and directional damage marker may appear near it. Menus retain the existing cursor-release and cancellation behavior. Inspect notch insets, Roblox’s default movement thumbstick, and camera-drag regions on actual touch devices; these interactions cannot be certified with source inspection.

## 3. Combat feedback grammar

| Event | Visual | Timing / implementation | Priority |
| --- | --- | --- | --- |
| Accepted damage | White × around the reticle | 180 ms fading lifetime; sent only to attacker | Primary |
| Critical damage | Gold × and CRIT number | Same short marker; number starts at 1.35 scale and settles over 140 ms | Primary |
| Damage to player | Red directional triangle | 650 ms; radius 94 px; angle computed from current camera and authoritative origin | Primary |
| Floating damage | Outlined world-space number | 900 ms rise/fade; 24 concurrent labels maximum; crit 32 px, normal 24 px | Secondary |
| Perfect release | Gold timing fill and explicit prompt | Existing authoritative attack timing remains unchanged | Primary |
| Guard / parry | Active action highlight and counter prompt | Preserve existing server-confirmed block/parry events | Primary |
| Technique blast | Transparent radial pulse / beam | Existing shape and timing; radial transparency raised to 0.88 | Secondary |
| Weapon arc | Thin translucent fan | Existing 220 ms lifetime; transparency raised to 0.65 | Secondary |

Incoming direction is computed each frame so the indicator remains correct if the player turns. Attacks absorbed entirely by defenses, dodged attacks, prohibited PvP attacks and rejected inputs do not generate health-damage indicators. Environmental or periodic damage without an origin does not invent a direction. This revision displays the latest incoming source; multiple-source indicators are a later enhancement.

Damage is still server-authoritative. PvP opt-in, team rules, safe zones, invulnerability, block and shield mitigation remain in the damage path. Confirmed-hit events are emitted after a valid player damage application or positive enemy damage. Brutus is currently an arena vendor/instructor, not a boss; do not invent a boss health bar for him.

### Next feedback pass — planned, not included

Add separate guard-contact and shield-absorption feedback so zero-health-damage hits still feel tactile without falsely showing successful damage. Add family-consistent impact sparks and audio: short metal click for guard, concise energy snap for Surge, heavier low-frequency impact for a charged melee strike. Use spatial audio for others and restrained local mix levels. Do not add full-screen flashes or repeated camera shake to Servo Flurry.

## 4. Viewmodel and character art

Retain the real equipped weapon, shield and gloves. First-person clones preserve existing geometry, colors, gem accents and authored neon. Only metal panels receive a restrained reflectance floor of 0.08. No family silhouettes or rarity identities are replaced.

Pistol attacks now use dedicated recoil instead of the melee side sweep: a small rearward travel (up to the 0.18-stud envelope) and pitch kick (9-degree envelope), with an exponential return over a 240 ms active interval. The aim camera itself is not kicked. Sword attacks retain their side-specific sweep. Guard transitions interpolate at rate 18/s. Breathing is a restrained 0.012-stud vertical oscillation.

Camera entry, exit, death, respawn and equipment replacement must restore visibility and cursor behavior. First-person parts remain non-colliding, non-queryable, anchored local presentation; they cannot change hit detection.

For the next art pass, prioritize readable helmets and shoulders at arena distance, layered metal roughness, protected gem housings, and stronger material separation. Increase rarity detail on secondary surfaces rather than widen silhouettes or cover the target with emissive ornaments. Validate each family with a neutral material pass before adding gem emission. Enemy stance and wind-up silhouettes should be distinguishable from static training dummies. These character animation and texture changes are follow-up production tasks.

## 5. Arena clarity and performance

The floor is blue-gray (37,47,58); navigation grid is muted cyan (58,111,132). Grid lines narrow from 0.3 to 0.12 studs. Keep red available for enemy danger. Four cool fixtures around the arena use 38-stud-range lights, brightness 1.4 and shadows disabled. Lighting changes are local to the arena geometry; global world lighting is preserved.

Do not increase bloom to compensate for dark materials. Test the floor with Thermal, Cryo, Corrosive and Ion effects simultaneously. Character edges, weapon silhouettes, enemy attack tells, and the floor boundary must remain readable. Keep pulses transparent and projectiles compact. Floating text is capped, but this revision does **not** implement a global VFX pool or a complete part budget.

Performance targets for the next profiling pass: stable 60 fps on the chosen desktop reference device and stable 30 fps on the chosen low-end mobile reference device. These are goals, not measured results. Capture MicroProfiler samples during rapid attacks with multiple players; watch transient part allocation, BillboardGui count, frame-time spikes and mobile thermal throttling. If allocations dominate, pool projectile/impact instances before increasing visual density.

## 6. Acceptance and production handoff

Engineering owns input correctness, state priorities, authoritative event routing, lifecycle cleanup and responsive bounds. Technical art owns arena lighting, material response, impact shapes and overdraw. UX owns hierarchy, touch reachability, unavailable-state comprehension and guide/tree discoverability. Design owns combat timing, resource budgets and family balance; this presentation pass does not rebalance damage.

### Automated verification completed

- Live combat tests cover authoritative damage and seven additional feedback checks: rejected attacks do not confirm, successful hits confirm only to the attacker, direction goes only to the victim, authoritative origin is preserved, and cooldown rejection produces no extra hit feedback.
- Existing technology, resource, Augment Tree UI and first-person lifecycle checks run against the production modules with deterministic service mocks.
- Changed source passes Selene with zero errors/warnings; Rojo produces `.tools/combat-polish.rbxlx`.

Automated checks do not substitute for visual testing.

### Required Studio / device review before release

1. Open the generated place and use Dashboard → Combat Arena. Test training first, then two opt-in players. Confirm training visitors, teammates and town players receive no prohibited damage or false confirmations.
2. Review every baseline viewport size above with desktop and touch emulation. Confirm no label wraps over a bar, no action target overlaps the resource panel, the center remains readable, and notches/default movement controls do not intercept actions.
3. Equip a sword, pistol, shield, and gloves from each family; swap equipment mid-session. Check low/high rarity geometry, material response, animation clipping and reticle visibility during firing and guarding.
4. Practice quick, perfect, overcharged and alternating attacks; trigger Servo Flurry and every Surge. Verify critical punch, cooldown, missing gem, insufficient resource and held-channel states.
5. Attack from front, left, right and behind while turning the camera. Confirm the incoming marker tracks the source and expires. Test ForceField, dodge invulnerability, full absorption and a successful parry.
6. Exit the arena, die, respawn, open/close the guide and tree, alt-tab, and release a touch outside its button. Verify held actions stop, camera and body visibility recover, and no stale indicators remain on re-entry.
7. Profile a prolonged multi-player combat session on target devices. Sign off readability, frame pacing and thumb comfort before publishing.

Release gates: no input/state regressions, no false damage feedback, no clipped primary HUD at supported sizes, and no viewmodel obstruction of critical attack tells. Reduced-motion controls, scalable accessibility text, controller prompts, expanded sound design and character animation polish remain explicit follow-up work.
