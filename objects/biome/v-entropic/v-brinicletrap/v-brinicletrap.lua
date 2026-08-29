require "/scripts/vec2.lua"

-- A combination of projectiletrap.lua and proximitysensor.lua

local projectile
local projectileConfig
local projectilePosition
local projectileDirection
local inaccuracy

local detectEntityTypes
local detectBoundMode
local detectDamageTeam
local detectArea
local triggerTimer

local isActive

function init()
  object.setSoundEffectEnabled(isActive)

  projectile = config.getParameter("projectile")
  projectileConfig = config.getParameter("projectileConfig", {})
  projectilePosition = config.getParameter("projectilePosition", {0, 0})
  projectileDirection = config.getParameter("projectileDirection", {1, 0})
  inaccuracy = config.getParameter("inaccuracy", 0)

  projectilePosition = object.toAbsolutePosition(projectilePosition)

  detectEntityTypes = config.getParameter("detectEntityTypes")
  detectBoundMode = config.getParameter("detectBoundMode", "CollisionArea")
  detectDamageTeam = config.getParameter("detectDamageTeam")
  local detectArea_ = config.getParameter("detectArea")
  local pos = object.position()
  if type(detectArea_[2]) == "number" then
    --center and radius
    detectArea = {
      {pos[1] + detectArea_[1][1], pos[2] + detectArea_[1][2]},
      detectArea_[2]
    }
  elseif type(detectArea_[2]) == "table" and #detectArea_[2] == 2 then
    --rect corner1 and corner2
    detectArea = {
      {pos[1] + detectArea_[1][1], pos[2] + detectArea_[1][2]},
      {pos[1] + detectArea_[2][1], pos[2] + detectArea_[2][2]}
    }
  end

  untrigger()

  triggerTimer = 0
end

function update(dt)
  if triggerTimer > 0 then
    triggerTimer = triggerTimer - dt
  elseif triggerTimer <= 0 then
    local entityIds = world.entityQuery(detectArea[1], detectArea[2], {
        withoutEntityId = entity.id(),
        includedTypes = detectEntityTypes,
        boundMode = detectBoundMode
      })

    if detectDamageTeam then
      entityIds = util.filter(entityIds, function (entityId)
          local entityDamageTeam = world.entityDamageTeam(entityId)
          if detectDamageTeam.type and detectDamageTeam.type ~= entityDamageTeam.type then
            return false
          end
          if detectDamageTeam.team and detectDamageTeam.team ~= entityDamageTeam.team then
            return false
          end
          return true
        end)
    end

    if #entityIds > 0 then
      trigger()
    else
      untrigger()
    end
  end
end

function trigger()
  animator.setAnimationState("trapState", "on")
  object.setLightColor(config.getParameter("activeLightColor", {0, 0, 0, 0}))
  object.setSoundEffectEnabled(true)
  animator.playSound("on")
  triggerTimer = config.getParameter("detectDuration")
  shoot()
end

function untrigger()
  animator.setAnimationState("trapState", "off")
  object.setLightColor(config.getParameter("inactiveLightColor", {0, 0, 0, 0}))
  object.setSoundEffectEnabled(false)
  animator.playSound("off")
end

function shoot()
  animator.playSound("shoot")
  local projectileDirection_ = vec2.rotate(projectileDirection, sb.nrand(inaccuracy, 0))
  world.spawnProjectile(projectile, projectilePosition, entity.id(), projectileDirection_, false, projectileConfig)
end
