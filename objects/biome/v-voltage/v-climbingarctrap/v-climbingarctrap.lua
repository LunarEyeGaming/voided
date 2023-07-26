require "/scripts/util.lua"
require "/scripts/vec2.lua"

--[[
  This script is for an object that creates a climbing arc (aka Jacob's ladder) hazard. It specifically handles things
  like the movement, drawing, and damage of the hazard. Periodically, an arc is created that spans from the leftmost 
  tile to the rightmost tile. If the width of this arc exceeds the specifiable limit, it disappears. The arc slowly 
  rises with the previous conditions applying--i.e., it will eventually reach the "top" and disappear. Note that the arc
  will touch tiles of all materials regardless of whether they are tagged as "conductive" (see v-matattributes.config).
  The object also has the ability to "roll" down to a local minimum. Due to API limitations, the parameter overrides to
  keep after doing this action must be manually specified in a list called "overriddenParams."
]]

local COLLISION_SPAN = 150

local overriddenParams

local maxArcWidth
local minArcWidth
local maxHeight
local climbingSpeed
local waitTime
local damageSourceConfig
local shouldRollDown
local state

function init()
  overriddenParams = config.getParameter("overriddenParams")

  maxArcWidth = config.getParameter("maxArcWidth")
  minArcWidth = config.getParameter("minArcWidth")
  maxHeight = config.getParameter("maxHeight")
  climbingSpeed = config.getParameter("climbingSpeed")
  waitTime = config.getParameter("waitTime")
  damageSourceConfig = config.getParameter("damageSourceConfig")
  shouldRollDown = config.getParameter("shouldRollDown")
  
  state = FSM:new()
  state:set(wait)
  
  if shouldRollDown then
    rollDownHill()
  end
end

function update(dt)
  state:update()
end

-- STATES

--[[
  Waits for a given amount of time.
]]
function wait()
  util.wait(waitTime)
  if shouldRollDown then
    rollDownHill()
  end

  state:set(arc)
end

--[[
  Moves an arc upwards until it is too wide or too high.
]]
function arc()
  local dt = script.updateDt()

  local arcWidth
  local arcHeight = 0
  
  -- Turn animations on
  animator.playSound("ambient", -1)
  animator.setParticleEmitterActive("impactLeft", true)
  animator.setParticleEmitterActive("impactRight", true)
  animator.setLightActive("leftLight", true)
  animator.setLightActive("midLight", true)
  animator.setLightActive("rightLight", true)

  local midpoint = util.tileCenter(object.position())  -- Starting midpoint

  -- The main part of the climbing arc.
  repeat
    coroutine.yield()  -- Placed here to prevent the arc from doing unfair damage

    -- Collisions are tested from the midpoint of the previous iteration for more intelligent arc climbing.
    arcWidth, midpoint = generateArc(midpoint)
    if midpoint then
      midpoint = vec2.add(midpoint, {0, climbingSpeed * dt})
    end
    arcHeight = arcHeight + climbingSpeed * dt
  until (arcWidth > maxArcWidth or arcWidth < minArcWidth) or arcHeight > maxHeight
  
  -- Reset everything
  animator.stopAllSounds("ambient")

  animator.setParticleEmitterActive("impactLeft", false)
  animator.setParticleEmitterActive("impactRight", false)

  animator.setLightActive("leftLight", false)
  animator.setLightActive("midLight", false)
  animator.setLightActive("rightLight", false)

  animator.resetTransformationGroup("leftpoint")
  animator.resetTransformationGroup("midpoint")
  animator.resetTransformationGroup("rightpoint")

  object.setAnimationParameter("lightning", {})
  object.setDamageSources()
  
  state:set(wait)
end

--[[
  Handles the damage and drawing of the arc at a specific height. Returns the width of the arc and the midpoint of the
  colliding positions.
  
  startPos: The midpoint of the current iteration
  return: the width of the arc, the new midpoint
]]
function generateArc(startPos)
  local leftTest = vec2.add(startPos, {-COLLISION_SPAN, 0})
  local rightTest = vec2.add(startPos, {COLLISION_SPAN, 0})

  local leftCollide = world.lineCollision(startPos, leftTest)
  local rightCollide = world.lineCollision(startPos, rightTest)
  
  if not leftCollide or not rightCollide then
    return math.huge  -- Force the arc not to form if either endpoint is too far from the object.
  end
  
  local midpoint = getMidpoint(leftCollide, rightCollide)
  
  local leftLength = world.magnitude(startPos, leftCollide)
  local rightLength = world.magnitude(startPos, rightCollide)
  
  setDamageArc(leftCollide, rightCollide)
  drawLightning(leftCollide, rightCollide)
  updateEffects(leftCollide, midpoint, rightCollide)
  
  return leftLength + rightLength, midpoint
end

--[[
  Sets the damage region to be a horizontal line with a starting absolute position of "from" and an ending absolute
  position of "to."
  
  from: The starting absolute position
  to: The ending absolute position
]]
function setDamageArc(from, to)
  local dmgCfg = copy(damageSourceConfig)
  local relativeFrom = world.distance(from, object.position())
  local relativeTo = world.distance(to, object.position())
  dmgCfg.poly = {relativeFrom, relativeTo}
  object.setDamageSources({dmgCfg})
end

--[[
  Sends data to the scripted animator to draw lightning of config "lightningConfig" from "startPos" to "endPos."

  startPos: The starting absolute position
  endPos: The ending absolute position
]]
function drawLightning(startPos, endPos)
  local lightning = config.getParameter("lightningConfig")
  lightning.worldStartPosition = startPos
  lightning.worldEndPosition = endPos
  object.setAnimationParameter("lightning", {lightning})
end

--[[
  Updates transformation groups and sound positions to reflect the leftmost, middle, and rightmost portions of the arc.
  
  left: The leftmost point to use
  middle: The middle point to use
  right: The rightmost point to use
]]
function updateEffects(left, mid, right)
  local pos = object.position()
  local dir = object.direction()

  local relativeLeft = world.distance(left, pos)
  local relativeMid = world.distance(mid, pos)
  local relativeRight = world.distance(right, pos)

  -- Update transformation groups, accounting for the object's direction so that particle positions are correct.
  animator.resetTransformationGroup("leftpoint")
  animator.translateTransformationGroup("leftpoint", vec2.mul(relativeLeft, {dir, 1}))
  
  animator.resetTransformationGroup("midpoint")
  animator.translateTransformationGroup("midpoint", vec2.mul(relativeMid, {dir, 1}))
  
  animator.resetTransformationGroup("rightpoint")
  animator.translateTransformationGroup("rightpoint", vec2.mul(relativeRight, {dir, 1}))
  
  animator.setSoundPosition("ambient", vec2.mul(relativeMid, {dir, 1}))
end

--[[
  Returns the midpoint between two absolute positions.

  pos1: First position
  pos2: Second position
]]
function getMidpoint(pos1, pos2)
  local pos2Fixed = world.nearestTo(pos1, pos2)  -- Prevent world wrapping issue
  return {(pos1[1] + pos2Fixed[1]) / 2, (pos1[2] + pos2Fixed[2]) / 2}
end

--[[
  Displaces the object to be at the lowest point on the surface - the bottom of the "hill." Note: overridden parameters
  must be manually specified in the "overriddenParams" parameter in order to be preserved.
]]
function rollDownHill()
  -- TODO: Find out why it does not properly move if its final spot is in a one block wide gap.
  local localMin = findLocalMinimum()
  if localMin then
    world.placeObject(config.getParameter("objectName"), localMin, nil, getParameters(overriddenParams))
    object.smash(true)  -- Goodbye cruel world...
  end
end

--[[
  Bidirectional variant of findLocalMinimum. Returns findLocalMinimum from starting at the right if it exists before
  returning the left-starting call.
]]
function findLocalMinimum()
  local result = findLocalMinimum_(1)
  if not result then
    return findLocalMinimum_(-1)
  else
    return result
  end
end

--[[
  Algorithm for finding the lowest ground position within a certain number of iterations. Returns nil if it rolls back
  to its original spot. This is a helper method for the bidirectional variant of this function.
  
  initialDirection: The starting direction to use.
]]
function findLocalMinimum_(initialDirection)
  -- In steps, move the position downhill until it cannot roll any further or it reaches too many iterations, in which
  -- case it returns the best result.
  local initialPos = object.position()
  local currentDirection = initialDirection
  local curPos = initialPos
  local hasNotAdvanced = true

  for i = 1, 100 do
    -- Fall downwards if there is no ground below. Bounce off any walls in the opposite direction. Move in the same
    -- direction if any of the previous conditions don't apply.
    if isVacant(curPos, {0, -1}) then
      curPos = vec2.add(curPos, {0, -1})
    elseif isVacant(curPos, {currentDirection, 0}) then
      curPos = vec2.add(curPos, {currentDirection, 0})
    elseif isVacant(curPos, {-currentDirection, 0}) then
      curPos = vec2.add(curPos, {-currentDirection, 0})
      currentDirection = -currentDirection
    else
      break
    end
    
    if vec2.eq(curPos, initialPos) then
      break
    end
  end
  
  -- Return nothing if the loop resulted in the target rolling back to the initial position to avoid infinite recursion.
  if not vec2.eq(curPos, initialPos) then
    return curPos
  end
end

--[[
  Returns true if no solid is occupying the space at the given offset from the current position.

  pos: The base position
  offset: The offset from "pos" to use when checking for collision.
]]
function isVacant(pos, offset)
  return not world.pointCollision(util.tileCenter(vec2.add(pos, offset)))
end

--[[
  Returns a table containing the parameters and their corresponding values.

  params: The list of parameters to copy.
]]
function getParameters(params)
  local result = {}

  for _, param in ipairs(params) do
    result[param] = config.getParameter(param)
  end

  return result
end