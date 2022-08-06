require "/scripts/util.lua"
require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()
  matProperties = {}
  matProperties.tickDelta = 4
  matProperties.tickTimer = matProperties.tickDelta
  matProperties.queryRange = 15
  matProperties.matchedMods = {}
  matProperties.cuedRadioMessage = false
end

function update(dt)
  oldUpdate(dt)
  matProperties.tickTimer = matProperties.tickTimer - 1
  if matProperties.tickTimer <= 0 then
    matUpdate(dt)
    matProperties.tickTimer = matProperties.tickDelta
  end
end

function matUpdate(dt)
  --local startTime = os.clock()

  local ownPos = mcontroller.position()
  
  for _, matMod in ipairs(matProperties.matchedMods) do
    local modPos, modLayer = table.unpack(matMod)
    
    if not matProperties.cuedRadioMessage then
      world.sendEntityMessage(player.id(), "queueRadioMessage", "v-voltite")
      matProperties.cuedRadioMessage = true
    end
    if math.random(1, 9) == 1 then
      world.spawnProjectile("v-voltitespark", modPos)
    end

    if not world.mod(modPos, modLayer) then
      world.spawnProjectile("v-voltiteexplosion", modPos, player.id(), {0, 0}, false, {damageTeam = {type = "indiscriminate"}})
    end
  end

  matProperties.matchedMods = {}

  for x = -matProperties.queryRange, matProperties.queryRange do
    for y = -matProperties.queryRange, matProperties.queryRange do
      local modPos = vec2.add({x, y}, ownPos)
      if world.mod(modPos, "foreground") == "v-voltite" then
        table.insert(matProperties.matchedMods, {modPos, "foreground"})
      end
      if world.mod(modPos, "background") == "v-voltite" then
        table.insert(matProperties.matchedMods, {modPos, "background"})
      end
    end
  end
  
  --local endTime = os.clock()
  --sb.logInfo("Time elapsed: %s", startTime - endTime)
end