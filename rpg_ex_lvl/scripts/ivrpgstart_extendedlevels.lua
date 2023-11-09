require "/scripts/rpgextendedlevelsutil.lua"
local ext_ivrpgstartinit = init
function init()
	rpgextendedlevelsutil.init() --Load config values
	ext_ivrpgstartinit()
	self.rpg_xp = self.rpg_xp or player.currency("experienceorb")
	maxLevel = maxLevel or 4630
	status.setStatusProperty("ivrpgskillpoints", math.min(math.floor(math.sqrt(self.rpg_xp/100)), maxLevel))
end

function checkMaxXP()
  if (self.rpg_xp or 0) > maxExperienceOrbs then
    player.consumeCurrency("experienceorb", self.rpg_xp - maxExperienceOrbs)
  end
  self.rpg_xp = player.currency("experienceorb")
end