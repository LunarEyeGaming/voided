require "/scripts/vec2.lua"
require "/scripts/rect.lua"

--[[
  A script for an object to fill in the void above the towers of the v-voltagecity dungeon with background walls and
  then disappear. The type of dungeon to place is specified by dungeonType, and it uses the same dungeon ID as that of
  the block that the object occupies. The dungeon can be offset from its original position using dungeonOffset, and it
  always starts one block above the object's location.
]]

local MAX_HEIGHT = 500

local dungeonType
local ownPos
local startDungeonPos

function init()
  dungeonType = config.getParameter("dungeonType")
  ownPos = object.position()
  startDungeonPos = vec2.add(ownPos, config.getParameter("dungeonOffset", {0, 0}))
end

function update(dt)
  if world.regionActive(rect.translate({-1, -1, 1, 1}, ownPos)) then
    local dungeonId = world.dungeonId(ownPos)
  
    local i = 1
    
    -- sb.logInfo("%s ?= %s", world.dungeonId(vec2.add(ownPos, {0, i})), dungeonId)
    
    -- Place dungeons (which should just be background tiles) until we reach the ceiling
    while i <= MAX_HEIGHT and world.dungeonId(vec2.add(ownPos, {0, i})) ~= dungeonId do
      -- sb.logInfo("%s ?= %s", world.dungeonId(vec2.add(ownPos, {0, i})), dungeonId)

      world.placeDungeon(dungeonType, vec2.add(startDungeonPos, {0, i}), dungeonId)

      i = i + 1
    end
    
    object.smash()
  end
end