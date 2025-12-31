require "/scripts/util.lua"

-- A hacky script to manually zero out the base value for v-depthPoisonDelta in worlds that give v-depthpoison. This
-- assumes that the status effect was removed from the player.

local hasDepthPoison
local deltaRemoverGroup

function init()
  hasDepthPoison = contains(world.environmentStatusEffects({0, 0}), "v-depthpoison")
  if hasDepthPoison then
    deltaRemoverGroup = effect.addStatModifierGroup({{stat = "v-depthPoisonDelta", baseMultiplier = 0.0}})
  end
end

-- Removed so that when assets are reloaded, the delta remover groups don't stack.
function uninit()
  if hasDepthPoison then
    effect.removeStatModifierGroup(deltaRemoverGroup)
  end
end