--!strict
-- Client bootstrap.

local Controllers = script.Controllers

require(Controllers.GameUI).start()
require(Controllers.Weapon).start()
require(Controllers.FX).start()
require(Controllers.UnitAnimator).start()
require(Controllers.TeamVisuals).start()
require(Controllers.Audio).start()
require(Controllers.MainMenu).start()
require(Controllers.Movement).start()
