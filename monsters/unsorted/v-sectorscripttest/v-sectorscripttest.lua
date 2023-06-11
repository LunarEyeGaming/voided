require "/scripts/v-matproperties/sector.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"

--[[
  Overengineered-as-heck script to test the getSectorsInRegion function. The tests are configured in the monstertype
  file. testRegions are the regions to test. expSectorSets are the corresponding expected sectors. The region is drawn
  in yellow. The sectors returned from getSectorsInRegion are highlighted in blue. The expected sectors (drawn below the
  returned sectors) are highlighted in red.
]]

local testNumber
local testRegions
local expSectorSets
local expSectors
local numTests
local shouldDieVar
local ownPos

local currentRegion
local currentSectors

function init()
  -- Lock to the current sector.
  mcontroller.setPosition(getPosFromSector(getSector(mcontroller.position()), {0, 0}))

  ownPos = mcontroller.position()

  -- Add absolute test regions
  testRegions = {}

  local relativeTestRegions = config.getParameter("testRegions")
  local relativeExpSectorSets = config.getParameter("expSectorSets")

  -- Check that the number of tests matches the number of expected sectors
  if #relativeTestRegions ~= #relativeExpSectorSets then
    error("Number of tests does not match number of expected sectors")
  end

  for _, testRegion in ipairs(relativeTestRegions) do
    table.insert(testRegions, rect.translate(testRegion, ownPos))
  end

  local ownSector = getSector(ownPos)

  -- Add absolute sectors
  expSectorSets = {}

  for _, relativeExpSectors in ipairs(relativeExpSectorSets) do
    local expSectors = {}

    for _, sector in ipairs(relativeExpSectors) do
      table.insert(expSectors, vec2.add(sector, ownSector))
    end

    table.insert(expSectorSets, expSectors)
  end

  numTests = #testRegions
  shouldDieVar = false
  self.debug = true
  testNumber = 1

  monster.setDamageBar("None")

  script.setUpdateDelta(1)

  updateTestData()

  message.setHandler("changeTest", function()
    rotateTest()
    updateTestData()
  end)

  message.setHandler("despawn", function()
    shouldDieVar = true
  end)
end

function update(dt)
  world.debugText("Test Number: %s\nNumber of Expected Sectors: %s\nNumber of Returned Sectors: %s", testNumber,
      #expSectors, #currentSectors, ownPos, "green")

  for _, sector in ipairs(expSectors) do
    drawSector(sector, "red")
  end

  for _, sector in ipairs(currentSectors) do
    drawSector(sector, "blue")
  end

  util.debugRect(currentRegion, "yellow")
end

--[[
  Increases the testNumber variable by 1. If testNumber exceeds the number of tests, wraps the number back around to 1.
]]
function rotateTest()
  testNumber = testNumber + 1
  if testNumber > numTests then
    testNumber = 1
  end
end

--[[
  Updates the test data.
]]
function updateTestData()
  currentRegion = testRegions[testNumber]
  currentSectors = getSectorsInRegion(currentRegion)
  expSectors = expSectorSets[testNumber]
end

--[[
  Draws a sector. Only visible when debug mode is on.

  param sector: the sector to draw
  param color: the color to draw the sector in
]]
function drawSector(sector, color)
  local pos1 = getPosFromSector(sector, {0, 0})
  local pos2 = getPosFromSector(sector, {32, 32})

  util.debugRect({pos1[1], pos1[2], pos2[1], pos2[2]}, color)
end

function shouldDie()
  return shouldDieVar
end