require "/scripts/util.lua"
require "/scripts/stagehandutil.lua"

local statusEffects

function init()
  statusEffects = config.getParameter("statusEffects")
end

function update(dt)
  local players = broadcastAreaQuery({ includedTypes = {"player"} })
  for _, playerId in pairs(players) do
    for _, statusEffect in ipairs(statusEffects) do
      if type(statusEffect) == "string" then
        world.sendEntityMessage(playerId, "applyStatusEffect", statusEffect)
      elseif type(statusEffect) == "table" then
        world.sendEntityMessage(playerId, "applyStatusEffect", statusEffect.effect, statusEffect.duration)
      else
        error("Expected string or table, got " .. type(statusEffect))
      end
    end
  end
end