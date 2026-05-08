-- Periodic actions just...doesn't allow for liquid placement at all. This is the workaround.

require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local liquidId
local liquidQuantity
local liquidDestroyRadius
local liquidPlaceRadius
local destroyLiquids
local destroyAllLiquids
local liquidPlacementInterval

local timer

function init()
  oldInit()

  liquidId = root.liquidId(config.getParameter("liquidPlacer.name"))
  liquidQuantity = config.getParameter("liquidPlacer.quantity")
  liquidDestroyRadius = config.getParameter("liquidPlacer.destroyRadius", 0)
  liquidPlaceRadius = config.getParameter("liquidPlacer.placeRadius", 0)
  -- local destroyLiquidsParam = config.getParameter("destroyLiquids", "all")
  -- if destroyLiquidsParam == "all" then
  --   destroyAllLiquids = true
  -- else
  --   destroyLiquids = {}
  --   for _, liquidName in ipairs(destroyLiquidsParam) do
  --     destroyLiquids[root.liquidId(liquidName)] = true
  --   end
  -- end
  liquidPlacementInterval = config.getParameter("liquidPlacer.interval")


  timer = liquidPlacementInterval
end

function update(dt)
  oldUpdate(dt)

  timer = timer - dt

  if timer <= 0 then
    local ownPos = mcontroller.position()
    for x = -liquidDestroyRadius, liquidDestroyRadius do
      for y = -liquidDestroyRadius, liquidDestroyRadius do
        local offset = {x, y}
        if vec2.mag(offset) <= liquidDestroyRadius then
          local pos = vec2.add(ownPos, offset)
          if shouldDestroyLiquid(pos) then
            world.destroyLiquid(pos)
          end
        end
      end
    end
    if liquidPlaceRadius > 0 then
      for x = -liquidPlaceRadius, liquidPlaceRadius do
        for y = -liquidPlaceRadius, liquidPlaceRadius do
          local offset = {x, y}
          if vec2.mag(offset) <= liquidPlaceRadius then
            local pos = vec2.add(ownPos, offset)
            world.spawnLiquid(pos, liquidId, liquidQuantity)
          end
        end
      end
    else
      world.spawnLiquid(ownPos, liquidId, liquidQuantity)
    end

    timer = liquidPlacementInterval
  end
end

function shouldDestroyLiquid(pos)
  -- if destroyAllLiquids then
  --   return true
  -- end

  local liquid = world.liquidAt(pos)
  -- return liquid and destroyLiquids[liquid[1]]
  return liquid and liquid[1] ~= liquidId
end