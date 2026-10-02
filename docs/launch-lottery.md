# Launch lottery onboarding

The old lore/ship/bomber intro is replaced by a short welcome, a six-reel equipment reveal, and a nine-reel gemstone reveal. All equipment reels roll together and stop in order: Boots → Gloves → Weapon → Shield → Chest → Helmet. The helmet is the final equipment reveal. Equipment results are the actual server-rolled starter loadout, with authored 3D geometry shown when replicated equipment is available; symbols remain as a fallback.

The gem lottery reveals a cut gemstone for each equipment socket and three separate Gem Surge capacitors. Gems cover all four elements, have cut grades 5–8, and include at least one Uncommon-or-better gem. Rarity, size, clarity and cuts remain random. Reels use animated names, colored symbols, progressively staggered stops, restrained sound ticks, scale punches and short star bursts. Phone layouts wrap equipment to two rows; gem reveals use a three-column grid.

Enter Moon Base grants and attunes all nine gems. Existing equipped gems are preserved; their corresponding new rewards go to the backpack, subject to a checked capacity limit. Skip animation / Space claims exactly the same rewards. No reward depends on animation timing, and there is no paid spin or reroll. Returning players whose intro is already complete keep their existing progress and do not receive the package again.

Server preparation stores the complete reveal plan in Intro.Lottery. Repeated requests and reconnects reuse that plan; the Granted flag prevents duplicate claims. Claim capacity is checked before any gem assignment. Legacy QuickStart and FinishIntro use the same completion path; class selection is retired. Gems are escrowed until completion rather than added temporarily to the backpack.

The three Gem Surge capacitors are the Surge Array sockets on Q, E and R (saved as Surge1Gem, Surge2Gem and Surge3Gem). The armory's SURGE ARRAY button, the dashboard socket strip and the L key open the Surge Array window: pick a socket, then a cut gem from the pouch. Each gem's element and surge tier decide its ability (Ability System v3.0); capacitor gems do not add armor or weapon enchantment stats.

## Validation

Run tests/run_starter_lottery.py for deterministic reveal order, unique IDs, coverage, saved outcomes, duplicate prevention, capacity and real PlayerData socket tests. Combat and equipment suites verify that Surge socket support preserves the existing damage and equipment systems. Open .tools/launch-lottery.rbxlx in Studio with a new test profile to review the intro. Do not erase a live player profile to test it.

Studio review: inspect 320×568, 360×640, 640×360 and desktop sizes; skip during both lotteries; disconnect after preparation and rejoin; verify nine filled sockets and the weapon gem's combat effect; try all three Surge capacitor replacements at Vey. Visual pacing, replicated equipment previews and audio still need live Studio/device validation. Nothing has been published.

## Presentation polish — launch chamber

The lottery now uses a full launch-chamber composition instead of a uniform card grid. A floating, locally built 3D capsule introduces the ceremony. A large reward spotlight fills the left side on desktop, beside a compact manifest of live reels. Matte navy surfaces, fine cyan rings, warm gold controls, restrained stars and rarity-colored accents establish the visual hierarchy.

All reels begin together. Each reel scrolls vertically, slows as its reveal approaches and locks in sequence; the next reel receives a stronger border. Boots remain first and the helmet remains last. The final equipment and gem reveals receive an extra pause. Every winning item takes over the large preview with a gentle zoom and localized particle burst; no fullscreen flash is used. Static thumbnails stay in the manifest and can be selected to inspect earlier rewards. Actual authored equipment and gem geometry is reused, with a capsule fallback if equipment replication has not arrived.

Portrait phones use a large preview above a horizontal reward strip. Short landscape windows also use a strip to keep controls accessible. Full desktop uses three columns, with two rows for equipment and three for gems. Previews frame against the narrower viewport dimension. A Motion: calm control removes preview bobbing, reel translation, scan lines, zoom punches and particle bursts while preserving reward information and timing. Skip still grants the same saved rewards.

`tests/run_lottery_ui.py` runs the real intro controller with GUI/service doubles and checks the complete equipment-to-gem flow, inspectable rewards, failed-request retry, repeat input protection, calm mode, claim behavior and cleanup. It does not certify live Roblox rendering. Studio review is still required for visual framing, scrolling, touch reach and audio pacing.

## Premium RPG visual pass

The launch chamber now uses forged-metal bevels, brass corner fasteners, a serif display heading and a framed rarity crest. The custom six-sided reliquary has plated doors, inset emissive seams, a crown and a segmented pedestal. Its shell opens outward and its crown rises during the final 0.7 seconds before the first reveal; calm motion keeps the mechanism still. Camera framing widens during opening.

Rarity has a visible hierarchy: one to five illuminated crest diamonds, a colored orbital dial, and increasing impact-particle density. Common rewards use a mechanical equip sound, Uncommon a confirmation tone, Rare an enchantment tone, and Ultra Rare/Legendary a reward cue. Final reveals receive the completion cue regardless of rarity. The manifest progress rail fills as rewards lock in. All styling and geometry are original to Saga Miners.

The new art pass preserves the existing server-owned reward plan and claim path. Static thumbnail cameras now skip redundant positioning work when their size is unchanged. Studio review remains necessary for the new metal lighting, capsule opening and rarity emphasis.
