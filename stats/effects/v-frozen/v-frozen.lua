local freezeDelay
local shatterDelay
local state
local timer

function init()
  animator.setParticleEmitterOffsetRegion("freeze", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("shatter", mcontroller.boundBox())
  freezeDelay = 0
  shatterDelay = 2.0

  state = "freeze"
  timer = freezeDelay
end

function update(dt)
  timer = timer - dt

  if state == "freeze" then
    if timer <= 0 then
      animator.setAnimationRate(0)
      animator.playSound("freeze")
      animator.burstParticleEmitter("freeze")
      if world.entityType(entity.id()) == "player" then
        animator.setAnimationState("freezeState", "visible")
      else
        effect.setParentDirectives("?saturation=-50?border=1;999999?multiply=87dece")
      end

      if status.isResource("stunned") then
        status.setResource("stunned", shatterDelay)
      end

      state = "thawing"
      timer = shatterDelay
    end
  elseif state == "thawing" then
    if timer <= 0 then
      animator.playSound("shatter")
      animator.burstParticleEmitter("shatter")
      if world.entityType(entity.id()) == "player" then
        animator.setAnimationState("freezeState", "invisible")
      else
        effect.setParentDirectives("")
      end

      state = nil
    end
  end
end