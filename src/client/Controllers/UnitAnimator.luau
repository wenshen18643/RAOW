--!strict
-- Client-side procedural animation for unit rigs built by UnitFactory.
-- The server moves each unit's anchored Body and sets attributes
-- (AnimState, AttackCount, MoveSpeed, Rig, Role); this controller drives
-- Motor6D.Transform every render frame. Transform is not replicated, so all
-- of this is free on the network and costs the server nothing.
--
-- Rigs and their joints (see UnitFactory):
--   infantry:  RootJoint, Neck, ShoulderL, ShoulderR, HipL, HipR
--   quadruped: Neck, QLegFL, QLegFR, QLegBL, QLegBR
--   catapult:  ThrowArm, WheelFL, WheelFR, WheelBL, WheelBR
--   tank:      Barrel
--   mech:      MechHipL, MechHipR, CannonL, CannonR

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UnitAnimator = {}

-- Optional hooks other controllers can set (e.g. Audio): fired when a unit's
-- attack animation starts / when a unit dies. Kept as plain callbacks to
-- avoid a signal dependency.
UnitAnimator.onUnitAttack = nil :: ((body: BasePart, role: string, age: number, rig: string) -> ())?
UnitAnimator.onUnitDeath = nil :: ((body: BasePart) -> ())?

local LOD_DISTANCE = 300 -- studs beyond which units are not animated
local ATTACK_DURATION = 0.45
local DEATH_EASE = 0.35

type Entry = {
	model: Model,
	body: BasePart,
	joints: { [string]: Motor6D },
	rig: string,
	role: string,
	phase: number, -- per-unit walk phase offset so armies don't march in lockstep
	lastAttackCount: number,
	attackStart: number?,
	deathStart: number?,
	wheelRoll: number,
	lastPos: Vector3,
	conns: { RBXScriptConnection },
}

local entries: { [Model]: Entry } = {}
local rng = Random.new()

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

--------------------------------------------------------------------------------
-- Pose functions per rig
--------------------------------------------------------------------------------

local function poseInfantry(e: Entry, now: number, state: string, moving: boolean)
	local j = e.joints
	local root, neck = j.RootJoint, j.Neck
	local sL, sR = j.ShoulderL, j.ShoulderR
	local hL, hR = j.HipL, j.HipR
	if not (root and neck and sL and sR and hL and hR) then
		return
	end

	-- death: ease into a limp sprawl while the server topples the body
	if e.deathStart then
		local p = easeOut(math.clamp((now - e.deathStart) / DEATH_EASE, 0, 1))
		root.Transform = CFrame.Angles(0, 0, math.rad(6 * p))
		neck.Transform = CFrame.Angles(math.rad(-25 * p), 0, math.rad(15 * p))
		sL.Transform = CFrame.Angles(0, 0, math.rad(-75 * p))
		sR.Transform = CFrame.Angles(0, 0, math.rad(70 * p))
		hL.Transform = CFrame.Angles(math.rad(-15 * p), 0, 0)
		hR.Transform = CFrame.Angles(math.rad(20 * p), 0, 0)
		return
	end

	local moveSpeed = (e.body:GetAttribute("MoveSpeed") :: number?) or 8
	local t = now * math.max(moveSpeed, 4) * 1.5 + e.phase
	local swing = moving and math.sin(t) or 0

	-- base locomotion / idle layer
	local legAmp, armAmp = 0.95, 0.7
	local bob = moving and math.abs(math.cos(t)) * 0.22 or math.sin(now * 2 + e.phase) * 0.03
	local lean = moving and 6 or 0
	hL.Transform = CFrame.Angles(swing * legAmp, 0, 0)
	hR.Transform = CFrame.Angles(-swing * legAmp, 0, 0)
	local armL = -swing * armAmp
	local armR = swing * armAmp
	root.Transform = CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(lean), 0, swing * 0.05)
	neck.Transform = CFrame.Angles(math.rad(-lean * 0.6), swing * 0.08, 0)

	-- combat stance layer: ranged units keep the weapon arm slightly raised
	if state == "combat" and e.role == "ranged" then
		armR = math.rad(18)
		armL = math.rad(8)
	end

	-- attack overlay
	if e.attackStart then
		local p = (now - e.attackStart) / ATTACK_DURATION
		if p >= 1 then
			e.attackStart = nil
		elseif e.role == "melee" then
			-- windup back, sharp overhead slam forward, recover
			local a: number
			if p < 0.35 then
				a = -60 * easeOut(p / 0.35)
			elseif p < 0.6 then
				a = -60 + 190 * ((p - 0.35) / 0.25)
			else
				a = 130 * (1 - easeOut((p - 0.6) / 0.4))
			end
			armR = math.rad(a)
			armL = math.rad(-a * 0.15)
			local punch = p >= 0.35 and p < 0.7 and math.rad(8) or 0
			root.Transform = root.Transform * CFrame.Angles(punch, 0, 0)
		else
			-- ranged/aim recoil: arm kicks up, torso rocks back
			local kick = math.sin(math.min(p, 0.5) * math.pi * 2) -- one pulse in first half
			armR += math.rad(14) * kick
			root.Transform = root.Transform * CFrame.Angles(math.rad(-4) * kick, 0, 0)
		end
	end

	sL.Transform = CFrame.Angles(armL, 0, 0)
	sR.Transform = CFrame.Angles(armR, 0, 0)
end

local function poseQuadruped(e: Entry, now: number, _state: string, moving: boolean)
	local j = e.joints
	local neck = j.Neck
	if e.deathStart then
		local p = easeOut(math.clamp((now - e.deathStart) / DEATH_EASE, 0, 1))
		if neck then
			neck.Transform = CFrame.Angles(math.rad(-30 * p), 0, math.rad(10 * p))
		end
		for _, name in { "QLegFL", "QLegFR", "QLegBL", "QLegBR" } do
			local leg = j[name]
			if leg then
				leg.Transform = CFrame.Angles(math.rad(rng:NextNumber(10, 25) * p), 0, 0)
			end
		end
		return
	end

	local moveSpeed = (e.body:GetAttribute("MoveSpeed") :: number?) or 5
	local t = now * math.max(moveSpeed, 3) * 1.4 + e.phase
	local swing = moving and math.sin(t) * 0.55 or 0
	-- diagonal gait: FL+BR move together, FR+BL opposite
	local pairs_: { [string]: number } = { QLegFL = 1, QLegBR = 1, QLegFR = -1, QLegBL = -1 }
	for name, dir in pairs_ do
		local leg = j[name]
		if leg then
			leg.Transform = CFrame.Angles(swing * dir, 0, 0)
		end
	end

	local headSway = moving and math.sin(t * 0.5) * 0.05 or math.sin(now * 1.5 + e.phase) * 0.04
	local headPitch = 0
	if e.attackStart then
		local p = (now - e.attackStart) / ATTACK_DURATION
		if p >= 1 then
			e.attackStart = nil
		elseif p < 0.4 then
			headPitch = 35 * easeOut(p / 0.4) -- rear head up
		elseif p < 0.7 then
			headPitch = 35 - 60 * ((p - 0.4) / 0.3) -- slam tusks down
		else
			headPitch = -25 * (1 - easeOut((p - 0.7) / 0.3))
		end
	end
	if neck then
		neck.Transform = CFrame.Angles(math.rad(headPitch), headSway, 0)
	end
end

local function poseCatapult(e: Entry, now: number, _state: string, moving: boolean, dt: number)
	local j = e.joints
	if e.deathStart then
		return -- server topple reads fine for siege equipment
	end
	-- wheels roll with actual ground movement
	local pos = e.body.Position
	local moved = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(e.lastPos.X, 0, e.lastPos.Z)).Magnitude
	e.lastPos = pos
	if moving and dt > 0 then
		e.wheelRoll += moved / 0.8 -- wheel radius 0.8
	end
	for _, name in { "WheelFL", "WheelFR", "WheelBL", "WheelBR" } do
		local wheel = j[name]
		if wheel then
			wheel.Transform = CFrame.Angles(e.wheelRoll, 0, 0)
		end
	end

	local arm = j.ThrowArm
	if arm then
		local a = 0
		if e.attackStart then
			local p = (now - e.attackStart) / ATTACK_DURATION
			if p >= 1 then
				e.attackStart = nil
			elseif p < 0.3 then
				a = 8 * easeOut(p / 0.3) -- drag back
			elseif p < 0.55 then
				a = 8 - 90 * ((p - 0.3) / 0.25) -- fling forward
			else
				a = -82 * (1 - easeOut((p - 0.55) / 0.45))
			end
		end
		arm.Transform = CFrame.Angles(math.rad(a), 0, 0)
	end
end

local function poseTank(e: Entry, now: number)
	local barrel = e.joints.Barrel
	if not barrel or e.deathStart then
		return
	end
	local recoil = 0
	if e.attackStart then
		local p = (now - e.attackStart) / ATTACK_DURATION
		if p >= 1 then
			e.attackStart = nil
		else
			recoil = 0.7 * math.exp(-p * 6) -- sharp kick, exponential return
		end
	end
	barrel.Transform = CFrame.new(0, 0, recoil)
end

local function poseMech(e: Entry, now: number, _state: string, moving: boolean)
	local j = e.joints
	local hipL, hipR = j.MechHipL, j.MechHipR
	if e.deathStart then
		if hipL and hipR then
			local p = easeOut(math.clamp((now - e.deathStart) / DEATH_EASE, 0, 1))
			hipL.Transform = CFrame.Angles(math.rad(20 * p), 0, 0)
			hipR.Transform = CFrame.Angles(math.rad(-15 * p), 0, 0)
		end
		return
	end
	local moveSpeed = (e.body:GetAttribute("MoveSpeed") :: number?) or 4
	local t = now * math.max(moveSpeed, 3) * 1.3 + e.phase
	-- stompy square-ish gait
	local raw = moving and math.sin(t) or 0
	local swing = math.sign(raw) * math.abs(raw) ^ 0.6 * 0.55
	if hipL and hipR then
		hipL.Transform = CFrame.Angles(swing, 0, 0)
		hipR.Transform = CFrame.Angles(-swing, 0, 0)
	end
	-- alternating cannon recoil
	if e.attackStart then
		local p = (now - e.attackStart) / ATTACK_DURATION
		if p >= 1 then
			e.attackStart = nil
		else
			local recoil = 0.6 * math.exp(-p * 6)
			local cannon = (e.lastAttackCount % 2 == 0) and j.CannonL or j.CannonR
			if cannon then
				cannon.Transform = CFrame.new(0, 0, recoil)
			end
		end
	else
		if j.CannonL then
			j.CannonL.Transform = CFrame.new()
		end
		if j.CannonR then
			j.CannonR.Transform = CFrame.new()
		end
	end
end

--------------------------------------------------------------------------------
-- Tracking
--------------------------------------------------------------------------------

local function untrack(model: Model)
	local e = entries[model]
	if not e then
		return
	end
	for _, c in e.conns do
		c:Disconnect()
	end
	entries[model] = nil
end

local REQUIRED_JOINTS: { [string]: { string } } = {
	infantry = { "RootJoint", "Neck", "ShoulderL", "ShoulderR", "HipL", "HipR" },
	quadruped = { "Neck", "QLegFL", "QLegFR", "QLegBL", "QLegBR" },
	catapult = { "ThrowArm", "WheelFL", "WheelFR", "WheelBL", "WheelBR" },
	tank = { "Barrel" },
	mech = { "MechHipL", "MechHipR", "CannonL", "CannonR" },
}

local function collectJoints(model: Model): { [string]: Motor6D }
	local joints: { [string]: Motor6D } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	return joints
end

local function hasRequiredJoints(rig: string, joints: { [string]: Motor6D }): boolean
	local required = REQUIRED_JOINTS[rig]
	if not required then
		return true
	end
	for _, name in required do
		if not joints[name] then
			return false
		end
	end
	return true
end

local function track(model: Model)
	if entries[model] then
		return
	end
	task.spawn(function()
		local body = model:WaitForChild("Body", 5) :: BasePart?
		if not body or not model.Parent then
			return
		end
		-- The rig attributes are set on Body, but joints may stream in after the
		-- model is parented. Wait until all expected joints for this rig exist.
		local rig: string = (body:GetAttribute("Rig") :: string?) or "infantry"
		local joints = collectJoints(model)
		local timeout = os.clock() + 3
		while not hasRequiredJoints(rig, joints) and os.clock() < timeout and model.Parent do
			task.wait(0.03)
			joints = collectJoints(model)
			rig = (body:GetAttribute("Rig") :: string?) or rig
		end
		if not model.Parent then
			return
		end
		local e: Entry = {
			model = model,
			body = body,
			joints = joints,
			rig = (body:GetAttribute("Rig") :: string?) or "infantry",
			role = (body:GetAttribute("Role") :: string?) or "melee",
			phase = rng:NextNumber(0, math.pi * 2),
			lastAttackCount = (body:GetAttribute("AttackCount") :: number?) or 0,
			attackStart = nil,
			deathStart = nil,
			wheelRoll = 0,
			lastPos = body.Position,
			conns = {},
		}
		table.insert(e.conns, body:GetAttributeChangedSignal("AttackCount"):Connect(function()
			e.lastAttackCount = (body:GetAttribute("AttackCount") :: number?) or 0
			e.attackStart = os.clock()
			local onAttack = UnitAnimator.onUnitAttack
			if onAttack then
				onAttack(body, e.role, (body:GetAttribute("Age") :: number?) or 1, e.rig)
			end
		end))
		table.insert(e.conns, body:GetAttributeChangedSignal("AnimState"):Connect(function()
			if body:GetAttribute("AnimState") == "death" then
				e.deathStart = os.clock()
				local onDeath = UnitAnimator.onUnitDeath
				if onDeath then
					onDeath(body)
				end
			else
				e.deathStart = nil
			end
		end))
		if body:GetAttribute("AnimState") == "death" then
			e.deathStart = os.clock()
		end
		entries[model] = e
	end)
end

local function watchFolder(folder: Instance)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			track(child)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			track(child)
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			untrack(child)
		end
	end)
end

function UnitAnimator.start()
	-- the Units folder is created lazily by the server on first spawn
	local existing = Workspace:FindFirstChild("Units")
	if existing then
		watchFolder(existing)
	else
		local conn: RBXScriptConnection
		conn = Workspace.ChildAdded:Connect(function(child)
			if child.Name == "Units" and child:IsA("Folder") then
				conn:Disconnect()
				watchFolder(child)
			end
		end)
	end

	RunService.RenderStepped:Connect(function(dt)
		local cam = Workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		local now = os.clock()
		for model, e in entries do
			if not e.body.Parent then
				untrack(model)
				continue
			end
			if (e.body.Position - camPos).Magnitude > LOD_DISTANCE then
				continue
			end
			local state = (e.body:GetAttribute("AnimState") :: string?) or "walk"
			local moving = state == "walk"
			if e.rig == "infantry" then
				poseInfantry(e, now, state, moving)
			elseif e.rig == "quadruped" then
				poseQuadruped(e, now, state, moving)
			elseif e.rig == "catapult" then
				poseCatapult(e, now, state, moving, dt)
			elseif e.rig == "tank" then
				poseTank(e, now)
			elseif e.rig == "mech" then
				poseMech(e, now, state, moving)
			end
		end
	end)
end

return UnitAnimator
