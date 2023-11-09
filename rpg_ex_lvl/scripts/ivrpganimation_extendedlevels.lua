require "/scripts/rpgextendedlevelsutil.lua"
function calculateLevelTags()
  rpgextendedlevelsutil.init() --Load config values
  if not self.experience then self.experience = 0 end
  local level = math.floor(math.sqrt(self.experience/100))
  if level == maxLevel then
    animator.setGlobalTag("level", "50")
  else
    local minExperience = level^2*100
    local maxExperience = (level+1)^2*100
    local percent = math.floor((self.experience - minExperience) / (maxExperience - minExperience) * 50 + 0.5)
    animator.setGlobalTag("level", tostring(percent))
  end
end