-- Who sits where, for the server and every client alike.
--
-- Seat.Occupant and Humanoid.SeatPart don't replicate: each machine works
-- them out for itself, so the side that didn't seat someone can see nil
-- (the Outpost's Pilot prompt seats players from the server). The SeatWeld
-- the seat makes does replicate (Part0 the seat, Part1 the body's root), so
-- when those properties are empty the weld answers instead.
local Seating = {}

local function read(instance: Instance, key: string): any
	local ok, value = pcall(function()
		return (instance :: any)[key]
	end)
	return if ok then value else nil
end

local function isSeat(part: any): boolean
	if typeof(part) ~= "Instance" then
		return part ~= nil -- (test stand-ins)
	end
	return part:IsA("Seat") or part:IsA("VehicleSeat")
end

-- The humanoid sitting in `seat`, if any.
function Seating.occupant(seat: Instance?): Humanoid?
	if not seat then
		return nil
	end
	local occupant = read(seat, "Occupant")
	if occupant then
		return occupant
	end
	local weld = seat:FindFirstChild("SeatWeld")
	local body = weld and read(weld, "Part1")
	local character = body and body.Parent
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

-- The seat `humanoid` sits in, if any.
function Seating.seatOf(humanoid: Humanoid?): BasePart?
	if not humanoid then
		return nil
	end
	local seat = read(humanoid, "SeatPart")
	if seat then
		return seat
	end
	local character = humanoid.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local ok, joints = pcall(function()
		return root and (root :: any):GetJoints()
	end)
	for _, joint in if ok and joints then joints else {} do
		if joint.Name == "SeatWeld" then
			local part0 = read(joint, "Part0")
			if part0 and part0 ~= root and isSeat(part0) then
				return part0
			end
		end
	end
	return nil
end

-- Whether `humanoid` sits in `seat`.
function Seating.sits(humanoid: Humanoid?, seat: Instance?): boolean
	if not humanoid or not seat then
		return false
	end
	return Seating.seatOf(humanoid) == seat or Seating.occupant(seat) == humanoid
end

return Seating
