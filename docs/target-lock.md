# Soft auto-lock

In combat, face an enemy or training dummy: the nearest eligible target visible within the forward 45-degree cone and 60 studs is acquired automatically. The target gains a cyan outline, cyan reticle and LOCK label. Attacks, guarding and techniques aim at the locked body point while server range, collision and damage checks remain authoritative.

The camera gently follows the target when you are not looking around. Mouse movement, unprocessed touch look and right-stick look suspend tracking immediately. Deliberately turning more than 50 degrees away releases the lock, with a 0.6-second acquisition pause so the camera does not immediately pull back. Walking and free roaming remain available; there is no movement tether or forced strafing mode.

The current lock is sticky: another enemy moving closer does not steal it. Death, removal, loss of line of sight, leaving the viewport or moving beyond range releases it; a new eligible target in front can then be selected. Walls are checked by camera-to-target raycast. Neutral vendors, protected targets, friendly teammates, safe-zone players and players who have not opted into arena PvP are excluded. Brutus remains a neutral instructor.

Opening the guide or Augment Tree, freeing the cursor, exiting combat or changing arena session suspends/reset the lock. Camera assist runs after Roblox's camera update and before the first-person weapon render, preserving weapon/camera alignment. This is local aiming presentation, not a new damage authority.

## Verification

`tests/run_target_lock.py` exercises production selection rules and the real controller with deterministic service mocks: nearest selection, sticky retention, forward cone, turn-away, reacquisition delay, walls, input priority, dead/removed/protected targets, neutral vendors, PvP eligibility, friendly teams and inactive-camera cleanup. Existing combat and first-person lifecycle suites remain required.

Before publishing, open `.tools/target-lock.rbxlx` in Studio and test mouse and real touch controls: approach two dummies, pan past the first target, step behind cover, swap to another visible target and exit/re-enter the arena. In a two-player test, confirm only opt-in enemies can lock. Tune the angle thresholds and tracking rate (7/s) against actual input sensitivity if tracking feels too sticky. This build has not been visually playtested or published.
