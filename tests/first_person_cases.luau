local count = 0
local function check(value, message)
	count += 1
	assert(value, message)
end
View.start()
check(player.CameraMode == "First" and player.CameraMaxZoomDistance == 0.5, "Camera did not enter first person")
check(camera.FieldOfView == 75 and bound ~= nil, "View not bound after camera")
View.start()
check(bindCount == 1, "Repeated entry bound twice")
bound()
check(part.LocalTransparencyModifier == 1, "Body obstructs camera")
check(input.MouseBehavior == "Locked" and not input.MouseIconEnabled, "Mouse not captured")
View.setCursorFree(true)
bound()
check(input.MouseBehavior == "Free" and input.MouseIconEnabled, "Cursor cannot access leave button")
View.setCursorFree(false)
bound()
check(input.MouseBehavior == "Locked", "Cursor did not recapture")
removalCallback(part)
check(part.LocalTransparencyModifier == 0.25, "Removed equipment visibility not restored")
View.stop()
check(removalDisconnected, "Removal listener leaked")
check(bound == nil and disconnected, "Camera cleanup leaked render or character connection")
check(part.LocalTransparencyModifier == 0.25, "Body visibility not restored")
check(player.CameraMode == "Classic" and player.CameraMinZoomDistance == 1 and player.CameraMaxZoomDistance == 80, "Zoom settings not restored")
check(camera.FieldOfView == 62 and input.MouseBehavior == "Free" and input.MouseIconEnabled, "View settings not restored")
View.stop()
View.start()
bound()
View.stop()
check(bindCount == 2 and part.LocalTransparencyModifier == 0.25 and bound == nil, "Second session cleanup failed")
-- Entered on a frame that had the cursor locked and the camera in first
-- person (a spar's kit swapped back and forth in the lobby): leaving never
-- hands back the lock, nor first person.
input.MouseBehavior, input.MouseIconEnabled = "Locked", false
player.CameraMode = "First"
View.start()
bound()
View.stop()
check(input.MouseBehavior == "Free" and input.MouseIconEnabled, "Leaving the view left the mouse locked")
check(player.CameraMode == "Classic", "Leaving the view left the camera in first person")
-- Back out to third person where it was. The fight's view leaves Roblox's
-- camera at its closest (and a phone can't wheel back out), so the zoom is
-- held at the distance it had, the camera put behind you at the pitch it
-- had, and let go once it's there. In a mining world the zoom you get back
-- is the world's own range, never the arrival's hold on it.
tpRange, tpHome = { 6, 40 }, 18
player.CameraMode, player.CameraMinZoomDistance, player.CameraMaxZoomDistance = "Classic", 18, 40 -- (the arrival's hold)
local focus = Vector3.new(0, 5, 0)
camera.Focus = { Position = focus }
camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 18 * math.sin(0.4), 18 * math.cos(0.4)), focus)
View.start()
check(player.CameraMode == "First" and player.CameraMaxZoomDistance == 0.5, "The fight's view didn't start")
camera.CFrame = CFrame.lookAt(focus, focus + Vector3.new(1, 0, 0)) -- (in the fight: turned, looking level)
View.stop()
check(player.CameraMode == "Classic" and player.CameraMaxZoomDistance == 40, "Third person wasn't back")
check(player.CameraMinZoomDistance == 18 and backOutStep ~= nil, "The zoom wasn't held at the distance it had")
local back = camera.CFrame
check(math.abs((back.Position - focus).Magnitude - 18) < 1e-6, "The camera wasn't put back out where it was")
check(
	math.abs(back.LookVector.Y + math.sin(0.4)) < 1e-6 and back.LookVector.X > 0.5,
	"The camera isn't behind you, looking the way you faced, at the pitch it had"
)
backOutStep()
check(backOutStep == nil and player.CameraMinZoomDistance == 6, "The hold never let go, or kept the arrival's minimum")
-- Back in before it got there (knocked down, then up again): the distance
-- it was going to is kept, and its hold let go.
View.start()
camera.CFrame = CFrame.lookAt(focus, focus + Vector3.new(0, 0, -1))
View.stop()
check(backOutStep ~= nil, "No way back out the second time")
camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, 6), focus) -- (still on its way out)
View.start()
check(backOutStep == nil and player.CameraMode == "First", "Coming back in left the hold on")
camera.CFrame = CFrame.lookAt(focus, focus + Vector3.new(0, 0, -1))
View.stop()
check(player.CameraMinZoomDistance == 18, "Back in before it got there, the distance it was going to was lost")
backOutStep()
check(player.CameraMinZoomDistance == 6, "The second hold never let go")
-- Something else setting the zoom meanwhile (a scene's own camera) keeps it.
View.start()
View.stop()
player.CameraMinZoomDistance = 12
backOutStep()
check(player.CameraMinZoomDistance == 12, "Letting go stamped over someone else's zoom")
-- A scene's own shot (a scripted camera) right after: the zoom is held,
-- but the camera isn't moved.
View.start()
camera.CFrame = CFrame.lookAt(focus, focus + Vector3.new(0, 0, -1))
camera.CameraType = "Scriptable"
local shot = camera.CFrame
View.stop()
check(camera.CFrame == shot, "Moved a scene's scripted camera")
camera.CameraType = "Custom"
camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, player.CameraMinZoomDistance), focus) -- (there now)
backOutStep()
check(backOutStep == nil and player.CameraMinZoomDistance == 6, "The hold after a scripted shot never let go")
-- Already at its closest before the fight: nothing to hold.
tpRange, tpHome = {}, nil
player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 6, 40
camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, 6), focus)
View.start()
View.stop()
check(backOutStep == nil and player.CameraMinZoomDistance == 6, "Held the zoom with nowhere to back out to")
print("PASS: " .. count .. " first-person camera, cursor and visibility lifecycle checks (and backing out to third person)")
