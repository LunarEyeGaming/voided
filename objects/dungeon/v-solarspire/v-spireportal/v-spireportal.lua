require "/scripts/poly.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-animator.lua"
require "/scripts/v-entity.lua"
require "/scripts/v-ministarutil.lua"
require "/scripts/v-vec2.lua"
require "/scripts/v-world.lua"

-- Parameters
local centerOffset
local center
local portalOpenTime
local portalCloseTime
local portalOffsetRegion
local playerTeleportQueryRegion
local playerDetectQueryRegion
local arenaRegion
local lightningEndOffsetRegion
local preIntroDungeonMusic
local postIntroDungeonMusic

local portalLightningFadeTime
local portalLightningStartColor
local portalLightningEndColor
local portalLightningStartOutlineColor
local portalLightningEndOutlineColor
local portalLightningConfig

local summonMinibossArgs
local summonMinibossThreshold

-- State variables / objects
local hazards
local hazardCooldowns
local hazardCounter
local state
local lightningController
local lightningControllerBig
local minibossId

local currentDestination

-- HOOKS
function init()
  -- TODO: Parametrize all of these
  centerOffset = {10, 10}
  center = vec2.add(object.position(), centerOffset)
  portalOpenTime = 0.5
  portalCloseTime = 0.5
  portalOffsetRegion = {-5, -5, 5, 5}
  playerTeleportQueryRegion = vEntity.getRegionPoints(config.getParameter("playerTeleportQueryRegion"))
  playerDetectQueryRegion = vEntity.getRegionPoints(config.getParameter("playerDetectQueryRegion"))
  playerDetectQueryRegion = vEntity.getRegionPoints(config.getParameter("playerDetectQueryRegion"))
  arenaRegion = vEntity.getRegionPoints(config.getParameter("arenaRegion"))
  lightningEndOffsetRegion = {-30, -30, 30, 30}
  preIntroDungeonMusic = config.getParameter("dungeonMusic.preIntro")
  postIntroDungeonMusic = config.getParameter("dungeonMusic.postIntro")
  world.setProperty("v-dungeonMusicStopFadeTime", config.getParameter("dungeonMusicStopFadeTime", 2.0))

  portalLightningFadeTime = config.getParameter("portalLightningFadeTime")
  portalLightningStartColor = config.getParameter("portalLightningStartColor")
  portalLightningEndColor = config.getParameter("portalLightningEndColor")
  portalLightningStartOutlineColor = config.getParameter("portalLightningStartOutlineColor")
  portalLightningEndOutlineColor = config.getParameter("portalLightningEndOutlineColor")
  portalLightningConfig = config.getParameter("portalLightningConfig")
  portalLightningBigConfig = config.getParameter("portalLightningBigConfig")

  hazards = {
    {
      func = states.floorHazard,
      config = {
        projectileType = "v-breadcrustbombportal",
        projectileParameters = {timeToLive = 1.5, speed = 100},
        projectileCount = 12,
        projectileInterval = 0.25,
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
          damage = 0,
          damageRepeatTimeout = 0.05,
          damageSourceKind = "hidden",
          rayCheck = true,
          teamType = "environment",
          damageType = "IgnoresDef",
          statusEffects = {"v-spireportalheat"}
        },
        damagePolyThickness = 8,
        damageSourcePoly = {{0, 8}, {0, -8}, {100, -8}, {100, 8}},
        maxBeamLength = 100,
        duration = 15,
        fastDuration = 7.5
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
          { type = "v-firefloater", count = 4, destination = "sky", onGround = false }
        },
        airOffsetRegion = {-24, -24, 24, 24},
        groundRaycastLength = 100,
        spawnerProjectileType = "v-spirespawnerorb"
      },
      cooldown = 20
    }
  }

  summonMinibossArgs = {
    spawnOffset = {0, 20},
    monsterType = "v-spireminiboss",
    monsterParameters = {
      musicStagehands = {"v-spireminibossmusic"},
      uniqueId = "v-spireminiboss"
    },
    spawnerProjectileType = "v-spireportalminibossspawn"
  }
  summonMinibossArgs.monsterParameters.level = object.level()
  summonMinibossThreshold = 5

  hazardCooldowns = {}
  for i, _ in ipairs(hazards) do
    hazardCooldowns[i] = 0
  end
  hazardCounter = 0
  lightningController = vAnimator.LightningController:new(
    portalLightningConfig,
    portalLightningStartColor,
    portalLightningEndColor,
    portalLightningFadeTime,
    false,
    portalLightningStartOutlineColor,
    portalLightningEndOutlineColor
  )
  lightningControllerBig = vAnimator.LightningController:new(
    portalLightningBigConfig,
    portalLightningStartColor,
    portalLightningEndColor,
    portalLightningFadeTime,
    false,
    portalLightningStartOutlineColor,
    portalLightningEndOutlineColor
  )

  state = FSM:new()
  state:set(states.postInit)
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
  return { "OpenTeleportDialog", {
      canBookmark = false,
      includePlayerBookmarks = false,
      destinations = { {
        name = "placeholder",
        planetName = "electrotoxicfacility",
        icon = "default",
        warpAction = string.format("InstanceWorld:v-electrotoxicfacility")
      } }
    }
  }
end

-- STATES
states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.postInit()
  coroutine.yield()

  local musicStagehand = world.loadUniqueEntity("v-spireminibossmusic")
  if musicStagehand == 0 then
    sb.logWarn("Stagehand with ID 'v-spireminibossmusic' not found.")
  else
    world.sendEntityMessage(musicStagehand, "setMusicState", "partial")
  end

  local dungeonId = tostring(world.dungeonId(object.position()))
  world.setProperty("v-dungeonMusic", {[dungeonId] = preIntroDungeonMusic})

  if storage.status == "active" then
    states.destabilize2()
  elseif storage.status == "open" then
    states.openToWorld()
  else
    states.awaitActivation()
  end
end

function states.awaitActivation()
  object.setAllOutputNodes(true)

  while not object.getInputNodeLevel(0) do
    coroutine.yield()
  end

  states.attemptActivation()
end

function states.attemptActivation()
  local crystal = world.loadUniqueEntity("v-spirecrystal")

  if crystal == 0 then
    error("Entity with uniqueId 'v-spirecrystal' not found")
  end

  if world.callScriptedEntity(crystal, "isRepaired") then
    states.open()
  else
    animator.playSound("error")
    states.awaitDeactivation()
  end
end

function states.awaitDeactivation()
  while object.getInputNodeLevel(0) do
    coroutine.yield()
  end

  states.awaitActivation()
end

function states.open()
  storage.active = true

  animator.setAnimationState("portal", "open")

  util.wait(3)

  states.destabilize1()
end

function states.destabilize1()
  animator.burstParticleEmitter("portalsparks")
  animator.playSound("firstSpark")
  animator.setParticleEmitterActive("portalsparks", true)
  animator.playSound("sparks", -1)

  util.wait(1.5)

  object.setAllOutputNodes(false)

  animator.setAnimationState("portalshockwave", "visible")
  animator.playSound("explosion")
  local timer = 0
  local shockwaveTime = 1
  local minScale = 0
  local maxScale = 5
  util.wait(shockwaveTime, function(dt)
    local progress = timer / shockwaveTime
    local scale = util.lerp(progress, minScale, maxScale)
    animator.resetTransformationGroup("portalshockwave")
    animator.scaleTransformationGroup("portalshockwave", scale, centerOffset)
    animator.setPartTag("portalshockwave", "opacity", string.format("%02x", math.floor(255 * (1 - progress))))

    timer = timer + dt
  end)

  local dungeonId = tostring(world.dungeonId(object.position()))
  world.setProperty("v-dungeonMusic", {[dungeonId] = postIntroDungeonMusic})
  for _, entityId in ipairs(world.players()) do
    world.sendEntityMessage(entityId, "v-dungeonmusicplayer-forceSwitch")
  end

  animator.setPartTag("portalshockwave", "opacity", "00")

  util.wait(2.0)

  for _ = 1, 7 do
    strikeLightning()
    util.wait(1.0)
  end

  local queried = world.entityQuery(playerTeleportQueryRegion[1], playerTeleportQueryRegion[2], {
    includedTypes = {"player"}
  })

  for _, entityId in ipairs(queried) do
    strikeLightning(world.entityPosition(entityId))
    world.sendEntityMessage(entityId, "applyStatusEffect", "v-solarspireteleport")
    util.wait(0.15)
  end

  util.wait(2.0)

  states.destabilize2()
end

function states.destabilize2()
  while not friendlyInsideRegion(playerDetectQueryRegion) do
    strikeLightning()
    util.wait(1.0)
  end

  states.hazardStart()
end

function states.hazardStart()
  coroutine.yield()  -- Defer to update

  if not friendlyInsideRegion(arenaRegion) then
    return states.destabilize2()
  end

  sb.logInfo("%s ?= %s: %s", hazardCounter, summonMinibossThreshold, hazardCounter == summonMinibossThreshold)
  if hazardCounter == summonMinibossThreshold then
    hazardCounter = hazardCounter + 1
    states.summonMiniboss(summonMinibossArgs)
  else
    -- Check for whether or not the miniboss has died. If so, open a portal to another world instead.
    if minibossId and not world.entityExists(minibossId) then
      return states.openToWorld()
    end
    invokeHazard(pickHazard(), hazardCounter < summonMinibossThreshold)
  end
end

function states.floorHazard(cfg, fast)
  switchDestination("sky")

  local projectileConfig = copy(cfg.projectileParameters)
  projectileConfig.power = (projectileConfig.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", object.level())

  for _ = 1, cfg.projectileCount do
    local spawnPos = vec2.add(center, rect.randomPoint(portalOffsetRegion))
    local spawnDirection = vec2.withAngle(vVec2.randomAngle(cfg.projectileAngle, cfg.projectileFuzzAngle))

    world.spawnProjectile(cfg.projectileType, spawnPos, entity.id(), spawnDirection, false, projectileConfig)

    util.wait(cfg.projectileInterval)
  end

  if fast then
    util.wait(3)
  else
    util.wait(5)
  end

  states.hazardStart()
end

function states.rotatingHazard(cfg, fast)
  switchDestination("surface")

  animator.setAnimationState("sunbeam", "on")

  local dmgSource = copy(cfg.damageSource)
  local startAngle = cfg.startAngle
  local angleDelta = cfg.endAngle - cfg.startAngle
  local duration = fast and cfg.fastDuration or cfg.duration
  local timer = 0
  util.wait(duration, function(dt)
    local angle = util.easeInOutSin(timer / duration, startAngle, angleDelta)
    local beamEnd = vec2.add(center, vec2.withAngle(angle, cfg.maxBeamLength))
    beamEnd = vMinistar.lightLineTileCollision(center, beamEnd) or beamEnd
    local mag = world.magnitude(center, beamEnd)
    local damagePoly = poly.translate({
      vec2.rotate({-10, cfg.damagePolyThickness}, angle),
      vec2.rotate({-10, -cfg.damagePolyThickness}, angle),
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

  states.hazardStart()
end

function states.enemyHazard(cfg, fast)
  local monsterGroup = util.randomFromList(cfg.monsterGroups)

  object.setAnimationParameter("lightningSeed", math.floor(os.clock()))

  switchDestination(monsterGroup.destination)

  local monsterIds = {}  -- Gets populated by the message handler
  message.setHandler("v-monsterSpawned", function(_, _, monsterId)
    table.insert(monsterIds, monsterId)
  end)

  animator.playSound("lightningStrike")

  local projectileIds = {}
  for _ = 1, monsterGroup.count do
    local startPos = vec2.add(center, rect.randomPoint(portalOffsetRegion))

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

  if fast then
    util.wait(1)
  else
    util.wait(3)
  end

  states.hazardStart()
end

function states.summonMiniboss(cfg)
  switchDestination("minibosscave")

  local startPos = vec2.add(center, rect.randomPoint(portalOffsetRegion))
  local spawnPos = vec2.add(center, cfg.spawnOffset)

  -- Strike lightning
  lightningController:add(startPos, spawnPos)
  animator.playSound("lightningStrikeBig")

  world.spawnProjectile(cfg.spawnerProjectileType, spawnPos, entity.id(), {1, 0}, false, {monsterType = cfg.monsterType,
      monsterParameters = cfg.monsterParameters})

  message.setHandler("v-monsterwavespawner-monsterspawned", function(_, _, id)
    minibossId = id
  end)

  util.wait(15)

  states.hazardStart()
end

function states.openToWorld()
  switchDestination("cryoflame")
  object.setInteractive(true)
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

function invokeHazard(hazardIdx, ...)
  local hazard = hazards[hazardIdx]
  hazardCooldowns[hazardIdx] = hazard.cooldown
  hazardCounter = hazardCounter + 1
  hazard.func(hazard.config, ...)
end

function switchDestination(destination)
  animator.setAnimationState("portal", "unlink")

  util.wait(portalCloseTime)

  currentDestination = destination
  animator.setGlobalTag("destination", destination)
  animator.setAnimationState("portal", "relink")

  util.wait(portalOpenTime)
end

--[[
  Returns true if at least one creature with a friendly damage team is inside the given region and false otherwise.

  region: A pair of Vec2F's
]]
function friendlyInsideRegion(region)
  local queried = world.entityQuery(region[1], region[2], {includedTypes = {"creature"}})

  for _, entityId in ipairs(queried) do
    local entityDamageTeam = world.entityDamageTeam(entityId)
    if entityDamageTeam.type == "friendly" then
      return true
    end
  end

  return false
end

function strikeLightning(endPos)
  object.setAnimationParameter("lightningSeed", math.floor(os.clock()))

  local startPos = vec2.add(center, rect.randomPoint(portalOffsetRegion))
  endPos = endPos or vec2.add(center, rect.randomPoint(lightningEndOffsetRegion))

  lightningController:add(startPos, endPos)
  animator.playSound("lightningStrike")
end