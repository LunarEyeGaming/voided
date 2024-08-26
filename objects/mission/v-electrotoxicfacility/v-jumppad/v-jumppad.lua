require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local forceEffects

function init()
  updateActive()

  forceEffects = config.getParameter("forceEffects")
end

function update()
  -- For each status effect defined...
  for _, forceEffect in ipairs(forceEffects) do
    local forceEffectRegion = getRegionPoints(forceEffect.region)
    local queried = world.entityQuery(forceEffectRegion[1], forceEffectRegion[2], {includedTypes = {"creature"}})

    -- For each entity in the status effect region...
    for _, entityId in ipairs(queried) do
      local damageTeam = world.entityDamageTeam(entityId)

      -- If the entity exists and has a friendly damage team...
      if damageTeam and damageTeam.type == "friendly" then
        -- Add status effect
        world.sendEntityMessage(entityId, "applyStatusEffect", forceEffect.effect, forceEffect.duration)
      end
    end
  end
end

function onInputNodeChange(args)
  updateActive()
end

function onNodeConnectionChange(args)
  updateActive()
end

function updateActive()
  storage.active = not object.isInputNodeConnected(0) or object.getInputNodeLevel(0)
  animator.setAnimationState("padState", storage.active and "on" or "off")
end

--[[
  Converts a relative rectangle into a table of the bottom-left and top-right points (absolute) and returns the result.
]]
function getRegionPoints(rectangle)
  local absoluteRectangle = rect.translate(rectangle, object.position())

  return {rect.ll(absoluteRectangle), rect.ur(absoluteRectangle)}
end
