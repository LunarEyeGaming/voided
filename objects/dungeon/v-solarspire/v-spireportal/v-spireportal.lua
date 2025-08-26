require "/scripts/poly.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-animator.lua"
require "/scripts/v-ministarutil.lua"
require "/scripts/v-vec2.lua"
require "/scripts/v-world.lua"

-- Parameters
local centerOffset
local center
local portalOpenTime
local portalCloseTime

local portalLightningFadeTime
local portalLightningStartColor
local portalLightningEndColor
local portalLightningStartOutlineColor
local portalLightningEndOutlineColor
local portalLightningConfig

-- State variables / objects
local hazards
local hazardCooldowns
local state
local lightningController

local currentDestination

function init()
  -- TODO: Parametrize all of these
  centerOffset = {10, 10}
  center = vec2.add(object.position(), centerOffset)
  portalOpenTime = 0.5
  portalCloseTime = 0.5

  portalLightningFadeTime = config.getParameter("portalLightningFadeTime")
  portalLightningStartColor = config.getParameter("portalLightningStartColor")
  portalLightningEndColor = config.getParameter("portalLightningEndColor")
  portalLightningStartOutlineColor = config.getParameter("portalLightningStartOutlineColor")
  portalLightningEndOutlineColor = config.getParameter("portalLightningEndOutlineColor")
  portalLightningConfig = config.getParameter("portalLightningConfig")

  hazards = {
    {
      func = states.floorHazard,
      config = {
        projectileType = "v-breadcrustbombportal",
        projectileParameters = {timeToLive = 1.5, speed = 100},
        projectileCount = 12,
        projectileInterval = 0.25,
        projectileOffsetRegion = {-5, -5, 5, 5},
        projectileAngle = -math.pi / 2,
        projectileFuzzAngle = 45 * math.pi / 180
      },
      cooldown = 20
    },
    {
      func = states.rotatingHazard,
      config = {
        startAngle = math.pi / 2,
        endAngle = 2 * math.pi + math.pi / 2,
        damageSource = {  ---@type DamageSource
          damage = 40,
          damageSourceKind = "fire",
          rayCheck = true,
          teamType = "enemy",
          damageType = "IgnoresDef"
        },
        damagePolyThickness = 8,
        damageSourcePoly = {{0, 8}, {0, -8}, {100, -8}, {100, 8}},
        maxBeamLength = 100,
        duration = 15
      },
      cooldown = 20
    },
    {
      func = states.enemyHazard,
      config = {
        monsterGroups = {
          { type = "v-sunleaper", count = 2, destination = "surface2", onGround = true },
          { type = "v-novamonster", count = 1, destination = "surface2", onGround = false },
          { type = "v-pyrebush", count = 2, destination = "forest", onGround = true },
          { type = "v-rammingasteroid", count = 1, destination = "asteroids", onGround = false },
          { type = "v-lurkano", count = 2, destination = "caves", onGround = true },
          { type = "v-firefloater", count = 2, destination = "sky", onGround = false }
        },
        startOffsetRegion = {-5, -5, 5, 5},
        airOffsetRegion = {-24, -24, 24, 24},
        groundRaycastLength = 100,
        spawnerProjectileType = "v-spirespawnerorb"
      },
      cooldown = 20
    }
  }

  hazardCooldowns = {}
  for i, _ in ipairs(hazards) do
    hazardCooldowns[i] = 0
  end
  lightningController = vAnimator.LightningController:new(
    portalLightningConfig,
    portalLightningStartColor,
    portalLightningEndColor,
    portalLightningFadeTime,
    false,
    portalLightningStartOutlineColor,
    portalLightningEndOutlineColor
  )

  state = FSM:new()
  state:set(states.noop)
  object.setInteractive(true)
end

function update(dt)
  -- Update cooldowns
  for i, cooldown in ipairs(hazardCooldowns) do
    hazardCooldowns[i] = cooldown - dt
  end

  state:update()

  lightningController:update(dt)
  world.debugText("destination: %s", currentDestination, object.position(), "green")
end

function onInteraction()
  state:set(states.hazardStart)
  object.setInteractive(false)
end

-- STATES
states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.hazardStart()
  coroutine.yield()  -- Defer to update

  invokeHazard(pickHazard())
end

function states.floorHazard(cfg)
  switchDestination("sky")

  for _ = 1, cfg.projectileCount do
    local spawnPos = vec2.add(center, rect.randomPoint(cfg.projectileOffsetRegion))
    local spawnDirection = vec2.withAngle(vVec2.randomAngle(cfg.projectileAngle, cfg.projectileFuzzAngle))

    world.spawnProjectile(cfg.projectileType, spawnPos, entity.id(), spawnDirection, false, cfg.projectileParameters)

    util.wait(cfg.projectileInterval)
  end

  util.wait(5)

  invokeHazard(pickHazard())
end

function states.rotatingHazard(cfg)
  switchDestination("surface")

  animator.setAnimationState("sunbeam", "on")

  local dmgSource = copy(cfg.damageSource)
  local startAngle = cfg.startAngle
  local angleDelta = cfg.endAngle - cfg.startAngle
  local duration = cfg.duration
  local timer = 0
  util.wait(duration, function(dt)
    local angle = util.easeInOutSin(timer / duration, startAngle, angleDelta)
    local beamEnd = vec2.add(center, vec2.withAngle(angle, cfg.maxBeamLength))
    beamEnd = vMinistar.lightLineTileCollision(center, beamEnd) or beamEnd
    local mag = world.magnitude(center, beamEnd)
    local damagePoly = poly.translate({
      vec2.rotate({0, cfg.damagePolyThickness}, angle),
      vec2.rotate({0, -cfg.damagePolyThickness}, angle),
      vec2.rotate({mag, -cfg.damagePolyThickness}, angle),
      vec2.rotate({mag, cfg.damagePolyThickness}, angle),
    }, centerOffset)
    dmgSource.poly = damagePoly

    animator.resetTransformationGroup("sunbeam")
    animator.scaleTransformationGroup("sunbeam", {mag, 1}, centerOffset)
    animator.translateTransformationGroup("sunbeam", {mag / 2, 0})
    animator.rotateTransformationGroup("sunbeam", angle, centerOffset)

    object.setDamageSources({dmgSource})

    timer = timer + dt
  end)

  animator.setAnimationState("sunbeam", "off")
  object.setDamageSources({})

  invokeHazard(pickHazard())
end

function states.enemyHazard(cfg)
  local monsterGroup = util.randomFromList(cfg.monsterGroups)

  object.setAnimationParameter("lightningSeed", math.floor(os.clock()))

  switchDestination(monsterGroup.destination)

  local monsterIds = {}  -- Gets populated by the message handler
  message.setHandler("v-monsterSpawned", function(_, _, monsterId)
    table.insert(monsterIds, monsterId)
  end)

  local projectileIds = {}
  for _ = 1, monsterGroup.count do
    local startPos = vec2.add(center, rect.randomPoint(cfg.startOffsetRegion))

    -- Pick spawn position
    local spawnPos
    if monsterGroup.onGround then
      local angle = math.random() * 2 * math.pi
      spawnPos = world.lineCollision(startPos, vec2.add(startPos, vec2.withAngle(angle, cfg.groundRaycastLength)))
      if not spawnPos then
        error("Line collision returned nil.")
      end
    else
      spawnPos = vWorld.randomPositionInRegion(rect.translate(cfg.airOffsetRegion, center), function(pos)
        return not world.pointCollision(pos)
      end, 200)
    end

    if spawnPos then
      -- Strike lightning
      lightningController:add(startPos, spawnPos)

      -- Spawn a projectile that will spawn the monster
      local projectileId = world.spawnProjectile(cfg.spawnerProjectileType, spawnPos, entity.id(), {1, 0}, false, {monsterType = monsterGroup.type,
          monsterParameters = {level = object.level()}})

      table.insert(projectileIds, projectileId)
    end
  end

  -- While at least one of the spawned projectiles is still alive...
  while #projectileIds > 0 do
    -- Filter out projectiles that died
    projectileIds = util.filter(projectileIds, function(id) return world.entityExists(id) end)

    coroutine.yield()
  end

  message.setHandler("v-monsterwavespawner-monsterspawned", function(_, _, id)
    table.insert(monsterIds, id)
  end)

  while #monsterIds > 0 do
    monsterIds = util.filter(monsterIds, function(id) return world.entityExists(id) end)

    coroutine.yield()
  end

  util.wait(3)

  invokeHazard(pickHazard())
end

-- HELPER FUNCTIONS

---@return integer
function pickHazard()
  local possibleHazards = {}
  for i, cooldown in ipairs(hazardCooldowns) do
    if cooldown <= 0 then
      table.insert(possibleHazards, i)
    end
  end

  -- Pick a completely random hazard
  if #possibleHazards == 0 then
    sb.logInfo("v-spireportal: All hazards on cooldown. Picking random hazard.")
    return math.random(1, #hazards)
  else
    return possibleHazards[math.random(1, #possibleHazards)]
  end
end

function invokeHazard(hazardIdx)
  local hazard = hazards[hazardIdx]
  hazardCooldowns[hazardIdx] = hazard.cooldown
  hazard.func(hazard.config)
end

function switchDestination(destination)
  animator.setAnimationState("portal", "unlink")

  util.wait(portalCloseTime)

  currentDestination = destination
  animator.setGlobalTag("destination", destination)
  animator.setAnimationState("portal", "relink")

  util.wait(portalOpenTime)
end