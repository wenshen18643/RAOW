--!strict
-- Client bootstrap.

local Controllers = script.Controllers

print("[AgeOfWarFP] Client bootstrap starting...")

require(Controllers.GameUI).start()
print("[AgeOfWarFP] GameUI started")
require(Controllers.Weapon).start()
print("[AgeOfWarFP] Weapon started")
require(Controllers.FX).start()
print("[AgeOfWarFP] FX started")
require(Controllers.UnitAnimator).start()
print("[AgeOfWarFP] UnitAnimator started")
require(Controllers.Audio).start()
print("[AgeOfWarFP] Audio started")
require(Controllers.MainMenu).start()
print("[AgeOfWarFP] MainMenu started")
require(Controllers.Movement).start()
print("[AgeOfWarFP] Movement started")

print("[AgeOfWarFP] Client ready")
