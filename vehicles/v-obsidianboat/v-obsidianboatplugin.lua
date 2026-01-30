require "/vehicles/boat/boat.lua"

require "/scripts/v-ministarutil.lua"
require "/scripts/v-time.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local heightMapSetRange
local minDepth

function init()
  oldInit()

  heightMapSetRange = config.getParameter("heightMapSetRange")
  minDepth = world.oceanLevel(mcontroller.position()  --[[@as Vec2I]])

  vTime.addInterval(0.1, function()
    local ownPos = mcontroller.position()
    local ownPosI = {
      math.floor(ownPos[1]),
      math.floor(ownPos[2])
    }

    if ownPosI[2] >= minDepth then
      local startX = ownPosI[1] + heightMapSetRange[1]
      local endX = ownPosI[1] + heightMapSetRange[2]

      local heightMap = vMinistar.XMap:new()

      for x = startX, endX do
        heightMap:set(math.floor(x), ownPosI[2])
      end

      registerEntityCollision(heightMap)
    end
  end)
end

function update()
  oldUpdate()

  vTime.update(script.updateDt())
end

function uninit()
  deregisterEntityCollision()
end

function registerEntityCollision(heightMap)
  for _, entityId in ipairs(world.entityQuery(mcontroller.position(), 250, {includedTypes = {"stagehand"}})) do
    world.sendEntityMessage(entityId, "v-ministarheat-setEntityCollision", entity.id(), heightMap)
  end
end

function deregisterEntityCollision()
  for _, entityId in ipairs(world.entityQuery(mcontroller.position(), 250, {includedTypes = {"stagehand"}})) do
    world.sendEntityMessage(entityId, "v-ministarheat-setEntityCollision", entity.id(), nil)
  end
end