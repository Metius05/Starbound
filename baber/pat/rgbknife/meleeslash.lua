require "/scripts/interp.lua"
require "/scripts/util.lua"

-- Melee primary ability
MeleeSlash = WeaponAbility:new()

function MeleeSlash:init()
	hueshift = 0

  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.energyUsage = self.energyUsage or 0

  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self:cooldownTime()

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function MeleeSlash:update(dt, fireMode, shiftHeld)
	hueshift = hueshift + 3
  if hueshift >= 360 then
    hueshift = 0
  end
	animator.setGlobalTag("hueshift", "?hueshift="..hueshift)
	activeItem.setCursor("/pat/rgbknife/cursor/"..math.floor(hueshift / 5)..".cursor")
	
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == "primary" and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

-- State: windup
function MeleeSlash:windup()
  self.weapon:setStance(self.stances.windup)
	
	local progress = 0
  util.wait(0.05, function()
    local from = self.stances.idle.weaponOffset or {0,0}
    local to = self.stances.windup.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.idle.weaponRotation, self.stances.windup.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.idle.armRotation, self.stances.windup.armRotation))

    progress = math.min(1.0, progress + (self.dt / 0.05))
  end)

  if self.stances.windup.hold then
    while self.fireMode == "primary" do
      coroutine.yield()
    end
  else
    util.wait(self.stances.windup.duration)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances.preslash then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: preslash
-- brief frame in between windup and fire
function MeleeSlash:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

-- State: fire
function MeleeSlash:fire()
	local progress = 0
  util.wait(0.05, function()
    local from = self.stances.windup.weaponOffset or {0,0}
    local to = self.stances.fire.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.windup.weaponRotation, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.windup.armRotation, self.stances.fire.armRotation))

    progress = math.min(1.0, progress + (self.dt / 0.05))
  end)
	
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("swoosh", "fire")
  animator.playSound(self.fireSound or "fire")
  animator.burstParticleEmitter((self.elementalType or self.weapon.elementalType) .. "swoosh")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)

  self.cooldownTimer = self:cooldownTime()
	
	local progress = 0
  util.wait(0.05, function()
    local from = self.stances.fire.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.fire.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.fire.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / 0.05))
  end)
end

function MeleeSlash:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function MeleeSlash:uninit()
  self.weapon:setDamage()
end
