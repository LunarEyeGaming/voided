require "/scripts/vec2.lua"

local CHUNK_SIZE = 32

local chunkRange

function init()
  chunkRange = config.getParameter("chunkRange", 3)

  message.setHandler("v-chunkvisualizer-kill", stagehand.die)
end

function update(dt)
  local ownPos = stagehand.position()

  local players = world.entityQuery(ownPos, 128, {includedTypes = {"player"}})
  if players[1] and world.entityExists(players[1]) then
    stagehand.setPosition(world.entityPosition(players[1]))
  else
    stagehand.die()
  end

  for x = -chunkRange, chunkRange do
    for y = -chunkRange, chunkRange do
      local displayPos = vec2.add(ownPos, {x, y})
      local testPos = vec2.add(ownPos, {x * CHUNK_SIZE, y * CHUNK_SIZE})

      local isLoaded = world.regionActive({testPos[1], testPos[2], testPos[1] + 1, testPos[2] + 1})
      local isNotNull = not world.pointCollision(testPos, {"Null"})

      local color
      if isLoaded then
        color = "green"
      elseif isNotNull then
        color = "yellow"
      else
        color = "red"
      end
      world.debugPoint(displayPos, color)
    end
  end
end