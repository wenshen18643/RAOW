--!strict
-- Client bootstrap.

local Controllers = script.Controllers

require(Controllers.GameUI).start()
require(Controllers.Weapon).start()
require(Controllers.FX).start()

print("[AgeOfWarFP] Client ready")
