# Loading Screens (tutorial curriculum)

10 finished loading screens, 1920x1080 JPEG. Each teaches one system.
Captions are baked in; `manifest.json` holds the same text plus rotation rules.

Rotation rules:
- Week 1: screens 1-4 get 3x weight (they teach the core loop).
- Unlock gating: 06 requires first dungeon, 07 requires first duplicate, 09 requires first duel.
  Never show a tip for a system the player has not touched yet.

Regenerating: replace the JPEG, keep filenames stable; the manifest is the source of truth.
