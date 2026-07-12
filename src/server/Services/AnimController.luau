--!strict
-- Server-side whole-body death topple for AI units.
-- Limb animation (walk cycles, swings, death limpness) is handled on the
-- client by UnitAnimator via Motor6D.Transform; the server only tilts and
-- drops the anchored Body so the corpse pose is authoritative and consistent
-- for all viewers.

local Match = require(script.Parent.Match)

local AnimController = {}

-- Death topple parameters
local TOPPLE_ANGLE_MAX = 90 -- degrees of X-axis tilt at full progress
local TOPPLE_DROP_MAX = 2 -- studs the body lowers at full progress

-- Applies a death topple animation: tilts the body on the X axis and lowers Y.
-- `progress` should go from 0 (just died) to 1 (fully toppled) over the death
-- duration.
function AnimController.applyDeathTopple(rec: Match.UnitRecord, progress: number)
	local body = rec.body
	if not body or not body.Parent then
		return
	end

	progress = math.clamp(progress, 0, 1)

	local tiltRad = math.rad(progress * TOPPLE_ANGLE_MAX)
	local yDrop = progress * TOPPLE_DROP_MAX

	local cf = body.CFrame
	local pos = cf.Position

	-- Preserve the flat facing direction, then apply tilt + drop around it
	local lookFlat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if lookFlat.Magnitude < 0.01 then
		lookFlat = Vector3.new(0, 0, -1)
	end
	lookFlat = lookFlat.Unit

	local dropped = Vector3.new(pos.X, pos.Y - yDrop, pos.Z)
	local baseCf = CFrame.lookAt(dropped, dropped + lookFlat)

	body.CFrame = baseCf * CFrame.Angles(tiltRad, 0, 0)
end

return AnimController
