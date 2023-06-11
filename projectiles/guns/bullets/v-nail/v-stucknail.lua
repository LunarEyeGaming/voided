function init()
  shockwaveDetectRadius = config.getParameter("shockwaveDetectRadius")
end

function update(dt)
  notifyShockwaves()
end

function notifyShockwaves()
  local nearbyMonsters = world.entityQuery(mcontroller.position(), shockwaveDetectRadius, {includedTypes = {"monster"}})
  
  for _, monsterId in ipairs(nearbyMonsters) do
    if world.monsterType(monsterId) == "v-shockwave" then
      world.sendEntityMessage(monsterId, "v-noticeNail", entity.id(), mcontroller.position())
    end
  end
end