require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-util.lua"
require "/scripts/v-world.lua"

local SMALL_RECT = {-1, -1, 1, 1}

local meltingLiquids
local meltCheckFunc
local meltCheckRegion

local postInitCalled

function init()
  meltingLiquids = {218, 2, }
  meltCheckFunc = vUtil.materialConfigGen(function(matConfigAndPath)
    local matConfig = matConfigAndPath.config
    return matConfig
  end)
  meltCheckRegion = {-200, -200, 200, 200}

  postInitCalled = false
end

function postInit()
  local stagehandId = world.loadUniqueEntity("v-icemelter-stagehand")

  -- Set unique ID if no stagehand with that unique ID exists. Otherwise (if it is not the stagehand with the unique
  -- ID), die.
  if stagehandId == 0 then
    stagehand.setUniqueId("v-icemelter-stagehand")
  elseif stagehandId ~= entity.id() then
    stagehand.die()
  end
end

function update(dt)
  if not postInitCalled then
    postInit()
    postInitCalled = true
    return
  end

  local players = world.players()
  for _, playerId in ipairs(players) do
    local playerPos = world.entityPosition(playerId)

    if playerPos then
      for _ = 1, 100 do
        local meltCheckPos = rect.randomPoint(rect.translate(meltCheckRegion, playerPos))
        local material = world.material(meltCheckPos, "foreground")
        if material then
          local matConfig = meltCheckFunc(material)
          if matConfig and matConfig.footstepSound == "/sfx/blocks/footstep_ice.ogg" then
            if adjacentToMeltingLiquid(meltCheckPos) then
              world.damageTiles({meltCheckPos}, "foreground", meltCheckPos, "blockish", 2 ^ 32, 0)
            end
          end
        end
      end
    end
  end
end

function adjacentToMeltingLiquid(pos)
  for _, offset in ipairs(vWorld.ADJACENT_TILES) do
    local checkPos = vec2.add(pos, offset)
    local liquid = world.liquidAt(checkPos)
    if liquid then
      local liquidId, liquidAmount = liquid[1], liquid[2]
      if contains(meltingLiquids, liquidId) and math.random() < liquidAmount then
        return true
      end
    end
  end

  return false
end