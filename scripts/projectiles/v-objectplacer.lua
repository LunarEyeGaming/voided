local objectToPlace
local objectOffset
local objectParameters
local objectDirection

function init()
  objectToPlace = config.getParameter("objectToPlace")
  objectOffset = config.getParameter("objectOffset", {0, 0})
  objectParameters = config.getParameter("objectParameters", {})
  objectDirection = config.getParameter("objectDirection", 1)
end

function destroy()
  local ownPos = mcontroller.position()
  local objectPosition = {
    math.floor(ownPos[1]) + objectOffset[1],
    math.floor(ownPos[2]) + objectOffset[2]
  }
  world.placeObject(objectToPlace, objectPosition, objectDirection, objectParameters)
end