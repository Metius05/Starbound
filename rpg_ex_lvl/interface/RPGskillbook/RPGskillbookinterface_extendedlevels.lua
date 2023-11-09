require "/scripts/rpgextendedlevelsutil.lua"
extendedlevelsinit = init
function init()
	rpgextendedlevelsutil.init() --Load config values
	widget.setSliderRange("overviewlayout.extendedLevelSlider", 50, trueMaxLevel, maxLevelStep)
	local value = player.currency("currMaxLevel")
	if not value or value < 50 then value = 1000 end
	value = value > trueMaxLevel and trueMaxLevel or value
	maxLevel = value
	widget.setSliderValue("overviewlayout.extendedLevelSlider", value)
	widget.setText("overviewlayout.extendedLevelValue","")--"Max Level: "..value)
	extendedlevelsinit()
	self.pointsToAllocate = player.currency("statpoint")
	widget.setText("statslayout.statAllocatingLabel",self.pointsToAllocate)
	widget.setText("overviewlayout.extendedLevelTitle","Level Range:\n".."50 -> "..trueMaxLevel)
	widget.setText("overviewlayout.extendedLevelTextBox",value)
	self.lockState = (status.statusProperty("rpgelLockedLevel",false) and 2) or 0
	forceLockLevel(self.lockState == 2)
	updateStatLimitsEL()
end


function updateLevel()
  self.xp = math.min(player.currency("experienceorb"), maxExperienceOrbs)
  if self.xp < 100 then
    player.addCurrency("experienceorb", 100)
    status.setStatusProperty("ivrpgskillpoints", 1)
  end
  
  self.level = player.currency("currentlevel")
  self.newLevel = math.floor(math.sqrt(self.xp/100))
  self.newLevel = self.newLevel >= maxLevel and maxLevel or self.newLevel
  
  if self.newLevel > self.level then
	player.addCurrency("currentlevel", self.newLevel - self.level)
	--Now it prevents you from getting statpoints when altering the "level limit" slider, now only occurs when you gained a level above the highest level you have reached
	if status.statusProperty("rpgelHighestReachedLevel",0) < self.newLevel then
		addStatPoints(self.newLevel, self.level)
		status.setStatusProperty("rpgelHighestReachedLevel",self.newLevel) --Store the new highest level reached
	end
  elseif self.newLevel < self.level then
    player.consumeCurrency("currentlevel", self.level - self.newLevel)
  end
  self.level = player.currency("currentlevel")
  widget.setText("statslayout.statpointsleft", player.currency("statpoint"))
  updateStats()
  self.toNext = 2*self.level*100+100
  updateOverview(self.toNext)
  updateBottomBar(self.toNext)
  
end

function updateBottomBar(toNext)
  widget.setText("levelLabel", "Level " .. tostring(self.level))
  if self.level == maxLevel then
    widget.setText("xpLabel","Max XP!")
    widget.setProgress("experiencebar",1)
  else
    widget.setText("xpLabel",tostring(math.floor((self.xp-self.level^2*100))) .. "/" .. tostring(toNext))
    widget.setProgress("experiencebar",(self.xp-self.level^2*100)/toNext)
  end
  
end

function enableStatButtons(enable)
  if player.currency("classtype") == 0 then
    enable = false
    widget.setVisible("statslayout.statprevention",true)
  else
    widget.setVisible("statslayout.statprevention",false)
  end
  for k,v in pairs(self.statList) do
    if k ~= "default" then
      widget.setButtonEnabled("statslayout.raise" .. k, self[k] < maxStat and enable)
    end
  end
end

oldRPGupdateOverview = updateOverview
function updateOverview(toNext)
  oldRPGupdateOverview(toNext)
  widget.setText("overviewlayout.levellabel","Level " .. tostring(self.level))
  if self.level == maxLevel then
    widget.setText("overviewlayout.xptglabel","Experience Needed For Level-Up: N/A.")
    widget.setText("overviewlayout.xptotallabel","Total Experience Orbs Collected: " .. tostring(self.xp))
  else
    widget.setText("overviewlayout.xptglabel","Experience Needed For Level-Up: " .. tostring(toNext - (math.floor(self.xp-self.level^2*100))))
    widget.setText("overviewlayout.xptotallabel","Total Experience Orbs Collected: " .. tostring(self.xp))
  end
  widget.setText("overviewlayout.statpointsremaining","Stat Points Available: " .. tostring(player.currency("statpoint")))
  
  self.lockState = (status.statusProperty("rpgelLockedLevel",false) and 2) or 0
  forceLockLevel(self.lockState == 2)
end

function updateMasteryTab()
  rpgextendedlevelsutil.updateLimit()
  widget.setText("masterylayout.masterypoints", self.mastery)

  if self.mastery < 3 or self.xp < 250000 then --Allow prestige as long as you have reached level 50
    widget.setButtonEnabled("masterylayout.prestigebutton", false)
  else
    widget.setButtonEnabled("masterylayout.prestigebutton", true)
  end

  if self.mastery < 5 then
    widget.setButtonEnabled("masterylayout.shopbutton", false)
  else
    widget.setButtonEnabled("masterylayout.shopbutton", true)
  end
		
  --If the max level was reached, then allow to refine a whole level worth of XP
  local maxOrbs = self.level >= trueMaxLevel and ((maxLevel-1)*(maxLevel-1)*100) or maxLimitExperienceOrbs
  maxOrbs = maxOrbs + 10000
  if self.mastery >= maxMastery or self.xp < maxOrbs then
    widget.setButtonEnabled("masterylayout.refinebutton", false)
  else
    widget.setButtonEnabled("masterylayout.refinebutton", true)
  end
  widget.setText("masterylayout.xpover", math.max(0, math.min(self.xp - maxOrbs-10000, maxExperienceOrbs)))

  updateChallenges()
end

function refine()
  --If the max level was reached, then allow to refine a whole level worth of XP
  local maxOrbs = self.level >= trueMaxLevel and ((maxLevel-1)*(maxLevel-1)*100) or maxLimitExperienceOrbs
  local xp = math.min(self.xp, maxExperienceOrbs) - maxOrbs
  local mastery = math.floor(xp/10000)
  player.addCurrency("masterypoint", mastery)
  player.consumeCurrency("experienceorb", 10000*mastery)
  --status.setStatusProperty("rpgelHighestReachedLevel",math.floor(math.sqrt(player.currency("experienceorb")/100)))
end

local origelRPGareyousure = areYouSure
function areYouSure(name)
  origelRPGareyousure(name)
  
  name = string.gsub(name,"resetbutton","")
  name2 = ""
  if name == "" then name2 = "overviewlayout"
  elseif name == "cl" then name2 = "classlayout" end
  
  widget.setVisible(name2..".extendedLevelTitle", false)
  widget.setVisible(name2..".extendedLevelValue", false)
  widget.setVisible(name2..".extendedLevelTextBox", false)
  widget.setVisible(name2..".extendedLevelMaxLabel", false)
  widget.setVisible(name2..".extendedLevelBoxImage", false)
  widget.setVisible(name2..".acceptlevel", false)
  widget.setVisible(name2..".locklevel", false)
end

local origelRPGnotsure = notSure
function notSure(name)
  origelRPGnotsure(name)
  
   name = string.gsub(name,"resetbutton","")
  name2 = ""
  if name == "" then name2 = "overviewlayout"
  elseif name == "cl" then name2 = "classlayout" end
  
  widget.setVisible(name2..".extendedLevelTitle", true)
  widget.setVisible(name2..".extendedLevelValue", true)
  widget.setVisible(name2..".extendedLevelTextBox", true)
  widget.setVisible(name2..".extendedLevelMaxLabel", true)
  widget.setVisible(name2..".extendedLevelBoxImage", true)
  widget.setVisible(name2..".acceptlevel", true)
  widget.setVisible(name2..".locklevel", true)
  forceLockLevel(self.lockState == 2)
end

local origELReset = resetSkillBook
function resetSkillBook()
  origELReset()
  unlockLevel()
end

--Now every "step"(15) levels after the first 58, you gain 1 extra statpoint, ie: >58 = 5, >73 = 6,...>148 = 10, ect...
--This is easily changed by setting a different "step"
--"tier" is a way of knowing how many "multiples of 15 levels above 18", to know how many points must be awarded, added 2 to start above vanilla rpg values.
function addStatPoints(newLevel, oldLevel)
  local step = 15.0
  local tier = -1
  while newLevel > oldLevel do
	if oldLevel > 58 then
		bigNumberAddStatPoints(newLevel, oldLevel)
		oldLevel = newLevel
	elseif oldLevel > 48 then
      player.addCurrency("statpoint", 4)
    elseif oldLevel > 38 then
      player.addCurrency("statpoint", 3)
    elseif oldLevel > 18 then
      player.addCurrency("statpoint", 2)
    elseif oldLevel > 0 then
      player.addCurrency("statpoint", 1)
    else
      startingStats()
    end
    oldLevel = oldLevel + 1
  end
end

--Yields the same result as the above function (when above 58) while being WAY faster when dealing with 1000+ level changes
--We are talking 10s to 10000s times faster, so that the interface does not crash when calculating anymore
function bigNumberAddStatPoints(newLevel, oldLevel)
  local step = 15.0;
  local levelChange = newLevel - oldLevel;
  
  --Calculate min and max tier for this level update
  local startTier = ((oldLevel - 18)/step);
  local beglocalier = math.ceil((startTier) + (startTier%1 == 0 and 1 or 0));
  local endTier = ((newLevel - 18)/step);
  local finalTier = math.ceil((endTier) + (endTier%1 == 0 and 1 or 0));
  
  --How many top and bottom levels will have different tiers, used when they are not in groups of "step" amoount
  --Ie: if (15 > difference1 > 0) then it means that "difference1" amount of levels to add is less than "step" amount and thus cannot be averaged below 
  --This is the amount of levels from the tier that already were added or were left from being added (from a previous book openning) 
  --Needs to take into account the base offset of 18 used to keep vanilla RPG values as a start
  --oldlevel and newLevel will always be larger than tier*step
  local difference1 = oldLevel-(beglocalier*step)+(step-18);
  local difference2 = newLevel-(finalTier*step)+(step-18);
 
  --Calculate which of the starting and ending tiers can be used for averaging, if a "difference" is higher than 0, then we add or substract 1 depending if is from the top or bottom of the levels
  --Because it means that there are levels that need to be calculated differently
  local avTier1 = difference1==0 and math.ceil(beglocalier) or math.ceil(beglocalier)+1;
  local avTier2 = difference2==0 and math.ceil(endTier) or math.ceil(endTier)-1;
  
  --The amount of "differece" levels can only be between 0 and "step", if the value is "step" then it is meant to be 0
  --Depends on the tier to be used for averaging, as it tells if there was a tier change reccently or not (seems to be based on "step"/2, but decimals can't be used, so this is my apporoach)
  local left1 = step - difference1;
  left1 = (avTier1-startTier < 0) and difference1 or left1;
  left1 = (left1==step) and 0 or left1;
  local left2 = step - difference2;
  left2 = (avTier2-endTier < 0) and difference2 or left2;
  left2 = (left2==step) and 0 or left2;
  
  --Average the min and max tiers then multiply that by all the levels that are in groups of "step" amount that use equal tier
  --This means all the levels except for the ones in "left1" and "left2"
  local fullLevels = (levelChange-left1-left2);
  local averageTier = (avTier1 + avTier2) / 2.0 + 2.0;
  local averagedLevels = averageTier * fullLevels;
  local result = averagedLevels + left1*(beglocalier+2) + left2*(finalTier+2)
  player.addCurrency("statpoint", result)
end

rpgelorigenableStatButtons = enableStatButtons
function enableStatButtons(enable)
  rpgelorigenableStatButtons(enable)
  for k,v in pairs(self.statList) do
    if k ~= "default" then
      widget.setButtonEnabled("statslayout.lower" .. k, self[k] > 0)
    end
  end
end

--[[function extendedLevelSlider()
	local value = math.ceil(widget.getSliderValue("overviewlayout.extendedLevelSlider"))
	player.consumeCurrency("currMaxLevel",player.currency("currMaxLevel"))
	rpgextendedlevelsutil.updateLimit()
	player.addCurrency("currMaxLevel",value)
	widget.setText("overviewlayout.extendedLevelValue",value)
	maxLevel = value
end]]--

function statAllocatingBox()
	local value = player.currency("statpoint")
	value = parseCommand(widget.getText("statslayout.statAllocatingBox") or value)
	value = value < 1 and 1 or value
	widget.setText("statslayout.statAllocatingLabel",value)
	self.pointsToAllocate = value
end

function statEscKey()
	statAllocatingBox()
end 
function statEnterKey()
	statAllocatingBox()
end

function extendedLevelTextBox(widgetName, change)
	if status.statusProperty("rpgelLockedLevel",false) then
		widget.setText("overviewlayout.extendedLevelTextBox", player.currency("currMaxLevel"))
		return 
	end
	if not change then return end
	local value = player.currency("currMaxLevel")
	value = parseLevelCommand(widget.getText("overviewlayout.extendedLevelTextBox") or value)
	rpgextendedlevelsutil.updateLimit()
	--widget.setText("overviewlayout.extendedLevelValue","Max Level: "..value)
	maxLevel = value
	player.consumeCurrency("currMaxLevel",player.currency("currMaxLevel"))
	player.addCurrency("currMaxLevel",value)
	updateLevel()
end

function levelEscKey()
	if status.statusProperty("rpgelLockedLevel",false) then return end
	extendedLevelTextBox("", false)
end 
function levelEnterKey()
	if status.statusProperty("rpgelLockedLevel",false) then return end
	extendedLevelTextBox("", true)
end


function acceptLevel()
	if status.statusProperty("rpgelLockedLevel",false) then return end
	extendedLevelTextBox("", true)
end 
function lockLevel()
    self.lockState = (self.lockState == 0 and 1) or 2
	forceLockLevel(self.lockState == 2)
end
function unlockLevel()
	self.lockState = 0
	status.setStatusProperty("rpgelLockedLevel",false)
	forceLockLevel(false)
end

function forceLockLevel(setLock)
	status.setStatusProperty("rpgelLockedLevel",setLock)
	extendedLevelTextBox("", setLock)
	self.lockState = setLock and 2 or self.lockState
	widget.setVisible("overviewlayout.locklevel", not setLock)
	widget.setVisible("overviewlayout.acceptlevel", not setLock)
	--widget.setVisible("overviewlayout.extendedLevelBoxCover", setLock)
	widget.setVisible("overviewlayout.extendedLevelTextBox", not setLock)
	widget.setVisible("overviewlayout.extendedLevelBoxImage", not setLock)
	widget.setVisible("overviewlayout.extendedLevelTitle", not setLock)
	widget.setVisible("overviewlayout.extendedLevelMaxLabel", not setLock)
	widget.setVisible("overviewlayout.extendedLevelValue", setLock)
	if setLock then widget.setText("overviewlayout.extendedLevelValue", "Max Level: "..maxLevel) end
	if self.lockState == 1 then
		widget.setButtonImages("overviewlayout.locklevel",{
			base = 			"/interface/RPGskillbook/locklevel_question.png",
			hover = 		"/interface/RPGskillbook/locklevel_question_hover.png",
			pressed = 		"/interface/RPGskillbook/locklevel_question_pressed.png",
			disabledImage = "/interface/RPGskillbook/locklevel_locked.png",
		})
	elseif self.lockState == 0 then
		widget.setButtonImages("overviewlayout.locklevel",{
			base = 			"/interface/RPGskillbook/locklevel.png",
			hover = 		"/interface/RPGskillbook/locklevel_hover.png",
			pressed = 		"/interface/RPGskillbook/locklevel_pressed.png",
			disabledImage = "/interface/RPGskillbook/locklevel_locked.png",
		})
	elseif self.lockState == 2 then
		widget.setButtonImages("overviewlayout.locklevel",{
			base = 			"/interface/RPGskillbook/locklevel_locked.png",
			hover = 		"/interface/RPGskillbook/locklevel_locked.png",
			pressed = 		"/interface/RPGskillbook/locklevel_locked.png",
			disabledImage = "/interface/RPGskillbook/locklevel_locked.png",
		})
	end
end

function raiseStat(name)
	local prev = self.pointsToAllocate
	if self.pointsToAllocate > player.currency("statpoint") then self.pointsToAllocate = player.currency("statpoint") end
	name = string.gsub(name,"raise","") .. "point"
	if self.pointsToAllocate + player.currency(name) > maxStat then self.pointsToAllocate = maxStat - player.currency(name) end
	player.consumeCurrency("statpoint", self.pointsToAllocate)
	player.addCurrency(name, self.pointsToAllocate)
	self.pointsToAllocate = prev
	updateStats()
end

function lowerStat(name)
  name = string.gsub(name,"lower","") .. "point"
  if player.currency(name) <= 0 then return end
  local prev = self.pointsToAllocate
  if self.pointsToAllocate > player.currency(name) then self.pointsToAllocate = player.currency(name) end
  player.addCurrency("statpoint", self.pointsToAllocate)
  player.consumeCurrency(name, self.pointsToAllocate)
  self.pointsToAllocate = prev
  updateStats()
end

rpgelorigconsumeAllCurrency = consumeAllRPGCurrency
function consumeAllRPGCurrency()
	rpgelorigconsumeAllCurrency()
	status.setStatusProperty("rpgelHighestReachedLevel",0)
end

function updateStatLimitsEL()
	for name,_ in pairs(self.statList) do
		if name ~= "default" and player.currency(name.."point") > maxStat then
			local diff = player.currency(name.."point") - maxStat
			player.consumeCurrency(name.."point",diff)
			player.addCurrency("statpoint",diff)
			self[name] = player.currency(name.."point")
		end
	end
	widget.setText("overviewlayout.statpointsremaining","Stat Points Available: " .. tostring(player.currency("statpoint")))
	widget.setText("statslayout.statpointsleft", player.currency("statpoint"))
	updateStats()
end


local changeToSkills_el = changeToSkills
function changeToSkills()
	changeToSkills_el()
	fixSkillPoints()
end

--For some reason, leveling up doesn't grant skill points sometimes, this fixes the missing points
--I think the problem is in "ivrpgstatboosts_extended.lua", but I'm going to fix it here because it is better for the ability to change your max level randomly, even below your current level, stops infinite skill point exploits
function fixSkillPoints()
	local maxPoints = self.level
	local activeSkills = status.statusProperty("ivrpgskills", {})
	local skillList = self.textData["skill"].children
	--[[for group, sub_skills in pairs(skillList) do
		for skillName, skilldata in pairs(sub_skills.children) do
			if activeSkills["skill"..group..skillName] and skilldata.requires then
				maxPoints = maxPoints - skillCost(#skilldata, activeSkills["skill"..group..skillName], skilldata.requires)
			end
		end
	end]]--
	for skillName, tier in pairs(activeSkills) do
		local group = string.sub(skillName,6,9)
		local skill = string.sub(skillName,10,-1)
		maxPoints = maxPoints - skillCost(nil,tier, skillList[group].children[skill].requires)
	end
	--sb.logInfo("Point Change: "..sb.print(self.level)..", "..maxPoints)
	status.setStatusProperty("ivrpgskillpoints", maxPoints)
end


function parseCommand(text) 
	local value = 1
	if tonumber(text) then
		value = math.floor(tonumber(text))
	end
	if text == "all" then
		value = (player.currency("statpoint") > addStats() and player.currency("statpoint")) or addStats()
	elseif text == "distribute" then
		value = math.floor(player.currency("statpoint")/7)
	elseif string.find(text,"/") then
		local num1 = ""
		local num2 = ""
		local i = 1
		while text:sub(i,i) ~= "/" do
			num1 = num1..text:sub(i,i)
			i = i + 1
		end
		i = i + 1
		while i <= text:len() do
			num2 = num2..text:sub(i,i)
			i = i + 1
		end
		num1 = tonumber(num1)
		num2 = tonumber(num2)
		if num1 and num2 and player.currency("statpoint") > 0 then
			value = math.floor((num1 / num2) * player.currency("statpoint"))
		end
	end
	return value
end

function parseLevelCommand(text)
	local value = 50
	if tonumber(text) then
		value = math.floor(tonumber(text))
		value = value < 50 and 50 or value
		value = value > trueMaxLevel and trueMaxLevel or value
	else
		value = maxLevel
	end
	if text == "max" then
		value = trueMaxLevel
	end
	return value
end

local orig_ExtLvl_updateInfo =updateInfo
function updateInfo()
	orig_ExtLvl_updateInfo()
	local log = math.log
	widget.setText("infolayout.displaystats", 
    "Amount\n" ..
    "^red;" .. math.floor(100*(1 + status.statusProperty("ivrpgvitality",0)^self.vitalityBonus * 0.02))/100.0 .. "^reset;" .. "\n" ..
    "^green;" .. math.floor(100*(1 + status.statusProperty("ivrpgvigor",0)^self.vigorBonus * 0.05))/100.0 .. "\n" ..
    math.floor(status.stat("energyRegenPercentageRate")*100+.5)/100 .. "\n" ..
    math.floor(status.stat("energyRegenBlockTime")*100+.5)/100 .. "^reset;" .. "\n" ..
    "^orange;" .. getStatPercent(status.stat("foodDelta")) .. "^reset;" ..
    "^gray;" .. getStatPercent(status.stat("grit")) ..
    getStatMultiplier(status.stat("fallDamageMultiplier")) ..
    math.floor((1 + status.statusProperty("ivrpgstrength",0)^self.strengthBonus*.05)*100+.5)/100 .. "^reset;" .. "\n" ..
    "^red;" .. (math.floor(10000*status.stat("ivrpgBleedChance"))/100) .. "%\n" ..
    (math.floor(100*status.stat("ivrpgBleedLength"))/100) .. "^reset;" .. "\n" ..
    "\n\nPercent\n" ..
    "^gray;" .. getStatPercent(status.stat("physicalResistance")) .. "^reset;" ..
    "^green;" .. getStatPercent(status.stat("poisonResistance")) .. "^reset;" ..
    "^blue;" .. getStatPercent(status.stat("iceResistance")) .. "^reset;" .. 
    "^red;" .. getStatPercent(status.stat("fireResistance")) .."^reset;" .. 
    "^yellow;" .. getStatPercent(status.stat("electricResistance")) .. "^reset;" ..
    "^magenta;" .. getStatPercent(status.stat("novaResistance")) .. "^reset;" .. 
    "^black;" .. getStatPercent(status.stat("demonicResistance")) .."^reset;" .. 
    "^yellow;" .. getStatPercent(status.stat("holyResistance")) .. "^reset;" ..
    "^green;" .. getStatPercent(status.stat("radioactiveResistance")) .. "^reset;" ..
    "^gray;" .. getStatPercent(status.stat("shadowResistance")) .. "^reset;" ..
    "^magenta;" .. getStatPercent(status.stat("cosmicResistance")) .. "^reset;")
end