# Performance (2026-10-15)

The game should run smoothly, with no hitches in a fight, even in a full
server where every fighter wears a neon suit. The rules below keep it that
way, followed by what was changed to get there.

## Rules for code that runs every frame

RenderStepped, Heartbeat and BindToRenderStep handlers run 60 times a second
or more, so:

- **No searches of the world or the UI.** Don't call `GetDescendants`, `GetChildren` or `FindFirstChild(name, true)` on a big tree inside a frame. Find things once, keep them, and check that a kept one is still there.
- **Write a property only when its value changes.** This applies most to `Text`, and any `string.format` that builds it. Keep the last value you wrote in a Lua field (for example `bar.ShownAmount`) and compare against that.
- **Don't build tables, `ColorSequence`s or `NumberSequence`s per frame unless they change.** Garbage made every frame comes back as a collection stutter. Reuse lists with `table.clear`.
- **Move many anchored parts with one `workspace:BulkMoveTo` call,** not one `CFrame` write per part.
- **Raycast only what needs it, and set `RaycastParams.FilterDescendantsInstances` only when the list changes.** Setting the list rebuilds it.
- **Heavy work that doesn't need every frame runs at a slower rate** (a timer of 0.1 to 0.25 s). Examples: stats from the augment tree, HUD layout, line-of-sight checks on foes you aren't locked onto.
- **Skip what's far away.** Effects nobody can see (more than about 120 to 220 studs from the camera) don't animate.

## Rules for the network

Every change to a player's attribute is sent to **every** player in the
server.

- **Publish whole numbers, not fractions that change every frame.** Charge and Stamina regenerate every frame, but are published in whole points.
- **Publish times on a fixed clock.** Use `serverTime(t)` in CombatServer (os.clock plus an offset fixed at start). Mixing `GetServerTimeNow()` with `os.clock()` drifts a little every frame and re-sends the value every frame.
- **`SetAttribute` with an unchanged value costs nothing on the network.** That's why the quantised values above are cheap even though the server still sets them every tick.

## What was optimised

| Where | Before | Now |
| --- | --- | --- |
| Combat HUD (`Combat.client`) | Every frame: augment tree and surge stats, icon art, full HUD layout, and new strings, a `ColorSequence` and a key table. | Layout only when the screen changes (or every 0.25 s); surge contents 5 times a second; text only when it changes. |
| Combat HUD | A crosshair raycast every frame, for a target card that is never shown. | Gone. |
| First-person view (`FirstPersonCombat`) | One `CFrame` write per viewmodel part (the shield alone is about 40), and attribute reads repeated per part. | One `BulkMoveTo`; attributes read once a frame. |
| Target lock (`TargetLock`) | A raycast per foe per frame, rebuilding the filter each time. | The locked foe every frame; the others at the 10 Hz scan; the filter rebuilt only when it changes. |
| Skin trim (`SeamVisibility`) | Every outline in the server checked every frame (well over a thousand with neon suits), including the Shop's mannequins in ReplicatedStorage. | Your own and first person's every frame, a preview's only while it's on screen; everyone else's in slices (all of them every 4 frames); animated trim only within 120 studs; trim strips (real parts, over a hundred a suit) recoloured 20 times a second; parts drawn nowhere never checked. |
| Stone lights (`GemLights`) | A tween per stone on the server: every stone's light (up to 8 a fighter, Ion's strobing every frame) sent to every player. | Moved on each client, within 120 studs; nothing goes over the network. |
| Prismatic gear (`PrismaticShimmer`) | Every plate in the world recoloured every frame, with an attribute read and an HSV conversion. | Base colour read once; only plates within 150 studs shimmer. |
| Status effects (`StatusEffects.decode`) | Each fighter's status string parsed 3 or more times a frame (HUD, overhead bars, auras). | Each string parsed once and the result shared (frozen). |
| World decorations (`Effects.client`) | One `CFrame` write per spinning or bobbing part; attribute and light lookups every frame. | One `BulkMoveTo`; lookups cached. |
| Tutorial (`Tutorial.client`) | Up to two full PlayerGui searches 10 times a second while the inventory was open. | Each target found once and kept; a failed search waits half a second. |
| Foe bars (`FoeBars`) | Names and percentages rewritten every frame. | Only when they change. |
| Server (`CombatServer`, `TriadServer`) | Fractional Charge and Stamina, and a drifting `GuardUntil`, sent to every player every frame. | Whole points and a fixed-clock `GuardUntil`: sent only when they really change. |

## Tests

- `tests/run_seam_visibility.py` checks the outline slicing:
  - your own outlines are checked every frame, even in a crowd;
  - everyone else's are all checked within `Spread` frames, not all in one;
  - a new body's outlines count as yours;
  - the animation and restyle cases still work.
- `tests/run_target_lock.py` checks that the cover grace on the locked foe still starts the moment it's hidden.
- `tests/run_live_looks.py` checks that stone lights and Prismatic plates move only where they're drawn: near the camera, in first person, or in a preview on screen.
