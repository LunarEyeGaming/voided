local clearAttemptMade

function init()
  clearAttemptMade = false
end

function attemptClear()
  local killRadius = config.getParameter("killRadius")

  local queried = world.entityQuery(stagehand.position(), killRadius, {includedTypes = {"stagehand"}})

  for _, entityId in ipairs(queried) do
    if world.stagehandType(entityId) == "v-chunkvisualizer" then
      world.sendEntityMessage(entityId, "v-chunkvisualizer-kill")
    end
  end

  stagehand.die()
end

function update()
  if not clearAttemptMade then
    attemptClear()
    clearAttemptMade = true
  end
end