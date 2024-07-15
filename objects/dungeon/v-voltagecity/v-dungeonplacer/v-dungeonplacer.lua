require "/scripts/vec2.lua"
require "/scripts/rect.lua"

--[[
  A script for an object to place a dungeon. The type of dungeon to place is specified by dungeonType, and it uses the
  same dungeon ID as that of the block that the object occupies. The dungeon can be offset from its original position
  using dungeonOffset, and it always starts one block above the object's location (due to the way that 
  world.placeDungeon() works).
]]

local dungeonType
local ownPos
local startDungeonPos

function init()
  dungeonType = config.getParameter("dungeonType")
  ownPos = object.position()
  startDungeonPos = vec2.add(ownPos, config.getParameter("dungeonOffset", {0, 0}))
  
  message.setHandler("v-monsterwavespawner-reset", function()
    local dungeonId = world.dungeonId(ownPos)
    world.placeDungeon(dungeonType, startDungeonPos, dungeonId)
  end)
end

function update(dt)
end