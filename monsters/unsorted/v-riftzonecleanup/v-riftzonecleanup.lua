require "/scripts/rect.lua"

local INSTANT_BREAK_DAMAGE = 2 ^ 32

local shouldDieVar

function init()

end

function update(dt)
  if world.regionActive(rect.translate({-32, -32, 32, 32}, mcontroller.position())) then
    local blocksToClearFG = config.getParameter("blocksToClearFG", {})
    local blocksToClearBG = config.getParameter("blocksToClearBG", {})

    world.damageTiles(blocksToClearFG, "foreground", mcontroller.position(), "blockish", INSTANT_BREAK_DAMAGE, 0)
    world.damageTiles(blocksToClearBG, "background", mcontroller.position(), "blockish", INSTANT_BREAK_DAMAGE, 0)

    shouldDieVar = true
  end
end

function shouldDie()
  return shouldDieVar
end