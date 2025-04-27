require "/scripts/vec2.lua"

local level
local speedThreshold
local damageProjectileType
local damage
local projectileConfig

local fireballActive
local projectileId
local invulGroupId

function init()
  level = 8
  speedThreshold = 75
  damageProjectileType = "v-setbonusfireballdamage"
  damage = 30
  projectileConfig = {}
  projectileConfig.power = damage * root.evalFunction("weaponDamageLevelMultiplier", level)

  fireballActive = false
end

function update(dt)
  local velocity = mcontroller.velocity()
  local speed = vec2.mag(velocity)
  local angle = vec2.angle(velocity)

  if speed >= speedThreshold and not fireballActive then
    projectileId = world.spawnProjectile(damageProjectileType, mcontroller.position(), entity.id(),
    velocity, false, projectileConfig)
    invulGroupId = effect.addStatModifierGroup({{stat = "invulnerable", amount = 1}})
    animator.setAnimationState("fireball", "on")
    animator.playSound("activate")
    animator.playSound("active", -1)
    fireballActive = true
  end

  if speed < speedThreshold and fireballActive then
    world.sendEntityMessage(projectileId, "kill")
    effect.removeStatModifierGroup(invulGroupId)
    animator.setAnimationState("fireball", "off")
    animator.playSound("deactivate")
    animator.stopAllSounds("active")
    fireballActive = false
  end

  animator.resetTransformationGroup("fireball")
  animator.rotateTransformationGroup("fireball", angle)
end