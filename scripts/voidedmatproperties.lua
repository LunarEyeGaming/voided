require "/scripts/util.lua"
require "/scripts/vec2.lua"

local oldInit = init
local oldUpdate = update

function init()
  oldInit()
  matProperties = {}
  matProperties.tickDelta = 4
  matProperties.tickTimer = matProperties.tickDelta
  matProperties.queryRadius = 15
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
  local ownPos = mcontroller.position()
  
  local i = 1
  while i <= #matProperties.matchedMods do
    local modPos = matProperties.matchedMods[i]
    if not matProperties.cuedRadioMessage then
      world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-voltite")
      matProperties.cuedRadioMessage = true
    end
    if math.random(1, 9) == 1 then
      world.spawnProjectile("v-voltitespark", modPos)
    end
    if not world.mod(modPos, "foreground") then
      world.spawnProjectile("v-voltiteexplosion", modPos, entity.id(), {0, 0}, false, {damageTeam = {type = "indiscriminate"}})
      table.remove(matProperties.matchedMods, i)
    else
      i = i + 1
    end
  end

  matProperties.matchedMods = {}

  for x = -matProperties.queryRadius, matProperties.queryRadius do
    for y = -matProperties.queryRadius, matProperties.queryRadius do
      local modPos = vec2.add({x, y}, ownPos)
      if world.mod(modPos, "foreground") == "v-voltite" then
        table.insert(matProperties.matchedMods, modPos)
      end
    end
  end
end