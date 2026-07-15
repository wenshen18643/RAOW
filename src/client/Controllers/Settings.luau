--!strict
-- Shared client preferences. Changes apply immediately and are debounced before
-- being persisted by the server, avoiding remote spam while sliders are dragged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Settings = {}

local values: { [string]: any } = {
	mouseSensitivity = 0.35,
	sfxVolume = 1,
	uiVolume = 1,
	reducedEffects = false,
	showDamageNumbers = true,
}

local revision: { [string]: number } = {}
local listeners: { (string, any) -> () } = {}

function Settings.get(key: string): any
	return values[key]
end

function Settings.set(key: string, value: any, persist: boolean?)
	if values[key] == nil or values[key] == value then return end
	values[key] = value
	for _, listener in listeners do listener(key, value) end
	if persist == false then return end
	revision[key] = (revision[key] or 0) + 1
	local expected = revision[key]
	task.delay(0.5, function()
		if revision[key] == expected then Remotes.UpdateSettings:FireServer(key, value) end
	end)
end

function Settings.apply(saved: any)
	if typeof(saved) ~= "table" then return end
	for key in values do
		local value = saved[key]
		if value ~= nil then Settings.set(key, value, false) end
	end
end

function Settings.onChanged(listener: (string, any) -> ())
	table.insert(listeners, listener)
end

return Settings
