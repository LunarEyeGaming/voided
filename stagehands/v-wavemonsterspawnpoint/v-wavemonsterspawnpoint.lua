require "/scripts/vec2.lua"

function init()
  local params = config.getParameter("monsterParameters", {})
  
  params.level = params.level or world.threatLevel()
  
  message.setHandler("v-getSpawnpointInfo", function()
    return {
      type = config.getParameter("monsterType"),
      position = vec2.add(stagehand.position(), config.getParameter("monsterOffset", {0, 0})),
      parameters = params,
      waveNumber = config.getParameter("waveNumber")
    }
  end)
  
  message.setHandler("v-die", stagehand.die)
end