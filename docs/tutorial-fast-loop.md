# Mining and enchanting tutorial (v3)

Scope: teach the mining/enchanting loop only. No tutorial Surge controls, matchmaking, combat, Market purchase or extra world rocks.

1. Enter the existing Outpost mining area next to an available real rock.
2. Click, tap or press E for each normal pick swing. Existing reach, cooldown, pick wear, shared claims, hit feedback and rock health rules apply.
3. The first three real rock breaks guarantee Common Thermal, Cryo and Ion gems, through the server mining reward path.
4. A brief gem introduction explains element color and removable equipment enchantments.
5. Open Inventory. Highlight the source gem and target socket together for Chest, Sword and Shield. Real rating changes flash; armor reports its actual perk improvement.
6. Close Inventory. All tutorial guidance is destroyed; modes are available.

A darkened four-panel spotlight leaves the target visible and interactive. A world highlight and direction/distance label guide mining. Brief descriptions explain each action. Closing Inventory early offers a reopen instruction.

DEV > RESTART INTRO / TUTORIAL replays this flow. Owned items and progression are retained; occupied sockets are cleared into the pouch after capacity checks. Skip stops guidance without fabricating rewards. Completed accounts remain completed; older in-progress tutorials migrate to the gem introduction if three gems were already found.

Validation: tests/run_tutorial.py checks progression, real-mining reward hook, retired remote rejection, migration, skip and authorized replays. The production Outpost interaction is reused. Studio desktop/touch walkthrough remains required for camera framing, spotlight/input behavior and rock spawn placement. Changes are not published automatically.

## Discovery and drag guidance polish

Three finds remain the limit. Each find gets a brief celebration and progress counter; mining prompts encourage the next discovery. Tutorial-earned gem IDs are saved so the guided inventory presents those stones ahead of old account loot. An animated gem demonstrates hold, drag and release between the real source card and socket, pausing during touch/mouse interaction. Separate source and destination outlines and numbered cues remain visible. The guide resolves ScreenGui origins for inset-aware placement. Rendering and pulse connections are cleaned up on completion, skip or replay.

Studio verification is still required for inset alignment across devices and the animated example over scaled inventory layouts.
