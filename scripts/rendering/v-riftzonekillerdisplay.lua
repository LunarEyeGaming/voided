require "/scripts/v-entity.lua"
require "/scripts/poly.lua"

local displayColor
local queryRange
-- local durations
local cachedItemConfig

local oldInit = init or function() end
local oldUpdate = update or function() end
-- local oldUninit = uninit or function() end

function init()
  oldInit()

  -- durations = {}
  cachedItemConfig = vUtil.cacheFunctionGen(root.itemConfig)

  displayColor = {79, 20, 92, 63}
  queryRange = 128
end

function update(dt)
  localAnimator.clearDrawables()

  oldUpdate(dt)
  -- local startTime = os.clock()

  local heldItem = player.primaryHandItem()
  if heldItem then
    local itemConfig = cachedItemConfig(heldItem.name)
    if itemConfig.config["v-isRiftZoneKiller"] or itemConfig.parameters["v-isRiftZoneKiller"] then
      local queried = world.entityQuery(entity.position(), queryRange, {
        includedTypes = {"object"}
      })

      for _, entityId in ipairs(queried) do
        if world.getObjectParameter(entityId, "v-isRiftZoneKiller") then
          local entityPos = world.entityPosition(entityId)
          local displaySize = world.getObjectParameter(entityId, "killRange")
          v_riftZoneKillerDisplay_drawBox(entityPos, displaySize, dt)
        end
      end

      if world.entityAimPosition then
        local aimPos = vec2.floor(world.entityAimPosition(entity.id()))
        local displaySize = itemConfig.parameters.killRange or itemConfig.config.killRange

        v_riftZoneKillerDisplay_drawBox(aimPos, displaySize, dt)
      end
    end
  end

  -- local duration = os.clock() - startTime
  -- table.insert(durations, duration)
end

function v_riftZoneKillerDisplay_drawBox(center, size, dt)
  local predictedPos = vEntity.predictPosition(dt)

  local centerRelative = world.distance(center, predictedPos)
  local displayPoly = {{-size, -size}, {size, -size}, {size, size}, {-size, size}}
  localAnimator.addDrawable({
    poly = displayPoly,
    position = centerRelative,
    color = displayColor
  }, "ForegroundOverlay+10")
end

-- function uninit()
--   oldUninit()

--   if durations then
--     local sum = 0
--     local max = -math.huge
--     local min = math.huge
--     for _, duration in ipairs(durations) do
--       sum = sum + duration
--       max = math.max(max, duration)
--       min = math.min(min, duration)
--     end

--     sb.logInfo("Max duration: %s ms, average duration: %s ms, min duration: %s", max * 1000, sum / #durations * 1000, min * 1000)
--   end
-- end