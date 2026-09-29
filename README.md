# Gemsoul

A Roblox game. Code lives in `src/` as Luau files and is synced into Roblox Studio with [Rojo](https://rojo.space).

## Setup (once, on your Windows/Mac computer)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run `rokit install` (installs Rojo, StyLua, Selene).
2. In Roblox Studio, install the Rojo plugin: Plugins tab → search "Rojo", or run `rojo plugin install`.

## Every time you work on it

1. `git pull` to get the latest code.
2. `rojo serve` in this folder.
3. Open a Baseplate in Studio → Plugins → Rojo → **Connect**.
4. Press **Play**. Walk into the glowing gems and watch your Gems count go up.

## Layout

| Folder | Goes into | Runs on |
|---|---|---|
| `src/server` | ServerScriptService | Server |
| `src/client` | StarterPlayerScripts | Each player |
| `src/shared` | ReplicatedStorage | Both (modules) |
