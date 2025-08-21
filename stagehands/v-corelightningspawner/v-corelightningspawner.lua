require "/scripts/util.lua"
require "/scripts/vec2.lua"

local lightningXPosRange
local lightningTimeRange
local maxSpawnHeight
local projectileType
local projectileDirection
local projectileParameters
local lightningRodType
local lightningRodRedirectRadius

local timer

function init()
  lightningXPosRange = config.getParameter("lightningXPosRange")
  lightningTimeRange = config.getParameter("lightningTimeRange")
  maxSpawnHeight = config.getParameter("maxSpawnHeight")
  projectileType = config.getParameter("projectileType")
  projectileDirection = config.getParameter("projectileDirection")
  projectileParameters = config.getParameter("projectileParameters")
  lightningRodType = config.getParameter("lightningRodType", "v-lightningrod")
  lightningRodRedirectRadius = config.getParameter("lightningRodRedirectRadius", 50)

  timer = util.randomInRange(lightningTimeRange)

  -- Spawn lake force projectile.
  world.spawnProjectile(config.getParameter("lakeForceProjectile", "v-voltagelakeforce"), stagehand.position())
end

function update(dt)
  local ownPos = stagehand.position()

  timer = timer - dt

  if timer < 0 then
    local xPos = util.randomInRange(lightningXPosRange) + ownPos[1]
    local testPos = vec2.add({xPos, ownPos[2]}, {0, maxSpawnHeight})

    -- Avoid spawning lightning inside dungeons.
    if world.isTileProtected({xPos, ownPos[2]}) then
      return
    end

    local pos = world.lineCollision({xPos, ownPos[2]}, testPos)

    -- If a collision was detected...
    if pos then
      spawnLightning(projectileType, pos, projectileDirection, projectileParameters)
      timer = util.randomInRange(lightningTimeRange)
    end

    -- Timer does not get reset until a spot was chosen.
  end
end

function spawnLightning(projType, position, direction, params)
  -- lightningboltredirection. Convert to a function named redirectLightning and put into a utility script if more than
  -- two are used.

  -- Query objects within a `lightningRodRedirectRadius` with name `lightningRodType`.
  local queried = world.objectQuery(position, lightningRodRedirectRadius, {order = "nearest",
      name = lightningRodType})

  local targetPos

  -- If at least one object was found...
  if #queried > 0 and world.getObjectParameter(queried[1], "isUpsideDown") then
    targetPos = world.entityPosition(queried[1])
  else
    targetPos = position
  end

  -- Spawn the projectile
  world.spawnProjectile(projType, targetPos, nil, direction, false, params)
end