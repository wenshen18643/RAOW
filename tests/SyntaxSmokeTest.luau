local ServerScriptService = game:GetService("ServerScriptService")

assert(loadstring ~= nil, "loadstring is unavailable for syntax validation")

local checked = 0
for _, root in { game:GetService("ReplicatedStorage"), ServerScriptService, game:GetService("StarterPlayer"), game:GetService("StarterGui") } do
	for _, instance in root:GetDescendants() do
		if instance:IsA("LuaSourceContainer") then
			local compiled, err = loadstring(instance.Source, `={instance:GetFullName()}`)
			assert(compiled ~= nil, `{instance:GetFullName()}: {err}`)
			checked += 1
		end
	end
end

assert(checked >= 25, `expected at least 25 game scripts, compiled {checked}`)
print(`SYNTAX_SMOKE_PASS ({checked} scripts)`)
