local worldHeight
local poisonDepthRate
local minPoisonDepth

local deltaRemoverGroup

function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-depthpoison", 0.0)
  deltaRemoverGroup = effect.addStatModifierGroup({{stat = "v-depthPoisonDelta", baseMultiplier = 0.0}})
  worldHeight = world.size()[2]
  poisonDepthRate = config.getParameter("poisonDepthRate") -- Measured in units per block per second
  minPoisonDepth = config.getParameter("minPoisonDepth") -- The minimum depth that the player must be at in order for the poison to start
end

function update(dt)
  local depth = worldHeight - mcontroller.yPosition()
  local poisonRate = math.max(poisonDepthRate * (depth - minPoisonDepth), 0)
  status.modifyResource("v-depthPoison", poisonRate * dt)
end

-- Removed so that when assets are reloaded, the delta remover groups don't stack.
function uninit()
  effect.removeStatModifierGroup(deltaRemoverGroup)
end