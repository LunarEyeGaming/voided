require "/scripts/vec2.lua"
require "/scripts/stagehandutil.lua"

function init()
  local params = config.getParameter("monsterParameters", {})

  params.level = params.level or world.threatLevel()

  message.setHandler("v-getTriggerInfo", function()
    return {
      messageType = config.getParameter("messageType"),
      messageArgs = config.getParameter("messageArgs", jarray()),
      queryArea = config.getParameter("broadcastArea", {-8, -8, 8, 8}),
      queryOptions = config.getParameter("targetOptions"),
      resetOnSubsequentWaves = config.getParameter("resetOnSubsequentWaves"),
      waveNumber = config.getParameter("waveNumber"),

      delay = config.getParameter("delay"),
      priority = config.getParameter("priority")
    }
  end)

  message.setHandler("v-die", stagehand.die)
end