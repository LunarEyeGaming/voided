--[[
  Script that makes it so that a rift zone can spawn only if there are no other rift zones nearby.
]]

require "/scripts/rect.lua"

local oldInit = init or function() end

function init()
  local cfg = root.assetJson("/v-riftzones.config")
  cfg = sb.jsonMerge(cfg, config.getParameter("configOverrides", {}))
  scanRadius = cfg.defaultZoneRadius

  local queried = world.entityQuery(mcontroller.position(), scanRadius, {
    includedTypes = {"monster"}
  })

  for _, entityId in ipairs(queried) do
    if world.monsterType(entityId) == world.monsterType(entity.id()) then
      -- Disappear.
      monster.setUniqueId()
      monster.setDropPool(nil)
      g_shouldDieVar = true
      script.setUpdateDelta(0)  -- Suppress calls to update

      return
    end
  end

  oldInit()
end