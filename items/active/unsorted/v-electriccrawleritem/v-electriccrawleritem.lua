require "/scripts/vec2.lua"

local level
local throwSpeed
local monsterType
local initialStunTime
local initialHealthPercentage
local uniqueParameters

function init()
  level = config.getParameter("level")
  throwSpeed = config.getParameter("throwSpeed")
  monsterType = config.getParameter("monsterType")
  initialStunTime = config.getParameter("initialStunTime")
  initialHealthPercentage = config.getParameter("healthPercentage")
  uniqueParameters = config.getParameter("uniqueParameters")
end

function update(dt, fireMode)
  if fireMode == "primary" and prevFireMode ~= fireMode then
    throw()
  end
  prevFireMode = fireMode
end

function throw()
  animator.playSound("throw")

  local velocity = vec2.mul(getAimVector(), throwSpeed)
  -- The monster is assumed to be scripted to handle all these parameters properly.
  local params = {level = level, flingVelocity = velocity, initialStunTime = initialStunTime, 
      initialHealthPercentage = initialHealthPercentage}
  world.spawnMonster(monsterType, mcontroller.position(), sb.jsonMerge(uniqueParameters, params))

  item.consume(1)
end

function getAimVector()
  return vec2.norm(world.distance(activeItem.ownerAimPosition(), mcontroller.position()))
end

function uninit()

end

