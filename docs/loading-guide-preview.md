# Loading guide — actual game assets

Five native Roblox loading-screen layouts: Mining, Gems, Enchanting, Surges and Charge.
Uses GemArt, GearArt, the shipped SurgeIcons atlas, and a cloned Outpost mining node.
No generated illustrations, invented miner models, new asset uploads, or profile mutations.
Equipment previews use the current player's worn gear. Rock and equipment previews need
the Outpost and dressed character to be available; an explicit placeholder appears otherwise.

## Review in Studio

Start Play, wait for the Outpost to spawn, switch the command bar to **Client**, and run:

```lua
require(game.Players.LocalPlayer.PlayerScripts.Client.Modules.LoadingGuide).preview()
```

The five topic buttons switch screens. CLOSE dismisses the preview.
These are reviewable layouts, not yet connected to initial loading or teleport flows.
No forced tutorial has been enabled. The bar is empty in preview: it does not fake loading progress.

## Loading controller interface

`LoadingGuide.mount(playerGui, topicIndex, false)` returns `Show(index)`,
`SetProgress(fraction)` and `Destroy()` closures. The eventual loading controller
must supply real progress and call Destroy as soon as loading finishes.
Early join loading needs a replicated asset library for rocks/equipment before the
live Outpost and player appearance become available; the current preview deliberately
does not substitute generated art for these assets.

Validation: Luau compilation and Rojo build; runtime appearance still requires Studio review.
