require "/scripts/util.lua"
require "/scripts/vec2.lua"

local tickDelta
local tickTimer
local queryRange
local matchedMods
local cuedRadioMessage

function init()
  -- for k, v in pairs(_ENV) do
    -- if type(v) == "table" then
      -- sb.logInfo("%s", k)
    -- end
  -- end
  tickDelta = 4
  tickTimer = tickDelta
  queryRange = 25  -- Matter manipulator can reach 17 blocks away at most, and there is a planned increase of up to 25 blocks.
  matchedMods = {}
  cuedRadioMessage = false
  
  message.setHandler("tileBroken", handleBrokenTile)
end

function update(dt)
  tickTimer = tickTimer - 1
  if tickTimer <= 0 then
    matUpdate(dt)
    tickTimer = tickDelta
  end
end

function matUpdate(dt)
  --local startTime = os.clock()

  local ownPos = mcontroller.position()
  
  for _, matMod in ipairs(matchedMods) do
    local modPos, modLayer = table.unpack(matMod)
    
    if not cuedRadioMessage then
      world.sendEntityMessage(player.id(), "queueRadioMessage", "v-voltite")
      cuedRadioMessage = true
    end
    if math.random(1, 9) == 1 then
      if modLayer == "background" then
        world.spawnProjectile("v-voltitespark2", modPos)
      else
        world.spawnProjectile("v-voltitespark", modPos)
      end
    end

    -- if not world.mod(modPos, modLayer) then
      -- world.spawnProjectile("v-voltiteexplosion", modPos, nil, {0, 0}, false, {damageTeam = {type = "environment"}})
    -- end
  end

  matchedMods = {}

  for x = -queryRange, queryRange do
    for y = -queryRange, queryRange do
      local modPos = vec2.add({x, y}, ownPos)
      if world.mod(modPos, "foreground") == "v-voltite" then
        table.insert(matchedMods, {modPos, "foreground"})
      end
      if world.mod(modPos, "background") == "v-voltite" then
        table.insert(matchedMods, {modPos, "background"})
      end
    end
  end
  
  --local endTime = os.clock()
  --sb.logInfo("Time elapsed: %s", endTime - startTime)
end

function handleBrokenTile(_, _, pos, layer)
  -- Exploits a loophole where the mod name does not get updated until after this function is called.
  if world.mod(pos, layer) == "v-voltite" then
    world.spawnProjectile("v-voltiteexplosion", pos, nil, {0, 0}, false, {damageTeam = {type = "environment"}})
  end
end