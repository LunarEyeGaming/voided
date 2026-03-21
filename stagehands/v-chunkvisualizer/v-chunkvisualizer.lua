require "/scripts/vec2.lua"

local CHUNK_SIZE = 32

local chunkRange
local scale
local timer

local chunks

function init()
  chunkRange = config.getParameter("chunkRange", 3)
  scale = config.getParameter("scale", 1)

  message.setHandler("v-chunkvisualizer-kill", stagehand.die)

  timer = 0
end

function update(dt)
  timer = timer - 1
  if timer <= 0 then
    local ownPos = stagehand.position()

    local players = world.entityQuery(ownPos, 128, {includedTypes = {"player"}})
    if players[1] and world.entityExists(players[1]) then
      stagehand.setPosition(world.entityPosition(players[1]))
    else
      stagehand.die()
    end

    chunks = {}
    for x = -chunkRange, chunkRange do
      for y = -chunkRange, chunkRange do
        local displayPos = vec2.add(ownPos, {x * scale, y * scale})
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
        table.insert(chunks, {displayPos, color})
      end
    end

    timer = 6
  end

  for _, chunk in ipairs(chunks) do
    world.debugPoint(chunk[1], chunk[2])
  end
end