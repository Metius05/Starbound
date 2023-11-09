require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/items/active/weapons/weapon.lua"

NebStarVestigeDash = WeaponAbility:new()

function NebStarVestigeDash:init()
  self.cooldownTimer = self.cooldownTime
end

function NebStarVestigeDash:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  self.searchVector = {self.searchDistance[1], self.searchDistance[2]}
  self.collidePoint = world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), self.searchVector))
  world.debugText("searchDistance? %s", self.searchDistance[1], vec2.add(mcontroller.position(), {0, -2}), "red")

  if self.weapon.currentAbility == nil 
     and self.fireMode == "alt"
     and self.cooldownTimer == 0
     and not status.statPositive("activeMovementAbilities")
     and status.overConsumeResource("energy", self.energyUsage) then

    self:setState(self.windup)
  end
end

function NebStarVestigeDash:windup()
  self.weapon:setStance(self.stances.windup)

  status.setPersistentEffects("weaponMovementAbility", {{stat = "activeMovementAbilities", amount = 1}})

  animator.setParticleEmitterActive("dashCharge", true)
  animator.playSound("dashCharge")

  util.wait(self.stances.windup.duration, function(dt)
    mcontroller.controlModifiers({jumpingSuppressed = true})
  end)

  if not self.maxAimAngle or activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition()) <= self.maxAimAngle and not mcontroller.onGround() and not self.collidePoint then
    self:setState(self.slamFire)
  else
    self:setState(self.dash)
  end
end

function NebStarVestigeDash:dash()
  self.weapon:setStance(self.stances.dash)

  animator.playSound("dashFire")

  local wasInvulnerable = status.stat("invulnerable") > 0
  status.addEphemeralEffect("invulnerable", self.dashTime)

  local position = mcontroller.position()
  local params = copy(self.projectileParameters)
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.power = params.power * config.getParameter("damageLevelMultiplier")

  local ownerAim = activeItem.ownerAimPosition()
  local mpos = mcontroller.position()
  local dashAim = vec2.norm(world.distance(ownerAim,mpos))
  util.wait(self.dashTime, function(dt)
    mcontroller.setVelocity(vec2.mul(dashAim, self.dashSpeed))
    mcontroller.controlMove(self.weapon.aimDirection)

    local direction = vec2.norm(world.distance(mcontroller.position(), position))
    while world.magnitude(mcontroller.position(), position) >= self.trailInterval do
      position = vec2.add(position, vec2.mul(direction, self.trailInterval))
      world.spawnProjectile(self.projectileType, vec2.add(position, self.projectileOffset), activeItem.ownerEntityId(), dashAim, false, params)
    end
    local damageArea = partDamageArea("blade")
    self.weapon:setDamage(self.damageConfig, damageArea)
  end)
  animator.setParticleEmitterActive("dashCharge", false)

  mcontroller.setVelocity({0,0})
  self.cooldownTimer = self.cooldownTime
end

-- State: slam fire
function NebStarVestigeDash:slamFire()
  local windupStance = self.stances["slamWindup"]
  local slamStance = self.stances["slamFire"]

  local slamMomentum = self.slamMomentum
  slamMomentum[1] = slamMomentum[1] * mcontroller.facingDirection()
  mcontroller.addMomentum(slamMomentum)
  
  self.weapon:setStance(windupStance)
  self.weapon:updateAim()
  local hasSlammed = false

  if mcontroller.onGround() then
	self.weapon:setStance(slamStance)            
	
	animator.burstParticleEmitter("groundImpact")
	animator.playSound("groundImpact")

	local direction = mcontroller.facingDirection()
	local partPoint = animator.partPoint("blade", "impactExplosionPosition")
	partPoint[1] = partPoint[1] * direction
	local projectilePosition = vec2.add(mcontroller.position(), partPoint)
	local params = copy(self.slamProjectileParameters)
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
	params.power = params.power * config.getParameter("damageLevelMultiplier")
	world.spawnProjectile(self.slamProjectile, projectilePosition, activeItem.ownerEntityId(), {direction,0}, false, params)
  else
    while not mcontroller.onGround() do
      local damageArea = partDamageArea("swoosh")
      if not damageArea then
        damageArea = partDamageArea("blade")
      end
      self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
	  if self.collidePoint then
	    self.weapon:setStance(slamStance)
	  end
      if hasSlammed == false then
	    local groundImpact = world.polyCollision(poly.translate(poly.handPosition(animator.partPoly("blade", "groundImpactPoly")), mcontroller.position()))
        if mcontroller.onGround() or groundImpact then
          if groundImpact then
            animator.burstParticleEmitter("groundImpact")
            animator.playSound("groundImpact")
	 
		    local direction = mcontroller.facingDirection()
		    local partPoint = animator.partPoint("blade", "impactExplosionPosition")
		    partPoint[1] = partPoint[1] * direction
	   	    local projectilePosition = vec2.add(mcontroller.position(), partPoint)
		    local params = copy(self.slamProjectileParameters)
		    params.powerMultiplier = activeItem.ownerPowerMultiplier()
		    params.power = params.power * config.getParameter("damageLevelMultiplier")
		    world.spawnProjectile(self.slamProjectile, projectilePosition, activeItem.ownerEntityId(), {direction,0}, false, params)
		    hasSlammed = true
		  end
        end
      end
      coroutine.yield()
    end
  end
end

function NebStarVestigeDash:uninit()
  status.clearPersistentEffects("weaponMovementAbility")

  animator.setParticleEmitterActive("dashCharge", false)

  if self.weapon.currentState == self.dash then
    mcontroller.setVelocity({0,0})
  end
end