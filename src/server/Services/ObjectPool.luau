--!strict
-- Generic object pool for recycling Roblox Models (e.g. unit model recycling).
-- Models are stored by a string key in per-key buckets, with a configurable
-- maximum capacity. Acquired models are reparented out of nil; released models
-- are hidden by parenting to nil and are ready for reuse.

local ObjectPool = {}

-- Staging folder used as a temporary parent for acquired models before the
-- caller repositions them.
local stagingFolder: Folder? = nil

local function getStagingFolder(): Folder
	if not stagingFolder or not stagingFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "_PoolStaging"
		f.Parent = workspace
		stagingFolder = f
	end
	return stagingFolder :: Folder
end

export type Pool = {
	maxPerKey: number,
	buckets: { [string]: { Model } },
}

-- Creates a new object pool.
-- maxPerKey: maximum number of models stored per key (defaults to 10).
function ObjectPool.new(maxPerKey: number?): Pool
	return {
		maxPerKey = maxPerKey or 10,
		buckets = {},
	}
end

-- Acquires a recycled model from the pool for the given key.
-- Returns nil if no models are available for that key.
-- The model is reparented to a staging folder so it exists in the DataModel;
-- the caller is responsible for repositioning and further setup.
function ObjectPool.acquire(pool: Pool, key: string): Model?
	local bucket = pool.buckets[key]
	if not bucket or #bucket == 0 then
		return nil
	end

	-- Pop the last model for O(1) removal
	local model = table.remove(bucket) :: Model
	model.Parent = getStagingFolder()

	-- Restore visibility: reset transparency on all BaseParts that were hidden
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- Body (PrimaryPart) stays invisible (Transparency 1); decorative
			-- parts are restored to their original transparency stored on release.
			local origTransparency = descendant:GetAttribute("_PoolOrigTransparency")
			if origTransparency ~= nil then
				descendant.Transparency = origTransparency :: number
				descendant:SetAttribute("_PoolOrigTransparency", nil)
			end
		end
	end

	return model
end

-- Returns a model to the pool under the given key.
-- The model is hidden by parenting to nil and each BasePart's transparency is
-- stored so it can be restored on acquire. If the bucket is already full
-- (>= maxPerKey), the model is destroyed instead.
function ObjectPool.release(pool: Pool, key: string, model: Model)
	local bucket = pool.buckets[key]
	if not bucket then
		bucket = {}
		pool.buckets[key] = bucket
	end

	-- If the bucket is full, destroy the model outright
	if #bucket >= pool.maxPerKey then
		model:Destroy()
		return
	end

	-- Save each BasePart's current transparency and then hide it
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant:SetAttribute("_PoolOrigTransparency", descendant.Transparency)
			descendant.Transparency = 1
		end
	end

	-- Parent to nil to fully remove from the DataModel (invisible, no physics)
	model.Parent = nil

	table.insert(bucket, model)
end

-- Destroys ALL pooled models and empties every bucket.
function ObjectPool.clear(pool: Pool)
	for key, bucket in pool.buckets do
		for _, model in bucket do
			model:Destroy()
		end
		pool.buckets[key] = nil
	end
	-- Ensure we start fresh
	pool.buckets = {}
end

return ObjectPool
