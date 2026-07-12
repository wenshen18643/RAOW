--!strict
-- Melee weapon arc raycasting for the hero's melee weapons.
-- Fires a fan of 5 rays spread across a ±30° horizontal arc centered on a
-- direction vector, simulating a wide melee weapon swing. Hits are
-- deduplicated by the Model ancestor of the struck part.

local RaycastHitbox = {}

-- The five arc angles (degrees) relative to the center direction, rotated
-- around the world Y axis for a horizontal sweep.
local ARC_ANGLES = { -30, -15, 0, 15, 30 }

export type HitResult = {
	part: BasePart,
	position: Vector3,
}

-- Rotates a direction vector around the world Y axis by the given angle in
-- degrees. Only the horizontal (XZ) component is rotated; Y is preserved.
local function rotateAroundY(dir: Vector3, angleDeg: number): Vector3
	local angleRad = math.rad(angleDeg)
	local cosA = math.cos(angleRad)
	local sinA = math.sin(angleRad)
	return Vector3.new(
		dir.X * cosA - dir.Z * sinA,
		dir.Y,
		dir.X * sinA + dir.Z * cosA
	)
end

-- Fires a fan of 5 rays in a ±30° horizontal arc centered on `direction`.
-- Each ray is `range` studs long. Returns all unique hits, deduplicated by
-- the Model ancestor of the hit part.
--
-- @param origin      The world-space origin of the swing
-- @param direction   The center aim direction (does not need to be a unit vector)
-- @param range       How far each ray extends, in studs
-- @param excludeList Instances to exclude from the raycast (e.g. the hero's character)
-- @return            Array of HitResult tables with part and position fields
function RaycastHitbox.swingArc(origin: Vector3, direction: Vector3, range: number, excludeList: { Instance }): { HitResult }
	-- Normalize the direction so arc rotations are predictable
	local dirUnit = direction.Unit

	-- Configure raycast params: Exclude mode with the caller's exclude list
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList

	-- Track which Model ancestors have already been recorded to deduplicate
	local hitModels: { [Model]: boolean } = {}
	local results: { HitResult } = {}

	for _, angleDeg in ARC_ANGLES do
		local rayDir = rotateAroundY(dirUnit, angleDeg) * range
		local result = workspace:Raycast(origin, rayDir, params)

		if result then
			-- Deduplicate by the Model ancestor of the hit part
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			if model and not hitModels[model] then
				hitModels[model] = true
				table.insert(results, {
					part = result.Instance,
					position = result.Position,
				})
			end
		end
	end

	return results
end

return RaycastHitbox
