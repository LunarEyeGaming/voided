require "/scripts/status.lua"
require "/scripts/util.lua"

local level
local hitInvulnerabilityTime
local protectionProjectileType
local protectionIntangibleProjectileType
local protectionProjectileConfig
local projectileId
local maxHits
local shieldRechargeTime
local maxAbsorption

local hitCounter
local hitTimer
local state
local hasTakenDamage
local currentAbsorption
local prevAbsorption

function init()
  -- Initialize parameters
  level = config.getParameter("level", 1)
  hitInvulnerabilityTime = 1.0
  protectionProjectileType = "v-auroriteshield"
  protectionIntangibleProjectileType = "v-auroriteshieldintangible"
  protectionProjectileConfig = config.getParameter("protectionProjectileConfig", {})
  protectionProjectileConfig.power = (protectionProjectileConfig.power or 10) * root.evalFunction("weaponDamageLevelMultiplier", level)
  maxHits = 3
  shieldRechargeTime = 5
  maxAbsorption = 200

  -- Initialize variables
  hitCounter = 0
  hitTimer = hitInvulnerabilityTime
  prevAbsorption = 0
  state = FSM:new()
  animator.setAnimationState("shield", "inactive")
  state:set(states.inactive)
end

function update(dt)
  currentAbsorption = status.resource("damageAbsorption")

  hitTimer = hitTimer - dt

  hasTakenDamage = currentAbsorption < prevAbsorption

  animator.setGlobalTag("numHits", hitCounter)

  state:update(dt)

  prevAbsorption = status.resource("damageAbsorption")
end

function onExpire()
  killProjectile()
end

function killProjectile()
  if projectileId and world.entityExists(projectileId) then
    world.sendEntityMessage(projectileId, "kill")
  end
end

states = {}

function states.inactive()
  killProjectile()
  status.setResource("damageAbsorption", 0)

  while not mcontroller.crouching() do
    world.debugText("Inactive", mcontroller.position(), "green")
    coroutine.yield()
  end

  animator.setAnimationState("shield", "grow")
  animator.playSound("deploy")

  state:set(states.activeIntangible)
end

function states.activeIntangible()
  projectileId = world.spawnProjectile(protectionIntangibleProjectileType, mcontroller.position(), entity.id(), {1, 0}, false, protectionProjectileConfig)

  while mcontroller.crouching() and hitTimer > 0 do
    world.debugText("Active (intangible)", mcontroller.position(), "green")
    coroutine.yield()
  end

  killProjectile()

  if not mcontroller.crouching() then
    animator.setAnimationState("shield", "shrink")
    animator.playSound("retract")
    state:set(states.inactive)
  else
    state:set(states.active)
  end
end

function states.active()
  projectileId = world.spawnProjectile(protectionProjectileType, mcontroller.position(), entity.id(), {1, 0}, false, protectionProjectileConfig)
  status.setResource("damageAbsorption", maxAbsorption)

  while mcontroller.crouching() and world.entityExists(projectileId) and not hasTakenDamage do
    world.debugText("Active (%s hits)", hitCounter, mcontroller.position(), "green")
    coroutine.yield()
  end

  if not world.entityExists(projectileId) or hasTakenDamage then
    killProjectile()  -- In the event that hasTakenDamage is true

    hitTimer = hitInvulnerabilityTime
    hitCounter = hitCounter + 1
    if hitCounter >= maxHits then
      animator.burstParticleEmitter("break")
      animator.playSound("break")
      state:set(states.broken)
    else
      status.addEphemeralEffect("invulnerable", hitInvulnerabilityTime)
      animator.burstParticleEmitter("crack")
      animator.playSound("crack")
      state:set(states.activeIntangible)
    end
  else
    animator.setAnimationState("shield", "shrink")
    animator.playSound("retract")
    state:set(states.inactive)
  end
end

function states.broken()
  animator.setAnimationState("shield", "broken")
  animator.setAnimationState("orb", "invisible")

  status.setResource("damageAbsorption", 0)

  util.wait(shieldRechargeTime, function()
    world.debugText("Broken", mcontroller.position(), "green")
  end)

  hitCounter = 0

  animator.setAnimationState("orb", "idle")

  state:set(states.inactive)
end