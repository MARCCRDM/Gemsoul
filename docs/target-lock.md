# The target lock

In a fight, the lock outlines your target in cyan, aims your moves at it, and
pulls the camera toward it (`Shared/TargetLockRules`, `Client/TargetLock`).
Selection is local presentation: server range, collision and damage checks
stay authoritative.

**On desktop it only works by itself in a 1v1.** With a mouse, an automatic
lock fights your own aim when there are critters, kaiju and fighters all
around. So outside a 1v1, desktop players aim themselves and lock on with T.
(It was X; X is now the kit switch, your pick or your combat kit: see
[friendly-sparring.md](friendly-sparring.md).)

| Where | Desktop (mouse and keyboard) | Touch screen or gamepad |
| --- | --- | --- |
| The Arena, against a player (`PvP`) or a rival (`Training`). This includes the intro's first fight and the combat tutorial, which run there | Automatic | Automatic |
| A 1v1 match (`Duel`) | Automatic | Automatic |
| Spars in the lobby, hunting in the quarry, the Rift, raids and dungeons, expeditions | **You aim; T locks on** | Automatic |

(The session is the player's `CombatSession` attribute; `TargetLockRules.AutoSessions`.)

## The automatic lock

**What it picks.** It goes for the nearest enemy:

- A pack's leader comes first: the Rift's fighters and its boss, while your
  kaiju take their critters.
- With no target, it takes whatever is attacking you (nearest first, wherever
  it is). Failing that, the nearest enemy ahead of you (within 45° and 90
  studs, in sight). Failing that, your Arena rival wherever it is.
- With a target, it moves to any enemy at least 2 studs nearer, if that one is
  in sight or attacking you.

**How long it holds.**

- A target holds through turning, mouse look and touch look, and through up to
  4 seconds of cover.
- It lets go when the target dies, goes past 140 studs or stays hidden.
- Your rival is only let go when it dies or can't be fought.

**Switching.**

- T (D-pad right) cycles the targets within 10 studs, left to right. A target
  you switched to stays until it's lost.
- Clicking or tapping a name in the target list locks that foe the same way.

**The camera.**

- It pulls hard toward the target's head, and a little softer while you look
  around yourself.
- The pull pauses while the guide or the Augment Tree is open, without
  losing the target.
- Moves only aim at the target while it's in sight: no aim assist through
  walls.

## Where you aim yourself (desktop, outside a 1v1)

- **Nothing is picked for you.** Not the nearest enemy, not a pack's leader,
  and not whatever just hit you. Your moves go where the crosshair points.
- **T locks on** to what you're aiming at. That's the target in sight, in
  range (90 studs) and nearest the middle of your view (within 25°).
- **T again** moves to the next target around you (within 10 studs, left to
  right). Past the last one, or with nothing else around, it lets go.
- **Clicking a name** in the target list still locks that foe.
- **A lock you chose holds** just as above: through brief cover, until the
  target dies, leaves range or stays hidden. The camera follows it.
- **The controls reminder** says "T Lock On" here, and "T Switch Target" where
  the lock is automatic.

**Desktop or not.** Desktop means a mouse and a keyboard with no gamepad in
hand, and the last input decides. Picking up a controller on a PC brings back
the automatic lock; going back to the mouse turns it off again. A touch screen
without a keyboard keeps the automatic lock.

## Who can be locked

- An enemy (critters, kaiju, fighters, bosses) that's alive and fightable
  where it stands.
- Not neutral vendors, not anyone protected by a ForceField, and not
  teammates.
- In the Arena, another player only if both of you have opted into PvP.
- In a spar, only your partner, and only while you're both on your feet.

## Files

| File | What |
| --- | --- |
| `src/shared/TargetLockRules.luau` | The rules: `update` (the automatic lock), `switch`, `pick`. For desktop: `auto(session, desktop)` and `AutoSessions`, plus `hold` (keep only a chosen target), `aimed` and `toggle` (what T does) |
| `src/client/Modules/TargetLock.luau` | The live lock: who's eligible, line of sight, the camera pull, and `Lock.auto()`. That reads the player's `CombatSession` and whether they're on a mouse (a gamepad in hand comes from `LastInputTypeChanged`) |
| `src/client/Combat.client.luau` | Turns the lock on in a fight, binds T, and shows the controls reminder |
| `src/client/Modules/FoeBars.luau` | The target list (click a name to lock it) |

## Tests and playtesting

`tests/run_target_lock.py` runs the production rules and the real controller
against deterministic service mocks. It checks:

- **The automatic lock:** nearest selection, a pack's leader first,
  auto-engaging an attacker, the cover grace, range, switching and picking.
- **The controller:** eligibility (dead, removed and protected targets,
  vendors, PvP opt-in, teams, spars), camera tracking, pausing, and cleanup
  when combat ends.
- **The desktop rule:** automatic only in `PvP`, `Training` and `Duel`.
  Elsewhere:
  - nothing is picked or pulled, and being hit doesn't lock;
  - T locks what you aim at, moves left to right, then lets go;
  - a gamepad or touch screen brings the automatic lock back.

None of this has been played in Roblox Studio. Before publishing, test it with
a mouse, a gamepad and a touch screen:

- in the Arena against a rival;
- in a lobby spar;
- hunting in the quarry with critters and kaiju about;
- in the Rift.

Check that the mouse aims freely outside a 1v1, that T locks on and lets go,
and that the automatic lock still feels right in the Arena.
