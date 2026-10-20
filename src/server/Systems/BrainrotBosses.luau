--[[
	The dungeons' bosses (Shared.DungeonRules.Bosses): ten brainrot creatures,
	most of them with two or three heads. Like the room fighters
	(BrainrotSkins) each is built of plain parts welded onto the R15 combat
	skeleton (its bones go invisible), so they walk, wind up, strike, guard
	and flinch with the standard fighting poses (RivalPose, BodyPoses). Their
	heads look about and nod, wings flap, tails sway, jaws and beaks snap on
	a blow (CreatureAnimation: Head, Wing, Tail, Jaw, Moss, Blade).

	  TwinCat     Gattini Gemellini      two cat heads on a grey stone body
	  DragonCroc  Bombardiro Drago       a crocodile with bat wings
	  TwinDuck    Paperotti Gemelli      two mallard heads, a round red body
	  FrogAvocado Ranocchio Avocadino    two frogs on an avocado
	  Chimpanzini Chimpanzini Bananini   three monkeys on a peeled banana
	  SahurTrio   Tung Tung Tung Sahur   three orange logs, and the bat
	  TwinShark   Tralalero Tralala      two shark heads, blue sneakers
	  TreeTrio    Brr Brr Patapim        three long-nosed faces on a mossy trunk
	  Frigo       Frigo Camelo           two camels out of a fridge
	  Cappuccino  Cappuccino Assassino   a ninja coffee cup with four knives

	  BrainrotBosses.Builders[shape](rig, accent)
	  BrainrotBosses.apply(rig, spec, accent, boss) -> boolean   dresses it
	      (false if `spec` isn't one of these: BrainrotSkins dresses it)
]]
local Skins = require(script.Parent.BrainrotSkins)

local Bosses = {}

local V, C, A = Vector3.new, Color3.fromRGB, CFrame.Angles
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local P, animate = Skins.part, Skins.animate
local WHITE, INK = C(244, 240, 230), C(22, 20, 24)
local UPRIGHT = A(0, 0, math.pi / 2) -- (a cylinder stood on end)

local function ball(rig, bone, name, size, pos, color, rot)
	return P(rig, bone, name, size, pos, color, BALL, rot)
end

local function neon(p)
	p.Material = Enum.Material.Neon
	return p
end

-- Moves every part of `list` together about `pivot` (a CFrame in its bone's
-- space): a head looking about, a wing flapping.
local function group(list, kind: string, pivot: CFrame, side: number)
	for _, p in list do
		animate(p, kind, pivot, side)
	end
end

-- A pair of round cartoon eyes looking forward (-Z): white, iris, pupil and
-- a glint. `iris` glows when `glow` is set.
local function eyePair(rig, bone, list, at: Vector3, spacing: number, r: number, iris: Color3, glow: boolean?)
	for _, s in { -1, 1 } do
		local x = at.X + s * spacing
		table.insert(list, ball(rig, bone, "EyeWhite", V(r, r * 1.1, r * 0.55), V(x, at.Y, at.Z), WHITE))
		local i = ball(rig, bone, "Iris", V(r * 0.62, r * 0.66, r * 0.2), V(x, at.Y, at.Z - r * 0.24), iris)
		if glow then
			neon(i)
		end
		table.insert(list, i)
		table.insert(list, ball(rig, bone, "Pupil", V(r * 0.3, r * 0.34, r * 0.12), V(x, at.Y, at.Z - r * 0.31), INK))
		table.insert(
			list,
			ball(rig, bone, "EyeGlint", V(r * 0.12, r * 0.12, r * 0.06), V(x + r * 0.12, at.Y + r * 0.14, at.Z - r * 0.36), WHITE)
		)
	end
end

-- Rounded limbs (arms and legs as long ellipsoids) in `color`.
local function limbs(rig, color, arm: number, leg: number, armColor: Color3?)
	for _, side in { "Left", "Right" } do
		for _, seg in { "UpperArm", "LowerArm" } do
			local b = rig[side .. seg]
			ball(rig, b, "Arm", V(arm, b.Size.Y + 0.2, arm), V(0, 0, 0), armColor or color)
		end
		for _, seg in { "UpperLeg", "LowerLeg" } do
			local b = rig[side .. seg]
			ball(rig, b, "Leg", V(leg, b.Size.Y + 0.25, leg), V(0, 0, 0), color)
		end
	end
end

-- A paw on each hand (palm and three or four fingers).
local function paws(rig, color: Color3, fingers: number, nail: Color3?)
	for _, side in { "Left", "Right" } do
		local hand = rig[side .. "Hand"]
		ball(rig, hand, "Palm", V(0.6, 0.42, 0.62), V(0, -0.05, -0.05), color)
		for i = 1, fingers do
			local x = (i - (fingers + 1) / 2) * 0.16
			ball(rig, hand, "Finger", V(0.15, 0.32, 0.17), V(x, -0.3, -0.14), color)
			if nail then
				P(rig, hand, "Claw", V(0.08, 0.18, 0.1), V(x, -0.5, -0.17), nail, "Wedge", A(0, 0, math.pi))
			end
		end
	end
end

-- A tail of `n` balls from the hips, curling up behind: it sways.
local function tail(rig, color: Color3, n: number, thick: number, lift: number)
	local t = rig.LowerTorso
	local list = {}
	for i = 1, n do
		local k = (i - 1) / math.max(1, n - 1)
		local size = thick * (1 - k * 0.55)
		table.insert(
			list,
			ball(rig, t, "Tail", V(size, size, size * 1.5), V(0, -0.1 + k * k * lift, 0.6 + i * 0.42), color)
		)
	end
	group(list, "Tail", CFrame.new(0, -0.1, 0.5), 1)
	return list
end

-- The bat: knob, handle, taper and barrel, held as Sahur holds his.
local function bat(rig)
	local h = rig.RightHand
	local grip = A(math.rad(-120), 0, 0)
	local function piece(name, size, y, color, shape, rotation)
		local mount = grip * CFrame.new(0, -y, 0) * (rotation or CFrame.identity)
		local p = P(rig, h, name, size, V(0, 0, 0), color, shape, mount)
		p.Material = Enum.Material.Wood
		return p
	end
	piece("BatKnob", V(0.12, 0.26, 0.26), 0.22, C(150, 96, 45), CYL, UPRIGHT)
	piece("BatHandle", V(1.1, 0.17, 0.17), -0.3, C(196, 150, 96), CYL, UPRIGHT)
	piece("BatTaper", V(0.6, 0.3, 0.3), -1.1, C(222, 180, 122), CYL, UPRIGHT)
	piece("BatBarrel", V(1.5, 0.44, 0.44), -1.95, C(228, 188, 130), CYL, UPRIGHT)
	piece("BatEnd", V(0.44, 0.24, 0.44), -2.7, C(228, 188, 130), BALL)
end

-- A knife at `at` in `bone`'s space: handle, guard and a blade running down
-- its -Y, turned by `mount` (forward out of a fist, or raised overhead).
local function knife(rig, bone, at: Vector3, mount: CFrame, list)
	local function piece(name, size, offset, color, shape, rotation)
		local p = P(rig, bone, name, size, at, color, shape, mount * CFrame.new(offset) * (rotation or CFrame.identity))
		if list then
			table.insert(list, p)
		end
		return p
	end
	piece("KnifeHandle", V(0.16, 0.42, 0.16), V(0, 0, 0), INK)
	piece("KnifeGuard", V(0.36, 0.06, 0.14), V(0, -0.24, 0), C(170, 170, 178))
	piece("KnifeBlade", V(0.06, 1.15, 0.3), V(0, -0.85, -0.02), C(214, 220, 228), "Wedge", A(0, 0, math.pi)).Material =
		Enum.Material.Metal
end

-- Gattini Gemellini ------------------------------------------------------------------------------------
-- Two cat heads, yellow-eyed, on a grey stone body; a long tail.
local function catHead(rig, t, x: number, side: number, accent: Color3)
	local grey, light = C(150, 151, 160), C(196, 196, 204)
	local list = {}
	table.insert(list, ball(rig, t, "CatNeck", V(0.72, 0.5, 0.66), V(x, 0.95, 0), grey))
	table.insert(list, ball(rig, t, "CatSkull", V(1.3, 1.12, 1.12), V(x, 1.55, 0), grey))
	table.insert(list, ball(rig, t, "CatCheeks", V(1.2, 0.6, 0.8), V(x, 1.32, -0.2), grey))
	table.insert(list, ball(rig, t, "CatMuzzle", V(0.62, 0.36, 0.36), V(x, 1.3, -0.52), light))
	table.insert(list, ball(rig, t, "CatNose", V(0.2, 0.13, 0.12), V(x, 1.43, -0.69), C(232, 142, 154)))
	table.insert(list, P(rig, t, "CatMouth", V(0.3, 0.05, 0.05), V(x, 1.2, -0.67), INK))
	eyePair(rig, t, list, V(x, 1.66, -0.46), 0.26, 0.3, accent, true)
	for _, s in { -1, 1 } do
		table.insert(list, P(rig, t, "CatEar", V(0.14, 0.55, 0.46), V(x + s * 0.38, 2.18, 0.02), grey, "Wedge", A(0, math.pi, s * 0.22)))
		table.insert(list, P(rig, t, "InnerEar", V(0.06, 0.38, 0.28), V(x + s * 0.38, 2.12, -0.06), C(226, 156, 168), "Wedge", A(0, math.pi, s * 0.22)))
		for i = 1, 3 do
			table.insert(list, P(rig, t, "Whisker", V(0.55, 0.03, 0.03), V(x + s * 0.5, 1.32 + (i - 2) * 0.07, -0.5), C(236, 236, 236), nil, A(0, s * 0.15, s * (i - 2) * 0.18)))
		end
	end
	group(list, "Head", CFrame.new(x, 0.95, 0), side)
end
local function twinCat(rig, accent)
	local t, l = rig.UpperTorso, rig.LowerTorso
	local grey, light = C(150, 151, 160), C(188, 188, 196)
	ball(rig, t, "CatTorso", V(2.15, 2.0, 1.4), V(0, 0.05, 0), grey)
	ball(rig, t, "CatBelly", V(1.3, 1.45, 0.5), V(0, -0.15, -0.5), light)
	ball(rig, l, "CatHips", V(1.95, 0.95, 1.3), V(0, -0.1, 0), grey)
	for i = 1, 3 do
		-- (stone stripes across the back)
		P(rig, t, "Stripe", V(1.6 - i * 0.2, 0.12, 0.08), V(0, 0.5 - i * 0.35, 0.68), C(118, 118, 128))
	end
	catHead(rig, t, -0.62, -1, accent)
	catHead(rig, t, 0.62, 1, accent)
	limbs(rig, grey, 0.66, 0.78)
	paws(rig, grey, 4, C(70, 70, 76))
	for _, side in { "Left", "Right" } do
		ball(rig, rig[side .. "Foot"], "CatPaw", V(0.75, 0.38, 1.05), V(0, 0.02, -0.2), grey)
		for i = 1, 3 do
			ball(rig, rig[side .. "Foot"], "Toe", V(0.2, 0.18, 0.2), V((i - 2) * 0.2, 0, -0.68), light)
		end
	end
	local list = tail(rig, grey, 6, 0.42, 2.2)
	local tip = l.CFrame:PointToObjectSpace(list[#list].CFrame.Position)
	animate(neon(ball(rig, l, "TailTip", V(0.22, 0.22, 0.22), tip + V(0, 0.15, 0.1), accent)), "Tail", CFrame.new(0, -0.1, 0.5), 1)
end

-- Bombardiro Drago -----------------------------------------------------------------------------------------
-- A crocodile on two legs, with bat wings and a long tail; fire in its eyes.
local function dragonCroc(rig, accent)
	local t, h, l = rig.UpperTorso, rig.Head, rig.LowerTorso
	local olive, belly, dark = C(98, 114, 60), C(200, 182, 122), C(70, 82, 44)
	ball(rig, t, "CrocTorso", V(2.1, 2.3, 1.5), V(0, 0.15, 0.05), olive)
	for i = 0, 4 do
		ball(rig, t, "BellyScale", V(1.2 - i * 0.05, 0.34, 0.32), V(0, -0.75 + i * 0.42, -0.66), belly)
	end
	for i = 0, 5 do
		P(rig, t, "BackRidge", V(0.14, 0.32, 0.36), V(0, 1.05 - i * 0.38, 0.74), dark, "Wedge")
	end
	ball(rig, l, "CrocHips", V(1.95, 1.0, 1.35), V(0, -0.1, 0.05), olive)
	-- The head: skull, long snout, a jaw that snaps, teeth, eyes up top.
	local head = {}
	table.insert(head, ball(rig, h, "CrocSkull", V(1.3, 0.92, 1.4), V(0, 0.1, 0), olive))
	table.insert(head, ball(rig, h, "CrocSnout", V(0.95, 0.46, 2.05), V(0, -0.02, -1.4), olive))
	for _, s in { -1, 1 } do
		table.insert(head, ball(rig, h, "EyeBump", V(0.42, 0.34, 0.42), V(s * 0.38, 0.52, -0.22), olive))
		table.insert(head, neon(ball(rig, h, "FireEye", V(0.24, 0.22, 0.12), V(s * 0.4, 0.56, -0.42), accent)))
		table.insert(head, P(rig, h, "SlitPupil", V(0.05, 0.18, 0.05), V(s * 0.4, 0.56, -0.49), INK))
		table.insert(head, ball(rig, h, "Nostril", V(0.12, 0.08, 0.1), V(s * 0.18, 0.2, -2.3), INK))
		for i = 1, 6 do
			table.insert(head, P(rig, h, "Tooth", V(0.08, 0.16, 0.1), V(s * 0.42, -0.24, -0.55 - i * 0.26), WHITE, "Wedge", A(0, 0, math.pi)))
		end
	end
	group(head, "Head", CFrame.new(0, -0.45, 0.2), 1)
	local jaw = {}
	table.insert(jaw, ball(rig, h, "LowerJaw", V(0.86, 0.3, 1.85), V(0, -0.36, -1.3), olive))
	table.insert(jaw, ball(rig, h, "JawInside", V(0.62, 0.12, 1.5), V(0, -0.24, -1.3), C(140, 54, 50)))
	for _, s in { -1, 1 } do
		for i = 1, 5 do
			table.insert(jaw, P(rig, h, "LowerTooth", V(0.07, 0.14, 0.09), V(s * 0.36, -0.13, -0.6 - i * 0.28), WHITE, "Wedge"))
		end
	end
	group(jaw, "Jaw", CFrame.new(0, -0.3, -0.4), 1)
	-- Bat wings: two finger spars and the leathery membrane between.
	local membrane, spar = C(122, 54, 42), C(72, 52, 36)
	for _, s in { -1, 1 } do
		local wing = {}
		table.insert(wing, P(rig, t, "WingArm", V(1.8, 0.2, 0.2), V(s * 1.2, 1.1, 0.62), spar, CYL, A(0, 0, s * 0.45)))
		table.insert(wing, P(rig, t, "WingFinger", V(2.2, 0.14, 0.14), V(s * 2.5, 1.35, 0.62), spar, CYL, A(0, 0, -s * 0.2)))
		table.insert(wing, P(rig, t, "WingFinger", V(2.0, 0.14, 0.14), V(s * 2.3, 0.45, 0.62), spar, CYL, A(0, 0, s * 0.35)))
		table.insert(wing, P(rig, t, "WingMembrane", V(0.06, 1.7, 2.2), V(s * 1.9, 0.75, 0.66), membrane, "Wedge", A(0, s * math.pi / 2, math.pi)))
		table.insert(wing, P(rig, t, "WingMembrane", V(0.06, 1.3, 1.6), V(s * 3.0, 0.75, 0.66), membrane, "Wedge", A(0, s * math.pi / 2, 0)))
		table.insert(wing, neon(ball(rig, t, "WingClaw", V(0.16, 0.24, 0.16), V(s * 3.55, 1.5, 0.62), accent)))
		group(wing, "Wing", CFrame.new(s * 0.6, 0.9, 0.62), s)
	end
	limbs(rig, olive, 0.6, 0.78)
	paws(rig, olive, 3, C(232, 222, 190))
	for _, side in { "Left", "Right" } do
		local foot = rig[side .. "Foot"]
		ball(rig, foot, "CrocFoot", V(0.85, 0.36, 1.25), V(0, 0.02, -0.22), olive)
		for i = 1, 3 do
			P(rig, foot, "FootClaw", V(0.1, 0.12, 0.3), V((i - 2) * 0.24, -0.06, -0.92), C(232, 222, 190), "Wedge")
		end
	end
	tail(rig, olive, 6, 0.75, 0.4)
end

-- Paperotti Gemelli --------------------------------------------------------------------------------------
-- Two mallard heads on a round red body: little wings, orange webbed feet.
local function duckHead(rig, t, x: number, side: number, accent: Color3)
	local green = C(36, 118, 64)
	local list = {}
	table.insert(list, ball(rig, t, "DuckNeck", V(0.55, 0.9, 0.55), V(x, 1.3, -0.2), C(30, 96, 54)))
	table.insert(list, ball(rig, t, "WhiteCollar", V(0.62, 0.14, 0.62), V(x, 0.98, -0.18), WHITE))
	table.insert(list, ball(rig, t, "DuckHead", V(0.95, 0.88, 1.0), V(x, 1.9, -0.28), green))
	table.insert(list, ball(rig, t, "Bill", V(0.55, 0.18, 0.78), V(x, 1.8, -0.88), C(242, 192, 44)))
	table.insert(list, ball(rig, t, "BillTip", V(0.2, 0.1, 0.12), V(x, 1.83, -1.25), C(60, 44, 20)))
	eyePair(rig, t, list, V(x, 2.02, -0.66), 0.22, 0.2, accent)
	group(list, "Head", CFrame.new(x, 0.95, -0.2), side)
	local beak = { ball(rig, t, "LowerBill", V(0.48, 0.12, 0.66), V(x, 1.68, -0.82), C(226, 166, 34)) }
	group(beak, "Jaw", CFrame.new(x, 1.7, -0.5), side)
end
local function twinDuck(rig, accent)
	local t, l = rig.UpperTorso, rig.LowerTorso
	local red, belly = C(212, 54, 42), C(236, 112, 82)
	ball(rig, t, "DuckBody", V(2.6, 2.4, 2.2), V(0, 0.05, 0.05), red)
	ball(rig, t, "DuckBelly", V(1.8, 1.75, 0.6), V(0, -0.25, -0.85), belly)
	ball(rig, l, "DuckBottom", V(2.3, 1.1, 2.0), V(0, -0.1, 0.05), red)
	for i = 1, 3 do
		P(rig, l, "TailFeather", V(0.3, 0.5, 0.6), V((i - 2) * 0.32, 0.25, 1.05), C(178, 40, 34), "Wedge", A(0.6, 0, 0))
	end
	duckHead(rig, t, -0.6, -1, accent)
	duckHead(rig, t, 0.6, 1, accent)
	for _, s in { -1, 1 } do
		local wing = {}
		table.insert(wing, ball(rig, t, "DuckWing", V(0.36, 1.3, 1.0), V(s * 1.28, 0.1, 0.2), C(176, 42, 34), A(0, 0, s * 0.15)))
		table.insert(wing, neon(ball(rig, t, "WingBar", V(0.38, 0.22, 0.6), V(s * 1.32, 0.45, 0.22), accent)))
		group(wing, "Wing", CFrame.new(s * 1.15, 0.7, 0.2), s)
	end
	limbs(rig, C(242, 142, 44), 0.42, 0.42, red)
	paws(rig, red, 3)
	for _, side in { "Left", "Right" } do
		local foot = rig[side .. "Foot"]
		ball(rig, foot, "WebbedFoot", V(1.0, 0.16, 1.2), V(0, -0.02, -0.3), C(244, 146, 40))
		for i = 1, 3 do
			ball(rig, foot, "WebToe", V(0.22, 0.14, 0.45), V((i - 2) * 0.32, -0.02, -0.82), C(232, 128, 34))
		end
	end
end

-- Ranocchio Avocadino -------------------------------------------------------------------------------------
-- Two frogs on a halved avocado: skin, flesh, and the stone in the middle.
local function frogHead(rig, t, x: number, side: number)
	local green = C(96, 176, 66)
	local list = {}
	table.insert(list, ball(rig, t, "FrogHead", V(1.25, 0.8, 1.15), V(x, 1.98, -0.1), green))
	for _, s in { -1, 1 } do
		table.insert(list, ball(rig, t, "EyeBulge", V(0.44, 0.44, 0.44), V(x + s * 0.34, 2.38, -0.28), green))
		table.insert(list, ball(rig, t, "FrogEye", V(0.34, 0.34, 0.2), V(x + s * 0.34, 2.42, -0.46), C(232, 214, 92)))
		table.insert(list, P(rig, t, "FrogPupil", V(0.2, 0.08, 0.06), V(x + s * 0.34, 2.42, -0.57), INK))
	end
	for i = -2, 2 do
		table.insert(list, P(rig, t, "Smile", V(0.22, 0.05, 0.05), V(x + i * 0.18, 1.88 + i * i * 0.025, -0.68), C(40, 60, 30), nil, A(0, 0, i * 0.12)))
	end
	table.insert(list, ball(rig, t, "Cheek", V(0.22, 0.14, 0.08), V(x - 0.45, 1.95, -0.6), C(232, 132, 120)))
	table.insert(list, ball(rig, t, "Cheek", V(0.22, 0.14, 0.08), V(x + 0.45, 1.95, -0.6), C(232, 132, 120)))
	group(list, "Head", CFrame.new(x, 1.55, 0), side)
	local throat = { ball(rig, t, "Throat", V(1.05, 0.36, 0.95), V(x, 1.66, -0.12), C(222, 232, 160)) }
	group(throat, "Jaw", CFrame.new(x, 1.75, 0.3), side)
end
local function frogAvocado(rig, _accent)
	local t, l = rig.UpperTorso, rig.LowerTorso
	local skin, flesh, rim = C(54, 84, 38), C(198, 216, 110), C(150, 186, 72)
	ball(rig, t, "AvocadoSkin", V(2.5, 2.8, 2.0), V(0, -0.25, 0.05), skin)
	ball(rig, t, "AvocadoTop", V(1.7, 1.1, 1.5), V(0, 1.05, 0.05), skin)
	ball(rig, t, "FleshRim", V(2.15, 2.5, 0.45), V(0, -0.3, -0.82), rim)
	ball(rig, t, "Flesh", V(1.95, 2.3, 0.4), V(0, -0.3, -0.92), flesh)
	ball(rig, t, "Stone", V(0.95, 1.05, 0.45), V(0, -0.55, -1.05), C(126, 78, 42))
	ball(rig, t, "StoneShine", V(0.25, 0.3, 0.1), V(0.22, -0.3, -1.25), C(176, 120, 72))
	ball(rig, l, "AvocadoBottom", V(2.3, 1.2, 1.9), V(0, -0.2, 0.05), skin)
	for i = 1, 6 do
		-- (the skin's bumps)
		ball(rig, t, "SkinBump", V(0.22, 0.22, 0.14), V(math.cos(i) * 0.95, -0.9 + i * 0.32, 0.6 + math.sin(i) * 0.25), C(44, 70, 30))
	end
	frogHead(rig, t, -0.68, -1)
	frogHead(rig, t, 0.68, 1)
	limbs(rig, C(96, 176, 66), 0.42, 0.55)
	for _, side in { "Left", "Right" } do
		local hand = rig[side .. "Hand"]
		ball(rig, hand, "FrogPalm", V(0.5, 0.3, 0.5), V(0, -0.05, -0.05), C(96, 176, 66))
		for i = 1, 3 do
			ball(rig, hand, "ToePad", V(0.17, 0.17, 0.17), V((i - 2) * 0.2, -0.32, -0.15), C(150, 210, 100))
		end
		local foot = rig[side .. "Foot"]
		ball(rig, foot, "FrogFoot", V(0.75, 0.16, 1.35), V(0, -0.02, -0.35), C(96, 176, 66))
		for i = 1, 3 do
			ball(rig, foot, "ToePad", V(0.22, 0.18, 0.22), V((i - 2) * 0.28, 0, -1.0), C(150, 210, 100))
		end
	end
end

-- Chimpanzini Bananini --------------------------------------------------------------------------------------
-- Three monkey heads on a peeled banana: the peel hangs round its hips.
local function monkeyHead(rig, t, at: Vector3, side: number)
	local fur, face = C(104, 70, 42), C(222, 186, 140)
	local list = {}
	table.insert(list, ball(rig, t, "MonkeyHead", V(1.0, 1.0, 0.95), at, fur))
	table.insert(list, ball(rig, t, "MonkeyFace", V(0.74, 0.74, 0.4), at + V(0, -0.05, -0.36), face))
	table.insert(list, ball(rig, t, "Muzzle", V(0.56, 0.32, 0.32), at + V(0, -0.24, -0.5), face))
	table.insert(list, P(rig, t, "Mouth", V(0.3, 0.05, 0.05), at + V(0, -0.3, -0.66), INK))
	table.insert(list, ball(rig, t, "Brow", V(0.62, 0.12, 0.16), at + V(0, 0.2, -0.48), C(84, 56, 32)))
	for _, s in { -1, 1 } do
		table.insert(list, ball(rig, t, "MonkeyEar", V(0.18, 0.36, 0.3), at + V(s * 0.52, 0, 0), face))
		table.insert(list, ball(rig, t, "EyeWhite", V(0.18, 0.2, 0.1), at + V(s * 0.15, 0.06, -0.52), WHITE))
		table.insert(list, ball(rig, t, "Pupil", V(0.1, 0.12, 0.06), at + V(s * 0.15, 0.06, -0.57), INK))
	end
	group(list, "Head", CFrame.new(at.X, at.Y - 0.5, at.Z), side)
end
local function chimpanzini(rig, accent)
	local t, l = rig.UpperTorso, rig.LowerTorso
	local banana, peel, fur = C(246, 236, 182), C(242, 212, 60), C(104, 70, 42)
	ball(rig, t, "Banana", V(1.75, 2.4, 1.4), V(0, 0.1, 0), banana)
	ball(rig, t, "MonkeyChest", V(1.3, 1.1, 0.6), V(0, 0.45, -0.45), fur)
	for i = 1, 6 do
		local a = (i - 0.5) / 6 * math.pi * 2
		local x, z = math.sin(a) * 0.95, math.cos(a) * 0.68
		local p = ball(rig, l, "Peel", V(0.62, 1.9, 0.22), V(x, -0.55, z), peel, A(math.cos(a) * 0.35, a, -math.sin(a) * 0.35))
		p.Name = "BananaPeel"
		ball(rig, l, "PeelTip", V(0.18, 0.22, 0.12), V(x * 1.25, -1.45, z * 1.25), C(96, 72, 30))
	end
	neon(ball(rig, t, "BananaSpark", V(0.2, 0.2, 0.2), V(0, -0.6, -0.7), accent))
	monkeyHead(rig, t, V(0, 1.75, -0.05), 0.3)
	monkeyHead(rig, t, V(-0.95, 1.45, 0.05), -1)
	monkeyHead(rig, t, V(0.95, 1.45, 0.05), 1)
	limbs(rig, fur, 0.55, 0.6)
	paws(rig, C(222, 186, 140), 4)
	for _, side in { "Left", "Right" } do
		ball(rig, rig[side .. "Foot"], "MonkeyFoot", V(0.62, 0.3, 1.15), V(0, 0, -0.25), C(222, 186, 140))
	end
	tail(rig, fur, 5, 0.3, 2.4)
end

-- Tung Tung Tung Sahur (three) ----------------------------------------------------------------------------
-- An orange plank of a body with three log heads, each its own face; the bat.
local function logHead(rig, t, x: number, side: number)
	local wood = C(214, 116, 46)
	local list = {}
	local head = P(rig, t, "LogHead", V(1.15, 0.86, 0.86), V(x, 1.95, 0), wood, CYL, UPRIGHT)
	head.Material = Enum.Material.Wood
	table.insert(list, head)
	table.insert(list, P(rig, t, "LogTop", V(0.04, 0.78, 0.78), V(x, 2.53, 0), C(236, 160, 92), CYL, UPRIGHT))
	eyePair(rig, t, list, V(x, 2.1, -0.4), 0.18, 0.22, C(120, 60, 30))
	table.insert(list, ball(rig, t, "Nose", V(0.18, 0.26, 0.2), V(x, 1.92, -0.46), C(196, 104, 40)))
	for i = -2, 2 do
		table.insert(list, P(rig, t, "Smile", V(0.12, 0.05, 0.05), V(x + i * 0.1, 1.72 + i * i * 0.02, -0.44), C(66, 30, 12), nil, A(0, 0, i * 0.2)))
	end
	group(list, "Head", CFrame.new(x, 1.5, 0), side)
end
local function sahurTrio(rig, _accent)
	local t, l = rig.UpperTorso, rig.LowerTorso
	local wood = C(226, 122, 50)
	local body = P(rig, t, "Plank", V(2.3, 2.4, 1.2), V(0, 0.15, 0), wood)
	body.Material = Enum.Material.Wood
	for i = 1, 5 do
		P(rig, t, "Grain", V(0.04, 2.2, 0.02), V(-0.9 + i * 0.3, 0.15, -0.61), C(186, 92, 34)).Material = Enum.Material.Wood
	end
	P(rig, l, "PlankBase", V(2.2, 0.6, 1.15), V(0, -0.1, 0), wood).Material = Enum.Material.Wood
	logHead(rig, t, -0.82, -1)
	logHead(rig, t, 0, 0.3)
	logHead(rig, t, 0.82, 1)
	for _, side in { "Left", "Right" } do
		for _, seg in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do
			local b = rig[side .. seg]
			P(rig, b, "WoodenLimb", V(b.Size.Y + 0.14, 0.32, 0.32), V(0, 0, 0), wood, CYL, UPRIGHT).Material = Enum.Material.Wood
		end
		local hand = rig[side .. "Hand"]
		ball(rig, hand, "Palm", V(0.36, 0.36, 0.36), V(0, -0.02, 0), wood)
		P(rig, rig[side .. "Foot"], "WoodenFoot", V(0.55, 0.32, 1.0), V(0, 0, -0.2), wood).Material = Enum.Material.Wood
	end
	bat(rig)
end

-- Tralalero Tralala (two) -----------------------------------------------------------------------------------
-- An upright blue shark with two shark heads, a white belly and blue sneakers.
local function sharkHead(rig, t, x: number, side: number)
	local blue = C(66, 110, 168)
	local list = {}
	table.insert(list, ball(rig, t, "SharkHead", V(1.0, 1.1, 1.65), V(x, 1.95, -0.25), blue))
	table.insert(list, ball(rig, t, "SharkSnout", V(0.8, 0.62, 0.9), V(x, 1.92, -0.95), blue))
	table.insert(list, P(rig, t, "HeadFin", V(0.12, 0.7, 0.7), V(x, 2.65, 0.05), C(52, 92, 146), "Wedge", A(0, math.pi, 0)))
	table.insert(list, ball(rig, t, "OpenMouth", V(0.72, 0.2, 0.7), V(x, 1.62, -0.85), C(70, 26, 30)))
	for _, s in { -1, 1 } do
		table.insert(list, ball(rig, t, "SharkEye", V(0.14, 0.16, 0.14), V(x + s * 0.42, 2.12, -0.82), INK))
		for i = 1, 3 do
			table.insert(list, P(rig, t, "SharkTooth", V(0.08, 0.16, 0.08), V(x + s * (0.1 + i * 0.08), 1.7, -1.12 + i * 0.1), WHITE, "Wedge", A(0, 0, math.pi)))
		end
	end
	group(list, "Head", CFrame.new(x, 1.2, -0.1), side)
	local jaw = { ball(rig, t, "LowerJaw", V(0.7, 0.24, 0.85), V(x, 1.5, -0.8), C(206, 214, 220)) }
	group(jaw, "Jaw", CFrame.new(x, 1.55, -0.35), side)
end
local function twinShark(rig, accent)
	local t, l = rig.UpperTorso, rig.LowerTorso
	local blue, white = C(66, 110, 168), C(226, 232, 236)
	ball(rig, t, "SharkBody", V(2.05, 2.6, 1.6), V(0, 0.1, 0.05), blue)
	ball(rig, t, "WhiteBelly", V(1.45, 2.1, 0.5), V(0, -0.15, -0.62), white)
	ball(rig, l, "SharkHips", V(1.9, 1.0, 1.4), V(0, -0.1, 0.05), blue)
	neon(P(rig, t, "CryoGill", V(0.06, 0.5, 0.3), V(-1.0, 0.6, -0.1), accent))
	neon(P(rig, t, "CryoGill", V(0.06, 0.5, 0.3), V(1.0, 0.6, -0.1), accent))
	sharkHead(rig, t, -0.58, -1)
	sharkHead(rig, t, 0.58, 1)
	limbs(rig, blue, 0.6, 0.7)
	for _, side in { "Left", "Right" } do
		ball(rig, rig[side .. "Hand"], "FinHand", V(0.25, 0.8, 0.6), V(0, -0.2, 0), blue)
	end
	Skins.sneaker(rig, rig.LeftFoot, V(0, 0.05, 0))
	Skins.sneaker(rig, rig.RightFoot, V(0, 0.05, 0))
	local fins = tail(rig, blue, 3, 0.7, 0.2)
	local last = fins[#fins]
	local base = l.CFrame:PointToObjectSpace(last.CFrame.Position)
	local tailFins = {
		P(rig, l, "UpperTailFin", V(0.14, 1.3, 0.9), base + V(0, 0.55, 0.35), C(52, 92, 146), "Wedge", A(0, math.pi, 0)),
		P(rig, l, "LowerTailFin", V(0.14, 0.8, 0.7), base + V(0, -0.4, 0.35), C(52, 92, 146), "Wedge", A(0, 0, math.pi)),
	}
	group(tailFins, "Tail", CFrame.new(0, -0.1, 0.5), 1)
end

-- Brr Brr Patapim (three) ----------------------------------------------------------------------------------
-- A mossy trunk with three long-nosed faces, root limbs and huge bare feet.
local function treeHead(rig, t, at: Vector3, side: number, accent: Color3)
	local bark, face = C(112, 80, 46), C(206, 160, 104)
	local list = {}
	table.insert(list, ball(rig, t, "TreeHead", V(0.92, 1.0, 0.86), at, bark))
	table.insert(list, ball(rig, t, "MossCap", V(1.0, 0.55, 0.95), at + V(0, 0.4, 0.05), C(70, 118, 44)))
	table.insert(list, ball(rig, t, "TreeFace", V(0.64, 0.62, 0.3), at + V(0, -0.02, -0.33), face))
	table.insert(list, ball(rig, t, "LongNose", V(0.26, 0.72, 0.3), at + V(0, -0.3, -0.55), C(202, 146, 84), A(0.3, 0, 0)))
	table.insert(list, P(rig, t, "Mouth", V(0.3, 0.06, 0.05), at + V(0, -0.32, -0.46), INK))
	for _, s in { -1, 1 } do
		table.insert(list, ball(rig, t, "EyeWhite", V(0.17, 0.18, 0.08), at + V(s * 0.16, 0.08, -0.47), WHITE))
		table.insert(list, neon(ball(rig, t, "Iris", V(0.1, 0.11, 0.05), at + V(s * 0.16, 0.08, -0.51), accent)))
		table.insert(list, ball(rig, t, "Brow", V(0.24, 0.07, 0.08), at + V(s * 0.16, 0.22, -0.47), C(60, 90, 32), A(0, 0, -s * 0.3)))
	end
	group(list, "Head", CFrame.new(at.X, at.Y - 0.5, at.Z), side)
end
local function treeTrio(rig, accent)
	local t, l = rig.UpperTorso, rig.LowerTorso
	local bark, moss = C(98, 72, 42), C(74, 112, 48)
	ball(rig, t, "Trunk", V(2.15, 2.6, 1.6), V(0, 0.05, 0.05), bark)
	ball(rig, l, "TrunkBase", V(2.0, 1.0, 1.5), V(0, -0.15, 0.05), bark)
	for i = 1, 16 do
		local a = i * 2.39996
		ball(rig, t, "MossTuft", V(0.6, 0.62, 0.3), V(math.cos(a) * 0.95, -0.9 + (i % 8) * 0.28, math.sin(a) * 0.7), C(54 + (i % 4) * 8, 98 + (i % 5) * 9, 36), A(0.15, a, 0.3))
	end
	treeHead(rig, t, V(-0.85, 1.55, 0), -1, accent)
	treeHead(rig, t, V(0, 1.85, -0.05), 0.3, accent)
	treeHead(rig, t, V(0.85, 1.55, 0), 1, accent)
	for i = 1, 5 do
		local strand = ball(rig, t, "HangingMoss", V(0.12, 0.6, 0.12), V((i - 3) * 0.36, -1.0, -0.7), moss)
		animate(strand, "Moss", CFrame.new((i - 3) * 0.36, -0.7, -0.7), if i % 2 == 0 then -1 else 1)
	end
	for _, side in { "Left", "Right" } do
		for _, seg in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do
			local b = rig[side .. seg]
			ball(rig, b, "RootLimb", V(0.55, b.Size.Y + 0.22, 0.58), V(0, 0, 0), bark)
		end
		local hand = rig[side .. "Hand"]
		for i = 1, 4 do
			P(rig, hand, "Twig", V(0.1, 0.62, 0.1), V((i - 2.5) * 0.15, -0.3, -0.1), C(84, 60, 34), nil, A(0, 0, (i - 2.5) * 0.18))
		end
		Skins.barefoot(rig, rig[side .. "Foot"], C(206, 160, 104), 1.7)
	end
end

-- Frigo Camelo --------------------------------------------------------------------------------------------
-- A fridge on camel legs, two camel heads on long necks out of its top.
local function camelHead(rig, t, x: number, side: number)
	local tan, light = C(198, 152, 94), C(226, 192, 140)
	local list = {}
	table.insert(list, ball(rig, t, "CamelNeck", V(0.46, 1.35, 0.46), V(x, 2.0, -0.25), tan, A(-0.25, 0, -x * 0.25)))
	table.insert(list, ball(rig, t, "CamelHead", V(0.72, 0.62, 1.2), V(x * 1.15, 2.72, -0.72), tan))
	table.insert(list, ball(rig, t, "CamelSnout", V(0.58, 0.46, 0.5), V(x * 1.15, 2.62, -1.22), light))
	table.insert(list, ball(rig, t, "Lip", V(0.5, 0.14, 0.3), V(x * 1.15, 2.42, -1.3), C(170, 120, 72)))
	for _, s in { -1, 1 } do
		table.insert(list, ball(rig, t, "EyeWhite", V(0.18, 0.2, 0.12), V(x * 1.15 + s * 0.26, 2.86, -0.98), WHITE))
		table.insert(list, ball(rig, t, "Pupil", V(0.1, 0.12, 0.06), V(x * 1.15 + s * 0.28, 2.86, -1.04), INK))
		table.insert(list, ball(rig, t, "HeavyLid", V(0.24, 0.1, 0.16), V(x * 1.15 + s * 0.26, 2.96, -0.98), tan))
		table.insert(list, ball(rig, t, "CamelEar", V(0.12, 0.26, 0.12), V(x * 1.15 + s * 0.3, 3.0, -0.48), tan))
	end
	group(list, "Head", CFrame.new(x, 1.45, -0.2), side)
end
local function frigo(rig, accent)
	local t, l = rig.UpperTorso, rig.LowerTorso
	local enamel, steel = C(234, 238, 242), C(150, 158, 168)
	P(rig, t, "Fridge", V(2.15, 2.9, 1.55), V(0, 0.15, 0), enamel)
	P(rig, l, "FridgeBase", V(2.15, 0.6, 1.55), V(0, -0.1, 0), C(210, 214, 220))
	P(rig, t, "DoorSeam", V(2.17, 0.05, 0.05), V(0, 0.75, -0.78), C(150, 156, 164))
	P(rig, t, "SideSeam", V(0.05, 2.85, 0.05), V(-1.05, 0.15, -0.78), C(190, 196, 204))
	P(rig, t, "FreezerHandle", V(0.12, 0.5, 0.14), V(0.82, 1.15, -0.86), steel).Material = Enum.Material.Metal
	P(rig, t, "DoorHandle", V(0.12, 0.95, 0.14), V(0.82, -0.05, -0.86), steel).Material = Enum.Material.Metal
	P(rig, l, "Vent", V(1.6, 0.18, 0.04), V(0, -0.2, -0.79), C(80, 84, 92))
	local magnets = { C(232, 72, 64), C(64, 140, 232), C(240, 200, 56) }
	for i, color in magnets do
		ball(rig, t, "Magnet", V(0.24, 0.24, 0.08), V(-0.6 + i * 0.32, 0.3 - (i % 2) * 0.3, -0.8), color)
	end
	neon(P(rig, t, "FrostLight", V(1.4, 0.06, 0.04), V(0, 1.45, -0.79), accent))
	camelHead(rig, t, -0.55, -1)
	camelHead(rig, t, 0.55, 1)
	ball(rig, t, "Hump", V(0.8, 0.55, 0.7), V(0, 1.65, 0.35), C(198, 152, 94))
	local tan = C(198, 152, 94)
	limbs(rig, tan, 0.5, 0.5)
	for _, side in { "Left", "Right" } do
		ball(rig, rig[side .. "LowerLeg"], "Knee", V(0.6, 0.45, 0.6), V(0, 0.5, 0), C(170, 126, 76))
		ball(rig, rig[side .. "Hand"], "Hoof", V(0.5, 0.38, 0.55), V(0, -0.05, 0), C(64, 52, 44))
		ball(rig, rig[side .. "Foot"], "Hoof", V(0.7, 0.36, 0.85), V(0, 0.02, -0.12), C(64, 52, 44))
	end
end

-- Cappuccino Assassino ----------------------------------------------------------------------------------------
-- A takeaway coffee cup in a ninja mask, a knife in each of four hands.
local function cappuccino(rig, accent)
	local t, l, h = rig.UpperTorso, rig.LowerTorso, rig.Head
	local cup, sleeve, lid = C(242, 238, 230), C(156, 104, 62), C(70, 46, 34)
	P(rig, t, "Cup", V(2.7, 1.85, 1.85), V(0, 0.45, 0), cup, CYL, UPRIGHT)
	P(rig, l, "CupFoot", V(0.9, 1.55, 1.55), V(0, 0.05, 0), cup, CYL, UPRIGHT)
	P(rig, t, "Sleeve", V(1.0, 1.92, 1.92), V(0, -0.15, 0), sleeve, CYL, UPRIGHT)
	P(rig, t, "Lid", V(0.32, 2.0, 2.0), V(0, 1.92, 0), lid, CYL, UPRIGHT)
	P(rig, t, "LidTop", V(0.22, 1.5, 1.5), V(0, 2.15, 0), C(84, 58, 44), CYL, UPRIGHT)
	P(rig, t, "SipHole", V(0.1, 0.35, 0.12), V(0, 2.28, -0.5), INK)
	-- The mask: a black band with an eye slit, angry eyes, its tails behind.
	local face = {}
	table.insert(face, P(rig, t, "NinjaMask", V(0.75, 1.9, 1.9), V(0, 1.2, 0), INK, CYL, UPRIGHT))
	for _, s in { -1, 1 } do
		table.insert(face, ball(rig, t, "EyeWhite", V(0.42, 0.26, 0.12), V(s * 0.36, 1.2, -0.9), WHITE))
		table.insert(face, neon(ball(rig, t, "Iris", V(0.18, 0.18, 0.06), V(s * 0.33, 1.18, -0.96), accent)))
		table.insert(face, P(rig, t, "AngryBrow", V(0.48, 0.1, 0.08), V(s * 0.36, 1.42, -0.95), INK, nil, A(0, 0, s * 0.35)))
	end
	group(face, "Head", CFrame.new(0, 0.6, 0), 1)
	for _, s in { -1, 1 } do
		local ribbon = P(rig, t, "MaskTail", V(0.3, 0.08, 1.2), V(s * 0.25, 1.15, 1.35), INK, nil, A(-0.4, s * 0.25, 0))
		animate(ribbon, "Moss", CFrame.new(s * 0.25, 1.2, 0.8), s)
	end
	-- Thin black limbs and ninja feet; a knife in each hand.
	limbs(rig, INK, 0.32, 0.36)
	for _, side in { "Left", "Right" } do
		ball(rig, rig[side .. "Hand"], "Glove", V(0.4, 0.36, 0.4), V(0, 0, 0), INK)
		knife(rig, rig[side .. "Hand"], V(0, -0.3, -0.12), A(math.pi / 2, 0, 0)) -- (blade forward)
		ball(rig, rig[side .. "Foot"], "Tabi", V(0.55, 0.32, 1.0), V(0, 0, -0.18), C(40, 40, 46))
	end
	-- Two more arms out of its sides, knives raised: they twirl and slash.
	for _, s in { -1, 1 } do
		local arm = {}
		table.insert(arm, P(rig, t, "ExtraArm", V(1.5, 0.26, 0.26), V(s * 1.55, 0.95, -0.1), INK, CYL, A(0, 0, -s * 0.6)))
		table.insert(arm, ball(rig, t, "ExtraHand", V(0.36, 0.34, 0.36), V(s * 2.15, 1.45, -0.1), INK))
		knife(rig, t, V(s * 2.15, 1.62, -0.1), A(0, 0, math.pi), arm) -- (raised: the blade points up)
		group(arm, "Blade", CFrame.new(s * 1.05, 0.7, -0.1), s)
	end
end

Bosses.Builders = {
	TwinCat = twinCat,
	DragonCroc = dragonCroc,
	TwinDuck = twinDuck,
	FrogAvocado = frogAvocado,
	Chimpanzini = chimpanzini,
	SahurTrio = sahurTrio,
	TwinShark = twinShark,
	TreeTrio = treeTrio,
	Frigo = frigo,
	Cappuccino = cappuccino,
}

-- Dresses `rig` as boss `spec` (DungeonRules.Bosses). False when it isn't
-- one of these (BrainrotSkins has the room fighters).
function Bosses.apply(rig, spec, accent: Color3, boss: boolean?): boolean
	local build = spec and Bosses.Builders[spec.Shape]
	if not build then
		return false
	end
	for _, p in rig:GetChildren() do
		if p:IsA("BasePart") then
			p.Transparency = 1
		end
	end
	build(rig, accent)
	Skins.finish(rig, spec, boss)
	return true
end

return Bosses
