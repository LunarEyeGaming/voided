require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/voidedutil.lua"

local inactiveTime
local activationTime
local activeTime
local deactivationTime

local maxAttractForce
local maxAttractSpeed
local maxAttractRange

local centerOffset

local whirStartVolume
local whirEndVolume
local whirStartPitch
local whirEndPitch

local startSpawnRockInterval
local endSpawnRockInterval
local speedPowerThreshold
local speedPowerMultiplier
local projectileType
local projectileParameters

local warningSize
local emitterSpecs

local glowLightColor

local activationRange

local warningEmitterInterval

local powerLevel
local ownPosition
local center
local spawnTimer
local warningEmitterTimer

local state

function init()
  inactiveTime = config.getParameter("inactiveTime")  -- Amount of time for which the coil is inactive
  activationTime = config.getParameter("activationTime")  -- Amount of time to take to activate
  activeTime = config.getParameter("activeTime")  -- Amount of time for which the coil is active
  deactivationTime = config.getParameter("deactivationTime")  -- Amount of time to take to deactivate

  -- Attract force, speed, and radius all scale with the power level of the coil.
  maxAttractForce = config.getParameter("maxAttractForce")  -- Maximum control force to apply to projectiles
  -- Maximum target speed of the affected projectiles (in blocks per second)
  maxAttractSpeed = config.getParameter("maxAttractSpeed")
  -- The maximum range (in blocks) of the magnetic attraction. This determines the maximum range to spawn and attract
  -- projectiles.
  maxAttractRange = config.getParameter("maxAttractRange")

  centerOffset = config.getParameter("centerOffset")
  
  whirStartVolume = config.getParameter("whirStartVolume")
  whirEndVolume = config.getParameter("whirEndVolume")
  whirStartPitch = config.getParameter("whirStartPitch")
  whirEndPitch = config.getParameter("whirEndPitch")
  
  startSpawnRockInterval = config.getParameter("startSpawnRockInterval")
  endSpawnRockInterval = config.getParameter("endSpawnRockInterval")
  speedPowerThreshold = config.getParameter("speedPowerThreshold")
  speedPowerMultiplier = config.getParameter("speedPowerMultiplier")
  projectileType = config.getParameter("projectileType")
  projectileParameters = config.getParameter("projectileParameters", {})
  
  warningSize = config.getParameter("warningSize")
  emitterSpecs = config.getParameter("warningParticleEmitter")
  
  glowLightColor = config.getParameter("glowLightColor")
  
  activationRange = config.getParameter("activationRange")
  
  warningEmitterInterval = 1 / emitterSpecs.emissionRate
  
  powerLevel = 0
  ownPosition = object.position()
  center = vec2.add(ownPosition, centerOffset)
  spawnTimer = startSpawnRockInterval
  warningEmitterTimer = warningEmitterInterval
  
  state = FSM:new()
  state:set(firstInactive)
end

function update(dt)
  state:update()

  --world.debugText("powerLevel: %s", powerLevel, object.position(), "green")
  
  if powerLevel > 0 then
    updateAnimation()
    attractRocks()

    warningEmitterTimer = warningEmitterTimer - dt
    spawnTimer = spawnTimer - dt
  end
end

-- States
-- These states form a cycle where the coil is inactive, winds up, stays active, winds down, and then repeats.
--[[
  A variant of the inactive state that will be triggered only once. Transitions to the powerUp state.
]]
function firstInactive()
  powerLevel = 0
  
  -- Wait for a player to be in close proximity to the coil.
  while #world.playerQuery(center, activationRange) == 0 do
    coroutine.yield()
  end

  util.wait(inactiveTime)

  animator.playSound("spark")
  animator.burstParticleEmitter("spark")
  
  state:set(powerUp)
end

--[[
  A state where the coil is inactive for a period of time. Transitions to the powerUp state.
]]
function inactive()
  powerLevel = 0

  util.wait(inactiveTime)
  
  state:set(powerUp)
end

function powerUp()
  activate()

  local timer = 0
  util.wait(activationTime, function(dt)
    powerLevel = timer / activationTime
    timer = timer + dt
  end)
  
  state:set(active)
end

function active()
  powerLevel = 1.0

  util.wait(activeTime)
  
  state:set(powerDown)
end

function powerDown()
  local timer = 0
  util.wait(deactivationTime, function(dt)
    powerLevel = 1.0 - timer / activationTime
    timer = timer + dt
  end)
  
  deactivate()
  
  state:set(inactive)
end

-- Helper Functions
function activate()
  -- do some animation
  animator.playSound("whir", -1)
  animator.setLightActive("glow", true)
end

function deactivate()
  --animator.stopAllSounds("whir")
  animator.setGlobalTag("glowOpacity", "00")
  animator.setLightActive("glow", false)
end

function attractRocks()
  local attractForce = powerLevel * maxAttractForce
  local attractSpeed = powerLevel * maxAttractSpeed
  local attractRange = powerLevel * maxAttractRange
  local spawnRockInterval = util.lerp(powerLevel, startSpawnRockInterval, endSpawnRockInterval)

  -- Spawn a rock in a random place
  if spawnTimer <= 0 then
    spawnRock(attractRange, attractSpeed)
    
    spawnTimer = spawnRockInterval
  end
  
  -- Bring in nearby rocks
  local queried = world.entityQuery(center, attractRange, {includedTypes = {"projectile"}})

  for _, proj in ipairs(queried) do
    world.sendEntityMessage(proj, "v-attract", center, attractSpeed, attractForce)
  end
end

function spawnRock(range, speed)
  local position = findPosition(range)
  
  if not position then
    -- Search failed. Don't do anything.
    return
  end
  
  local params = sb.jsonMerge(projectileParameters, {
    speed = speed,
    power = math.max(0, speed * speedPowerMultiplier - speedPowerThreshold)
  })
  
  world.spawnProjectile(projectileType, position, entity.id(), world.distance(center, position), false, params)
end

--[[
  An algorithm to find a random position within a circle of radius "range" that is adjacent to an occupied space and is 
  not occupied by collision geometry.
  
  range: The maximum distance from a position to the center of the object
]]
function findPosition(range)
  -- Find a position adjacent to a solid tile that is not inside of an existing tile.

  -- Get random point in circle of radius "range"
  local offset = vec2.withAngle(util.randomInRange({0, 2 * math.pi}), util.randomInRange({0, range}))
  local startPosition = vec2.add(center, offset)
  
  -- Search along the perimeter of increasingly large squares for the first position that meets all of the following 
  -- conditions:
  -- a. It is within range of the center
  -- b. It is adjacent to a solid tile
  -- c. It is not occupied by a tile
  -- Stop at a square two times the range.
  -- If no position is found, return nil.
  for halfSideLength = 1, range do
    local position = searchAlongPerimeter(startPosition, halfSideLength, function(pos)
      return world.magnitude(center, pos) <= range and not world.pointCollision(pos) and isGroundAdjacent(
          pos)
    end)
    
    if position then
      return position
    end
  end
  
  -- Implicitly returns nil here
end

--[[
  Searches along the perimeter of a square in a clockwise manner for the first position where the result of "condition"
  is true.
  
  squareCenter: The world position of the center of the square
  halfSideLength: A value representing half the side length of the square
  condition: The function to use to determine if a position is satisfactory. Must accept a position coordinate and
      return either true or false.
]]
function searchAlongPerimeter(squareCenter, halfSideLength, condition)
  -- Left side
  for y = -halfSideLength, halfSideLength do
    local pos = vec2.add(squareCenter, {-halfSideLength, y})
    
    if condition(pos) then
      return pos
    end
  end

  -- Top side
  for x = -halfSideLength, halfSideLength do
    local pos = vec2.add(squareCenter, {x, halfSideLength})
    
    if condition(pos) then
      return pos
    end
  end
  
  -- Right side
  for y = halfSideLength, -halfSideLength, -1 do
    local pos = vec2.add(squareCenter, {halfSideLength, y})
    
    if condition(pos) then
      return pos
    end
  end
  
  -- Bottom side
  for x = halfSideLength, -halfSideLength, -1 do
    local pos = vec2.add(squareCenter, {x, -halfSideLength})
    
    if condition(pos) then
      return pos
    end
  end
end

function isGroundAdjacent(position)
  -- Go through all the spaces adjacent to the position and return true if any of them are occupied by a tile.
  for _, offset in ipairs({1, 0}, {0, 1}, {-1, 0}, {0, -1}) do
    if world.material(vec2.add(position, offset), "foreground") then
      return true
    end
  end
  
  return false
end

function updateAnimation()
  animator.setSoundVolume("whir", util.lerp(powerLevel, whirStartVolume, whirEndVolume), 0)
  animator.setSoundPitch("whir", util.lerp(powerLevel, whirStartPitch, whirEndPitch), 0)
  
  if warningEmitterTimer <= 0 then
    local warningScale = powerLevel * maxAttractRange / warningSize
    emitParticle(warningScale)
    
    warningEmitterTimer = warningEmitterInterval
  end

  animator.setGlobalTag("glowOpacity", string.format("%02x", math.floor(255 * powerLevel)))
  
  animator.setLightColor("glow", lerpColorRGB(powerLevel, {0, 0, 0}, glowLightColor))
end

function emitParticle(size)
  -- Copy particle specifications of emitter for later modification.
  local particleSpecs = copy(emitterSpecs.particle)
  
  -- Set the size
  particleSpecs.size = size
  
  -- If configured to apply hue shift to the particle, apply it.
  if emitterSpecs.applyHueShift then
    applyHueShift(particleSpecs)
  end
  
  -- Emit the particle. This uses a projectile because the API does not allow spawning of particles directly.
  world.spawnProjectile("orbitalup", center, entity.id(), {0, 0}, false, {
    timeToLive = 0,
    onlyHitTerrain = true,
    actionOnReap = {
      {
        action = "particle",
        specification = particleSpecs
      }
    }
  })
end