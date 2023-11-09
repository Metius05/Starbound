require "/scripts/util.lua"
require "/scripts/status.lua"
require "/items/active/weapons/weapon.lua"

-- Melee primary ability
NebCustomCombo = WeaponAbility:new()

function NebCustomCombo:init()
  self.comboStep = 1
  
  animator.setAnimationState("scabbard", "visible")
  self.baseActiveTime = config.getParameter("activeTime", 2.0)
  self.activeTime = self.baseActiveTime / 3
  self.activeTimer = 0

  self.energyUsage = self.energyUsage or 0

  self:computeDamageAndCooldowns()

  self.weapon:setStance(self.stances.idle)

  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.cooldownTimer = self.cooldowns[1]

  self.animKeyPrefix = self.animKeyPrefix or ""
  
	if self.stances.idle.directives then
      animator.setGlobalTag("stanceDirectives", self.stances.idle.directives)
    else
      animator.setGlobalTag("stanceDirectives", "")
    end

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
    
	self.activeTimer = self.activeTime
	
	if self.stances.idle.directives then
      animator.setGlobalTag("stanceDirectives", self.stances.idle.directives)
    else
      animator.setGlobalTag("stanceDirectives", "")
    end
  end
end

-- Ticks on every update regardless if this is the active ability
function NebCustomCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
      self:readyFlash()
    end
  end

  if self.flashTimer > 0 then
    self.flashTimer = math.max(0, self.flashTimer - self.dt)
    if self.flashTimer == 0 then
      animator.setGlobalTag("bladeDirectives", "")
    end
  end
  
  if self.activeTimer > 0 and self.comboStep <= 1 and animator.animationState("blade") == "inactive" then
    self.activeTimer = math.max(0, self.activeTimer - dt)
    if self.activeTimer == 0 then
	  animator.setAnimationState("scabbard", "return")
    end
  end

  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) and fireMode == (self.activatingFireMode or self.abilitySlot) then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  if not self.weapon.currentAbility and self:shouldActivate() then
    self:setState(self.windup)
  end
end

-- State: windup
function NebCustomCombo:windup()
  local stance = self.stances["windup"..self.comboStep]

  self.weapon:setStance(stance)

  self.edgeTriggerTimer = 0

  if stance.directives then
    animator.setGlobalTag("stanceDirectives", stance.directives)
  else
    animator.setGlobalTag("stanceDirectives", "")
  end

  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(stance.duration)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- waiting for next combo input
function NebCustomCombo:wait()
  local stance = self.stances["wait"..(self.comboStep - 1)]

  self.weapon:setStance(stance)
  
  if stance.directives then
    animator.setGlobalTag("stanceDirectives", stance.directives)
  else
    animator.setGlobalTag("stanceDirectives", "")
  end

  util.wait(stance.duration, function()
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)

  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  self.comboStep = 1
end

-- State: preslash
-- brief frame in between windup and fire
function NebCustomCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()
  
  if stance.directives then
    animator.setGlobalTag("stanceDirectives", stance.directives)
  else
    animator.setGlobalTag("stanceDirectives", "")
  end

  util.wait(stance.duration)

  self:setState(self.fire)
end

-- State: fire
function NebCustomCombo:fire()
  local stance = self.stances["fire"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()
  
  if self.scabbardProjectile and animator.animationState("scabbard") == "visible" and self.comboStep <= 1 then
    animator.setAnimationState("scabbard", "hidden")
	
	local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(self.projectileInaccuracy or 0, 0) + (self.projectileAimAngleOffset or 0))
	aimVector[1] = aimVector[1] * mcontroller.facingDirection()	
	
	local firePosition = vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("scabbard", "scabbardReleasePoint") or {0.5, 0}))
	
	local params = self.projectileParameters or {}
	params.power = self.projectileDamage * config.getParameter("damageLevelMultiplier")
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
	params.speed = util.randomInRange(params.speed)
		
    world.spawnProjectile(
	  self.scabbardProjectile,
	  firePosition,
	  activeItem.ownerEntityId(),
	  aimVector,
	  false,
	  params
	)
  end
  
  if stance.block then
    status.setPersistentEffects("broadswordParry", {{stat = "shieldHealth", amount = stance.shieldHealth}})
	
    local blockPoly = partDamageArea("swoosh")
    activeItem.setItemShieldPolys({blockPoly})
  end

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)

  if stance.directives then
    animator.setGlobalTag("stanceDirectives", stance.directives)
  else
    animator.setGlobalTag("stanceDirectives", "")
  end
  
  util.wait(stance.duration, function()
    if stance.block then
      --Interrupt when running out of shield stamina
      if not status.resourcePositive("shieldStamina") then return true end
	end
  
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
  end)

  --Remove Parry
  status.clearPersistentEffects("broadswordParry")
  activeItem.setItemShieldPolys({})
  
  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
  end
end

function NebCustomCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function NebCustomCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function NebCustomCombo:computeDamageAndCooldowns()
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["fire"..i].duration
    if self.stances["preslash"..i] then
      attackTime = attackTime + self.stances["preslash"..i].duration
    end
    table.insert(attackTimes, attackTime)
  end

  self.cooldowns = {}
  local totalAttackTime = 0
  local totalDamageFactor = 0
  for i, attackTime in ipairs(attackTimes) do
    self.stepDamageConfig[i] = util.mergeTable(copy(self.damageConfig), self.stepDamageConfig[i])
    self.stepDamageConfig[i].timeoutGroup = "primary"..i

    local damageFactor = self.stepDamageConfig[i].baseDamageFactor
    self.stepDamageConfig[i].baseDamage = damageFactor * self.baseDps * self.fireTime

    totalAttackTime = totalAttackTime + attackTime
    totalDamageFactor = totalDamageFactor + damageFactor

    local targetTime = totalDamageFactor * self.fireTime
    local speedFactor = 1.0 * (self.comboSpeedFactor ^ i)
    table.insert(self.cooldowns, (targetTime - totalAttackTime) * speedFactor)
  end
end

function NebCustomCombo:uninit()
  status.clearPersistentEffects("broadswordParry")
  self.weapon:setDamage()
end
