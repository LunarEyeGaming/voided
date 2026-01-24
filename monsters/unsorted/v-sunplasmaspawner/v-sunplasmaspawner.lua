local shouldDieVar

local liquidId
local quantity
local spawnDelay
local spawnDelayTimer

local numTicks

function init()
  liquidId = config.getParameter("liquidId")
  quantity = config.getParameter("quantity")
  spawnDelay = config.getParameter("spawnDelay")
  spawnDelayTimer = spawnDelay
  shouldDieVar = false

  numTicks = 2

  monster.setDamageBar("None")
end

function update(dt)
  if numTicks then
    numTicks = numTicks - 1
    if numTicks <= 0 then
      animator.playSound("warning")
      animator.setParticleEmitterActive("warning", true)
      numTicks = nil
    end
  end
  spawnDelayTimer = spawnDelayTimer - dt
  if spawnDelayTimer <= 0 then
    local position = mcontroller.position()
    local isTileProtected = world.isTileProtected(position)
    local dungeonId = world.dungeonId(position)

    -- Temporarily disable tile protection so that it can place the object.
    if isTileProtected then
      world.setTileProtection(dungeonId, false)
    end

    world.spawnLiquid(position, liquidId, quantity)

    -- Turn tile protection back on.
    if isTileProtected then
      world.setTileProtection(dungeonId, true)
    end

    shouldDieVar = true
  end
end

function shouldDie()
  return shouldDieVar
end