--!strict
-- Client bootstrap.

local Controllers = script.Controllers

require(Controllers.GameUI).start()
require(Controllers.Weapon).start()
require(Controllers.FX).start()
require(Controllers.UnitAnimator).start()
require(Controllers.TeamVisuals).start()
require(Controllers.Audio).start()
require(Controllers.Accessibility).start()
require(Controllers.MainMenu).start()
require(Controllers.LobbyPortals).start()
require(Controllers.TutorialController).start()
