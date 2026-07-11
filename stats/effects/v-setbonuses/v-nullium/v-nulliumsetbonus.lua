require "/scripts/status.lua"
require "/scripts/util.lua"

-- Parameters
local level
local projectileType
local projectileConfig

-- State variables
local listener
local spawnedMines

function init()
  -- Initialize parameters
  level = config.getParameter("level", 1)
  projectileType = config.getParameter("projectileType")
  projectileConfig = config.getParameter("projectileConfig", {})
  projectileConfig.power = (projectileConfig.power or 10) * root.evalFunction("weaponDamageLevelMultiplier", level)

  -- Initialize variables
  spawnedMines = {}
  listener = damageListener("inflictedDamage", function(notifications)
    for _, notification in ipairs(notifications) do
      if notification.hitType == "Kill" then
        if not spawnedMines[notification.targetEntityId] then
          local entityPos = world.entityPosition(notification.targetEntityId)
          if entityPos then
            projectileConfig.affectedEntityId = notification.targetEntityId
            world.spawnProjectile(projectileType, entityPos, entity.id(), {0, 0}, false, projectileConfig)
          end
          spawnedMines[notification.targetEntityId] = true
        end
      end
    end
  end)
end

function update(dt)
  listener:update()

  -- Clean up table
  for entityId, _ in pairs(spawnedMines) do
    if not world.entityExists(entityId) then
      spawnedMines[entityId] = nil
    end
  end
end

function onExpire()
end