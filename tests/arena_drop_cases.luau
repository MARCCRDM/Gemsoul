local checks = 0
local function check(v, m)
	checks += 1
	assert(v, m)
end
local p, h, root = makePlayer(978, arena, nil)
p:SetAttribute("ArenaDropUntil", workspace:GetServerTimeNow() + 7)
local hp = h.Health
local amount = CombatServer.hurt(p, 100, "Fire", nil, false, false)
check(amount == 0 and h.Health == hp, "Insertion fighter took damage")
CombatServer._input(p, "BeginAttack", "Right")
check(CombatServer._state(p).ChargeStarted == nil, "Insertion accepted an attack charge")
CombatServer._input(p, "Block", true, root.Position + Vector3.new(0, 0, -4))
check(p:GetAttribute("Blocking") ~= true, "Insertion accepted a guard action")
for count = 1, 5 do
	check(
		ArenaDrop.duration(count) >= 2.5 and ArenaDrop.duration(count) <= 3,
		"Insertion exceeded 2.5-3 second deployment budget"
	)
end
check(ArenaDrop.duration(4) > ArenaDrop.duration(2), "Team insertion does not scale")
p:SetAttribute("ArenaDropUntil", nil)
ArenaDrop.cancel(p.Character)
check(ArenaDrop.forRival("Training", nil, nil), "Onboarding fight lost orbital insertion")
check(ArenaDrop.forRival("Training", nil, nil), "Regular AI arena lost insertion")
check(ArenaDrop.forRival("PvP", nil, nil), "PvP arena lost insertion")
check(not ArenaDrop.forRival("Raid", {}, nil), "Raid received arena insertion")
check(not ArenaDrop.forRival("Training", nil, {}), "Dungeon encounter received arena insertion")
check(not ArenaDrop.forRival(nil, nil, nil), "Lobby received arena insertion")
-- Camera and shell must never pop at a phase boundary, including impact onset.
for _, boundary in { 0, Motion.Landing, Motion.Hatch, Motion.Exit, Motion.Exit + Motion.ExitDuration, Motion.Ready } do
	local before, after = Motion.sample(boundary - 0.00001), Motion.sample(boundary + 0.00001)
	for _, field in { "Height", "Approach", "Impact", "Step", "Pitch", "Hatch", "Draw", "Fov" } do
		check(math.abs(before[field] - after[field]) < 0.01, "Insertion discontinuity: " .. field .. " at " .. boundary)
	end
end
check(Motion.sample(-10).Height == Motion.Altitude, "Queued pod does not hold at altitude")
check(Motion.Altitude > 82 and Motion.Approach > 0, "Insertion did not start farther away")
check(Motion.sample(-10).Approach == Motion.Approach, "Queued pod approach is not held")
check(Motion.sample(Motion.Landing).Approach == 0, "Approach misses landing spot")
check(
	Motion.sample(100).Height == 0 and Motion.sample(100).Step == 3,
	"Late client cannot reconstruct completed landing"
)
check(Motion.sample(Motion.Exit).Hatch > 0.7, "Fighter exits before hatch clears")
check(Motion.sample(Motion.Ready).Draw == 1, "Weapon draw not finished before handoff")
for count = 1, 4 do
	local lastReady = Motion.Lead + (count - 1) * Motion.Spacing + Motion.releaseDelay(count, count) + Motion.Ready
	check(
		ArenaDrop.duration(count) - lastReady >= Motion.Handoff - 0.0001,
		"Combat starts before final weapon is ready"
	)
end
check(Motion.sample(Motion.Landing + 0.29).Impact == 0, "Impact repeats after the initial compression")
check(Motion.SmokeAfter >= 3, "Smoke clears before combat can establish")
check(Motion.blast(Motion.ShellBurst - 0.01).Travel == 0, "Shell ruptures before release")
check(Motion.blast(Motion.ShellBurst + 0.1).Travel > 0, "Shell never blows outward")
check(Motion.blast(Motion.ShellBurst + 1.7).Fade == 1, "Debris persists in combat viewport")
check(Motion.blast(Motion.ShellBurst + 1).Flash < 0.001, "Explosion flash blocks sustained combat")
check(Motion.smokeSpread(Motion.Landing) == 2, "Smoke starts detached from impact")
check(Motion.smokeSpread(Motion.Landing + 1.5) >= 30, "Impact smoke does not reach across arena")
check(Motion.SmokeAfter >= 6, "Arena smoke does not linger into combat")
check(Motion.Landing >= 0.8 and Motion.Landing <= 1.1, "Descent is not fast enough for short deployment")
check(Motion.sample(Motion.ShellBurst).Hatch == 1, "Shell explodes before door finishes ejecting")
check(Motion.blast(Motion.Hatch + 0.2).Travel == 0, "Door and shell are exploding together")
check(Motion.audio(-0.1).Air == 0 and Motion.audio(-0.1).Rumble == 0, "Descent audio begins before launch")
check(Motion.audio(0.5).Air > 0 and Motion.audio(0.5).Rumble > 0, "Missing descent layers")
check(Motion.audio(Motion.Landing).Air == 0, "Air rush continues after impact")
check(Motion.audio(Motion.Landing + 0.7).Rumble == 0, "Rumble does not release after impact")
check(Motion.Spacing <= 0.25, "Drops no longer land on a close double beat")
for count = 2, 4 do
	local lastDoorOpen = Motion.Lead + (count - 1) * Motion.Spacing + Motion.Hatch + Motion.HatchDuration
	local lastExit = 0
	for slot = 1, count do
		local start = Motion.Lead + (slot - 1) * Motion.Spacing
		local delay = Motion.releaseDelay(slot, count)
		local exitAt = start + Motion.Exit + delay
		check(exitAt > lastDoorOpen, "A fighter exits before all opponents can see through their open doors")
		check(exitAt > lastExit, "Fighters do not emerge in order")
		check(
			Motion.sample(Motion.Ready + delay, delay).Step == Motion.ExitDistance,
			"Delayed exit never reaches spawn"
		)
		check(Motion.sample(Motion.Exit + delay - 0.01, delay).Step == 0, "Delayed fighter moved before exit cue")
		lastExit = exitAt
	end
end
for _, fps in { 30, 60, 144 } do
	local previous = Motion.sample(-1 / fps)
	for frame = 0, math.ceil(Motion.Ready * fps) do
		local sample = Motion.sample(frame / fps)
		check(sample.Height <= previous.Height + 0.00001, "Pod reverses direction during descent")
		check(sample.Approach <= previous.Approach + 0.00001, "Pod reverses its approach")
		check(sample.Step >= previous.Step - 0.00001, "Exit movement reverses")
		check(sample.Draw >= previous.Draw - 0.00001, "Weapon draw reverses")
		previous = sample
	end
end
print("PASS: " .. checks .. " orbital insertion protection and timing checks")
