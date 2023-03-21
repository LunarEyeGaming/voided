require "/items/active/weapons/ranged/beamfire.lua"

CorrectedBeamFire = BeamFire:new()

function CorrectedBeamFire:fire()
  -- Uses the weapon rotation because that's where the problem is arising -- weapon rotation.
  local correctionAmount = util.toRadians(self.stances.fire.weaponRotation)

  self.weapon:setStance(self.stances.fire)

  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)

  local wasColliding = false
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
    local beamStart = self:firePosition()
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
    local beamLength = self.beamLength

    local collidePoint = world.lineCollision(beamStart, beamEnd)
    if collidePoint then
      beamEnd = collidePoint

      beamLength = world.magnitude(beamStart, beamEnd)

      animator.setParticleEmitterActive("beamCollision", true)
      animator.resetTransformationGroup("beamEnd")
      animator.translateTransformationGroup("beamEnd", vec2.rotate({beamLength, 0}, correctionAmount))

      if self.impactSoundTimer == 0 then
        animator.setSoundPosition("beamImpact", vec2.rotate({beamLength, 0}, correctionAmount))
        animator.playSound("beamImpact")
        self.impactSoundTimer = self.fireTime
      end
    else
      animator.setParticleEmitterActive("beamCollision", false)
    end

    -- Modified variant of the self.weapon:setDamage() call so that the damage line properly corresponds to the image of the beam.
    self.weapon:setDamage(self.damageConfig, {self.weapon.muzzleOffset, vec2.add(vec2.rotate({beamLength, 0}, correctionAmount), self.weapon.muzzleOffset)}, self.fireTime)

    self:drawBeam(beamEnd, collidePoint)

    coroutine.yield()
  end

  self:reset()
  animator.playSound("fireEnd")

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function CorrectedBeamFire:firePosition(angularOffset)
  return vec2.add(mcontroller.position(), vec2.rotate(activeItem.handPosition(self.weapon.muzzleOffset), (angularOffset or 0)))
end

function CorrectedBeamFire:aimVector(inaccuracy, angularOffset)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + (angularOffset or 0) + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end