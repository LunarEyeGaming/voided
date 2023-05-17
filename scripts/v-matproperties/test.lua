require "/scripts/v-matproperties/sector.lua"
require "/scripts/vec2.lua"

local SECTOR_SIZE = 32

function update(dt)
  test1()
  test2()
end

function test1()
  world.debugPoint(vec2.mul(getSector(mcontroller.position()), SECTOR_SIZE), "green")
end

function test2()
  local ownSector = getSector(mcontroller.position())
  world.debugPoint(getPosFromSector(ownSector, {15, 0}), "yellow")
  world.debugPoint(getPosFromSector(ownSector, {0, 15}), "yellow")
  world.debugPoint(getPosFromSector(ownSector, {15, 15}), "yellow")
  world.debugPoint(getPosFromSector(ownSector, {SECTOR_SIZE, SECTOR_SIZE}), "yellow")
end