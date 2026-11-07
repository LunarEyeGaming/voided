require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-vec2.lua"

local detectionRange
local doNotKillMonsters
local hatchNotifyRange
local stickTime

local nearbyMonsters
local consumedCount

local state
local shouldDieVar
local currentAngle

function init()
  detectionRange = config.getParameter("detectionRange")
  doNotKillMonsters = config.getParameter("doNotKillMonsters")
  hatchNotifyRange = 256
  stickTime = 0.5

  nearbyMonsters = {}
  consumedCount = 0

  currentAngle = 0
  state = FSM:new()
  state:set(states.wait)

  monster.setDeathSound("deathPuff")

  status.addEphemeralEffect("invulnerable", 2 ^ 32)
end

function update(dt)
  local ownDamageTeam = entity.damageTeam()

  local queried = world.entityQuery(mcontroller.position(), detectionRange, {includedTypes = {"monster"}, withoutEntityId = entity.id()})
  nearbyMonsters = {}
  for _, entityId in ipairs(queried) do
    local damageTeam = world.entityDamageTeam(entityId)
    if not hasSameMaster(entityId) then
      goto continue_query
    end

    if damageTeam.type ~= ownDamageTeam.type then
      goto continue_query
    end

    if world.lineCollision(mcontroller.position(), world.nearestTo(mcontroller.position(), world.entityPosition(entityId))) then
      goto continue_query
    end

    if contains(doNotKillMonsters, world.monsterType(entityId)) then
      goto continue_query
    end

    table.insert(nearbyMonsters, entityId)

    ::continue_query::
  end

  animator.setGlobalTag("glowCounter", consumedCount)

  state:update(dt)
end

function shouldDie()
  return shouldDieVar
end

states = {}

function states.wait()
  coroutine.yield()

  util.wait(3.0, function()
    if #nearbyMonsters == 0 then
      state:set(states.hatch)
    end
  end)

  state:set(states.consume)
end

function states.consume()
  animator.setAnimationState("body", "consumewindup")

  util.wait(1.0)

  animator.setAnimationState("body", "consume")

  if #nearbyMonsters == 0 then
    state:set(states.hatch)
    return
  end

  local targetEntity = nearbyMonsters[math.random(1, #nearbyMonsters)]

  local timer = 0

  animator.playSound("fire")

  local lastTargetPosition

  -- Stick tongue on entity.
  util.wait(2.5, function()
    if not world.entityExists(targetEntity) then
      clearTongue()
      retractCo(lastTargetPosition)
      state:set(states.wait)
    else
      timer = math.min(stickTime, timer + script.updateDt())
      lastTargetPosition = world.entityPosition(targetEntity)
      local posEnd = vVec2.lerp(timer / stickTime, mcontroller.position(), world.entityPosition(targetEntity))
      drawTongue(mcontroller.position(), posEnd)
      rotateBody(mcontroller.position(), posEnd)
    end
  end)

  -- Consume.
  if world.entityExists(targetEntity) then
    world.callScriptedEntity(targetEntity, "monster.setDropPool", nil)
    world.callScriptedEntity(targetEntity, "status.applySelfDamageRequest", {
      damage = 1000,
      damageSourceKind = "v-void",
      damageType = "IgnoresDef"
    })
    consumedCount = consumedCount + 1
  end

  retractCo(lastTargetPosition)

  if consumedCount >= 3 then
    state:set(states.hatch)
  else
    state:set(states.wait)
  end
end

function states.hatch()
  util.wait(2.0)

  animator.setAnimationState("body", "hatch")

  util.wait(1.5)

  if consumedCount < 1 then
    hatch("v-riftdevourer1")
  elseif consumedCount < 2 then
    hatch("v-riftdevourer2")
  else
    hatch("v-riftdevourer3")
  end

  world.spawnProjectile("v-riftdevourershell", mcontroller.position(), entity.id(), vec2.withAngle(currentAngle))

  state:set(states.die)
end

function states.die()
  shouldDieVar = true

  while true do
    coroutine.yield()
  end
end

---Returns `true` if the current entity has the same master as the given `entityId`, `false` otherwise--i.e., both this
---entity and `entityId` are clientsided or serversided.
function hasSameMaster(entityId)
  return (entity.id() < 0 and entityId < 0) or (entity.id() > 0 and entityId > 0)
end

function drawTongue(posStart, posEnd)
  local tongue = config.getParameter("tongue")

  tongue.startPosition = posStart
  tongue.endPosition = posEnd

  monster.setAnimationParameter("chains", {tongue})
end

function rotateBody(posStart, posEnd)
  local angle = vec2.angle(world.distance(posEnd, posStart))
  currentAngle = angle
  angle = angle - math.pi / 2
  animator.resetTransformationGroup("body")
  animator.rotateTransformationGroup("body", angle)
end

function retractCo(pos)
  if not pos then
    return
  end

  -- Retract tongue
  timer = 0

  util.wait(stickTime, function()
    timer = math.min(stickTime, timer + script.updateDt())
    local posEnd = vVec2.lerp(1 - timer / stickTime, mcontroller.position(), pos)
    drawTongue(mcontroller.position(), posEnd)
  end)

  clearTongue()

  animator.setAnimationState("body", "consumewinddown")
end

function hatch(monsterType)
  local monsterId = world.spawnMonster(monsterType, mcontroller.position(), {
    aggressive = true,
    level = monster.level()
  })
  if monsterId then
    local queried = world.entityQuery(mcontroller.position(), hatchNotifyRange, {
      includedTypes = {"object"}
    })
    for _, entityId in ipairs(queried) do
      world.sendEntityMessage(entityId, "v-monsterwavespawner-monsterspawned", monsterId)
    end
  end
end

function clearTongue()
  monster.setAnimationParameter("chains", {})
end