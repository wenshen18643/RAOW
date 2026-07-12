--!strict
-- Structured server telemetry plus Roblox custom analytics for player events.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")

local Telemetry = {}
local counters: { [string]: number } = {}

local function structured(name: string, fields: { [string]: any }?)
	local payload = fields or {}
	payload.event = name
	payload.jobId = game.JobId
	payload.placeId = game.PlaceId
	payload.time = os.time()
	local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
	print(ok and `[Telemetry] {encoded}` or `[Telemetry] {name}`)
end

function Telemetry.event(player: Player?, name: string, value: number?, fields: { [string]: any }?)
	structured(name, fields)
	if player then
		pcall(function()
			AnalyticsService:LogCustomEvent(player, name, value or 1)
		end)
	end
end

function Telemetry.count(name: string, amount: number?)
	counters[name] = (counters[name] or 0) + (amount or 1)
end

task.spawn(function()
	while true do
		task.wait(60)
		if next(counters) then
			structured("server_counters", table.clone(counters))
			table.clear(counters)
		end
	end
end)

return Telemetry
