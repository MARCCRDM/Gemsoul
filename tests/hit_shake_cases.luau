local now, callbacks, priorities = 0, {}, {}
local os = { clock = function() return now end }
local Enum = { RenderPriority = { Camera = { Value = 200 } } }
local RunService = {}
function RunService:BindToRenderStep(name, priority, fn) callbacks[name], priorities[name] = fn, priority end
function RunService:UnbindFromRenderStep(name) callbacks[name] = nil end
local mt = {}
local function rotation(x, y, z) return setmetatable({ X=x, Y=y, Z=z }, mt) end
mt.__mul = function(a,b) return rotation(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
local CFrame = { Angles = rotation }
local original = rotation(0,0,0)
local workspace = { CurrentCamera = { CFrame = original } }
local CombatFx = {}
-- The size of whatever's drawing (Modules/FxSize): 1, a player's.
local FxSize = { Size = 1 }
function FxSize.get()
	return FxSize.Size
end
local checks = 0
local function check(ok, message) checks+=1; assert(ok,message) end
local function frame(dt)
	now += dt
	if callbacks.CombatShakeRestore then callbacks.CombatShakeRestore() end
	if callbacks.CombatShake then callbacks.CombatShake() end
end
-- SHAKE HERE
CombatFx.hitShake(true, false)
frame(0)
local light = workspace.CurrentCamera.CFrame.X
check(light > math.rad(1), "Light sword hit is barely visible")
check(priorities.CombatShakeRestore < 200 and priorities.CombatShake > 201 and priorities.CombatShake < 203, "Shake must follow target lock and precede first-person arms")
frame(0.09)
check(math.abs(workspace.CurrentCamera.CFrame.X) < light, "Hit did not decay")
frame(0.1)
check(workspace.CurrentCamera.CFrame == original, "Camera retained a permanent shake offset")
check(next(callbacks)==nil, "Expired shake kept frame callbacks")
CombatFx.hitShake(true, true)
frame(0)
local heavy = workspace.CurrentCamera.CFrame.X
check(heavy > light and heavy < math.rad(4), "Heavy hit is not stronger or is excessive")
CombatFx.hitShake(false, false)
frame(0)
check(workspace.CurrentCamera.CFrame.X == heavy, "Weaker hit replaced strong active shake")
frame(0.3)
CombatFx.hitShake(false, false)
frame(0)
check(workspace.CurrentCamera.CFrame.X < light, "Non-sword damage got the stronger sword kick")
local otherController = rotation(1,1,1)
workspace.CurrentCamera.CFrame = otherController
frame(0.3)
check(workspace.CurrentCamera.CFrame == otherController, "Cleanup overwrote another camera controller")
workspace.CurrentCamera = nil
CombatFx.hitShake(true, true)
frame(0.05)
frame(0.3)
check(next(callbacks)==nil, "Missing camera prevented cleanup")
-- A repeated hit extends feedback without stacking offsets or callbacks.
workspace.CurrentCamera = { CFrame = original }
CombatFx.hitShake(true, false)
frame(0.1)
CombatFx.hitShake(true, true)
frame(0)
check(workspace.CurrentCamera.CFrame.X == heavy, "Repeated hit stacked camera offsets")
frame(0.3)
check(workspace.CurrentCamera.CFrame == original and next(callbacks)==nil, "Repeated hits never settled")
-- A creature's (FxSize: a kaiju's, a critter's) shakes by its size squared:
-- a half-size one's heavy blow a quarter as hard as yours.
FxSize.Size = 0.5
CombatFx.hitShake(true, true)
FxSize.Size = 1
frame(0)
check(
	math.abs(workspace.CurrentCamera.CFrame.X - heavy / 4) < 1e-9,
	"A half-size creature's shake wasn't a quarter of a player's"
)
frame(0.3)
check(workspace.CurrentCamera.CFrame == original and next(callbacks) == nil, "A creature's shake never settled")
print("PASS: " .. checks .. " sword-hit camera checks")
