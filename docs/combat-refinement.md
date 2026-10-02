# First person combat refinement

The charge meter now displays the full interval to overcharge, with a gold band matching the shared perfect timing window. Resource spending appears immediately; regeneration interpolates toward server values. Low resources have a text label as well as a color cue.

Weapon charging eases into and out of its pose. Removed equipment restores its original local transparency and schedules a viewmodel rebuild; removal listeners are disconnected on exit. Losing window focus cancels held attacks, guard and channels.

Combat remotes validate action names and payload shapes before state lookup, equipment resolution or resource updates. Finite aim validation applies to attacks, guard, dodge and abilities. Release and cancel messages remain available even when action rate limits are exhausted. Legacy missing attack side still defaults to Right.

Validation includes live combat, technology, augment and first person lifecycle harnesses plus malformed payload cases. Studio visual and multiplayer playtesting remain necessary; this change is not published.
