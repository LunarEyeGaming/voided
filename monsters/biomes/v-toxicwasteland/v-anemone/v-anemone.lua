function init()
  monster.setDamageOnTouch(true)

  monster.setDeathParticleBurst("deathPoof")

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end
end

function update(dt)
  local isStunned = status.resourcePositive("stunned")

  -- Update stunned state and damage on touch.
  animator.setAnimationState("damage", isStunned and "stunned" or "none")
  monster.setDamageOnTouch(not isStunned)
end