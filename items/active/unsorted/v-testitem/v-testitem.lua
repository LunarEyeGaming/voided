require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-ministarutil.lua"

local id
local prevFireMode

function init()
  id = 0
end

function update(dt, fireMode)
  if fireMode ~= prevFireMode then
    if fireMode == "primary" then
      openUi()
    -- elseif fireMode == "alt" then
    --   clearCollisions()
    end
  end
  prevFireMode = fireMode
end

function openUi()
  local uiConfig = root.assetJson("/interface/scripted/v-ministarrenderconfig/v-ministarrenderconfig.config")
  player.interact("ScriptPane", uiConfig, entity.id())
end

-- function addCollision()
--   local aimPos = activeItem.ownerAimPosition()
--   local aimPosI = {
--     math.floor(aimPos[1]),
--     math.floor(aimPos[2])
--   }

--   local heightMapSetRange = {-5, 5}

--   local startX = aimPosI[1] + heightMapSetRange[1]
--   local endX = aimPosI[1] + heightMapSetRange[2]

--   local heightMap = vMinistar.XMap:new(startX)

--   for x = startX, endX do
--     heightMap:set(math.floor(x), aimPosI[2])
--   end

--   world.sendEntityMessage(entity.id(), "v-ministarheat-setEntityCollision", id, heightMap)
--   id = id + 1
-- end

-- function clearCollisions()
--   for i = 0, id do
--     world.sendEntityMessage(entity.id(), "v-ministarheat-setEntityCollision", i)
--   end
--   id = 0
-- end

-- function addSolarFlare()
--   local solarFlares = world.getProperty("v-solarFlares") or {}

--   table.insert(solarFlares, {
--     x = activeItem.ownerAimPosition()[1],
--     startTime = world.time(),
--     duration = 10,
--     potency = 0.5,
--     spread = 300
--   })

--   world.setProperty("v-solarFlares", solarFlares)
-- end

-- function clearSolarFlares()
--   world.setProperty("v-solarFlares", jarray())
-- end