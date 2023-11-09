require "/scripts/rpgextendedlevelsutil.lua"

origRPGinit = init
function init()
	rpgextendedlevelsutil.init() --Load config values
	origRPGinit()
	self.prevXP = math.min(world.entityCurrency(self.rpgPlayerID, "experienceorb"), maxLimitExperienceOrbs) --This is to bypass RPGGrowths 500000 xp constant, and use my own variable
	self.gritDiff = 0
	--self.statGrowthBases = root.assetJson("/scripts/extendedlevels/limits.config:statGrowthBases")
end

function checkLevelUp()
  self.xp = math.min(world.entityCurrency(self.rpgPlayerID, "experienceorb"), maxLimitExperienceOrbs)
  self.level = math.floor(math.sqrt(self.prevXP/100))
  local currXP = world.entityCurrency(self.rpgPlayerID,"experienceorb")
  if currXP >= (self.level+1)^2*100 and self.level < maxLevel then
    local oldLevel = self.level
    self.level = math.min(math.floor(math.sqrt(currXP/100)), maxLevel)
    if self.level == 1 then
      return
    end
    status.setStatusProperty("ivrpgskillpoints", status.statusProperty("ivrpgskillpoints", 0) + (self.level - oldLevel))
    status.addEphemeralEffect("ivrpglevelup")
  elseif currXP < (self.level+1)^2*100 then
    self.level = math.floor(math.sqrt(currXP/100))
  end
  self.prevXP = self.xp
end

local origRPGstatboostupdate = update
function update(dt)
  rpgextendedlevelsutil.updateLimit()
  self.xp = math.min(world.entityCurrency(self.rpgPlayerID, "experienceorb"), maxLimitExperienceOrbs)
  self.level = self.level == -1 and math.floor(math.sqrt(self.xp/100)) or self.level
  origRPGstatboostupdate(dt)
  --kockbackController()
end


--Vanilla doesn't limit "grit"/knockback resistance to 1, so if it's highet knockback goes negative but not lower
--This function grabs the "grit" stat and limits it to 1
--Because "status.stat" cannot be set, only modified, I do it this convoluted way
--[[function kockbackController()
	if status.stat("grit") > 1 then
		self.gritDiff = 1-status.stat("grit") + self.gritDiff
		self.gritDiff = status.stat("grit") > 1 and self.gritDiff or 0
		if self.gritDiff < 0 then
			if self.gritControlId then effect.removeStatModifierGroup(self.gritControlId) self.gritControlId = nil end
			self.gritControlId = effect.addStatModifierGroup({{stat="grit",amount = self.gritDiff}})
		end
	elseif status.stat("grit") < 1 and self.gritDiff < 1 then
		self.gritDiff =  0
		self.gritDiff = 1 - status.stat("grit")
		if self.gritControlId then effect.removeStatModifierGroup(self.gritControlId) self.gritControlId = nil end
		if self.gritDiff < 0 then
			self.gritControlId = effect.addStatModifierGroup({{stat="grit",amount = self.gritDiff}})
		end
	end
end]]--

--I was going to hook, but the scaling is included in the function, so it's better to overwrite
--[[function updateStats()
	local stats = {
		strength = world.entityCurrency(self.rpgPlayerID, "strengthpoint"),
		agility = world.entityCurrency(self.rpgPlayerID, "agilitypoint"),
		vitality = world.entityCurrency(self.rpgPlayerID, "vitalitypoint"),
		vigor = world.entityCurrency(self.rpgPlayerID, "vigorpoint"),
		intelligence = world.entityCurrency(self.rpgPlayerID, "intelligencepoint"),
		endurance = world.entityCurrency(self.rpgPlayerID, "endurancepoint"),
		dexterity = world.entityCurrency(self.rpgPlayerID, "dexteritypoint")
	}
	self.stats = stats
	
	--Was only used here
	--But kept global for future proofing
  local statBonuses = {
    strength = 1 + status.stat("ivrpgstrengthscaling"),
    agility = 1 + status.stat("ivrpgagilityscaling"),
    vitality = 1 + status.stat("ivrpgvitalityscaling"),
    vigor = 1 + status.stat("ivrpgvigorscaling"),
    intelligence = 1 + status.stat("ivrpgintelligencescaling"),
    endurance = 1 + status.stat("ivrpgendurancescaling"),
    dexterity = 1 + status.stat("ivrpgdexterityscaling")
  }
  self.statBonuses = statBonuses
  
  self.classicBonuses = {
    strength = 0,
    agility = 0,
    vitality = 0,
    vigor = 0,
    intelligence = 0,
    endurance = 0,
    dexterity = 0,
    default = 0
  }
  
  --Logarithmic base to lower growth at higher stat amounts
  --The closer to 1 the stronger the stat becomes, but NEVER 1, log doesn't work at base 1
  --Values grow really slow even after a few decimals, so above 3, stat growth is pretty much negligable
  local statLogBases = self.statGrowthBases

  --Stat Linearity Change + Scaling
  local log = math.log
  local floor = math.floor
  for k,v in pairs(stats) do
    if v >= 20 then
      self.classicBonuses[k] = 1
      if v < 30 then
        v = (v + 30)/2.0
      end
    end
	stats[k] = v <= 50 and v or 50 + log(v-49, statLogBases[k])
    stats[k] = floor(stats[k]^statBonuses[k])
	status.setStatusProperty("ivrpg" .. k, stats[k])
  end
  
  --Intelligence xp scaling remains untouched
  local int = world.entityCurrency(self.rpgPlayerID, "intelligencepoint")
  self.classicBonuses.intelligence = int > 20 and 1 or 0
  int = int < 30 and (int + 30)/2.0 or int
  status.setStatusProperty("ivrpgintelligence", int^statBonuses.intelligence)

  local statConfig = {}
  local movementConfig = {}
  for k,statModsConfig in pairs(self.statList) do
    if k ~= "default" then
      for x,statModifiers in ipairs(statModsConfig) do
        if statModifiers.type == "stat" then
          for i,statMod in ipairs(statModifiers.apply) do
            local currentConfig = {}
            local extra = 1
            if statMod.type == "status" then
              currentConfig.stat = statMod.stat
              if statMod.amountType == "amount" then extra = 0 end
			  currentConfig[statMod.amountType] = (extra + (statMod.amount*stats[k]*(statMod.negative and -1 or 1)))
              table.insert(statConfig, currentConfig)
            elseif statMod.type == "movement" then
              if statMod.stat ~= "airJumpModifier" or not mcontroller.walking() then
                movementConfig[statMod.stat] = (extra + (statMod.amount*stats[k]))
              end
            end
          end
        end
      end
    end
  end
  
  status.setPersistentEffects("ivrpgstatboosts", statConfig)
  if (not status.statPositive("activeMovementAbilities")) or mcontroller.canJump() or status.statPositive("ninjaVanishSphere") or status.statPositive("ivrpgshapeshifting") then
    mcontroller.controlModifiers(movementConfig)
  end
end]]--