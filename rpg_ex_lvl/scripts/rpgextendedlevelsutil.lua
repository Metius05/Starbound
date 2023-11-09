maxLevel = 1000 --These values will be replaced below
maxExperienceOrbs = 100000000
minMasteryExperience = 250000 
maxMastery = 100000
maxStat = 3460
trueMaxLevel = 1000
maxLimitExperienceOrbs = 500000
maxLevelStep = 1
maxAllocatablePoints = 100
pointsStep = 1

rpgextendedlevelsutil = {}
function rpgextendedlevelsutil.init() --execute before using values
	local limits = root.assetJson("/scripts/extendedlevels/limits.config")
	maxLevel = limits.maxLevel
	trueMaxLevel = maxLevel
	maxExperienceOrbs = limits.maxExperienceOrbs
	maxLevelStep = limits.maxLevelStep
	minMasteryExperience = limits.minMasteryExperience
	maxMastery = limits.maxMastery
	maxStat = limits.maxStat
	maxAllocatablePoints = limits.maxAllocatablePoints
	pointsStep = limits.pointsStep
	
	if player then
		maxLevel = player.currency("currMaxLevel")
		if maxLevel > trueMaxLevel then
			player.consumeCurrency("currMaxLevel",player.currency("currMaxLevel")-trueMaxLevel)
			maxLevel = trueMaxLevel
		end
	elseif world and self.rpgPlayerID then
		maxLevel =  world.entityCurrency(self.rpgPlayerID, "currMaxLevel")
	end
	maxLimitExperienceOrbs = maxLevel*maxLevel*100
end

local lastMaxLevel = 0
function rpgextendedlevelsutil.updateLimit()
	if player then
		maxLevel = player.currency("currMaxLevel")
		if maxLevel > trueMaxLevel then
			player.consumeCurrency("currMaxLevel",player.currency("currMaxLevel")-trueMaxLevel)
			maxLevel = trueMaxLevel
		end
	elseif world and self.rpgPlayerID then
		maxLevel =  world.entityCurrency(self.rpgPlayerID, "currMaxLevel")
	end
	if maxLevel ~= lastMaxLevel then
		lastMaxLevel = maxLevel
	end
	maxLimitExperienceOrbs = maxLevel*maxLevel*100
end