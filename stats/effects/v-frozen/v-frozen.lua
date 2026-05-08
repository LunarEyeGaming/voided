local freezeDelay
local shatterDelay
local state
local timer

function init()
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
      animator.setAnimationState("freezeState", "visible")

      state = "thawing"
      timer = shatterDelay
    end
  elseif state == "thawing" then
    if timer <= 0 then
      animator.playSound("shatter")
      animator.burstParticleEmitter("shatter")
      animator.setAnimationState("freezeState", "invisible")

      state = nil
    end
  end
end