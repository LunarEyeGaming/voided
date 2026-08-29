require "/scripts/vec2.lua"

require "/scripts/v-entity.lua"

local queryArg1
local queryArg2
local effectType
local effectDuration
local requireInput
local isActive

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  local effectRadius = config.getParameter("statusEffectConfig.effectRadius")
  if effectRadius then
    local effectOffset = config.getParameter("statusEffectConfig.effectCenter", {0, 0})

    queryArg1 = vec2.add(object.position(), effectOffset)
    queryArg2 = effectRadius
  else
    local effectRegion = config.getParameter("statusEffectConfig.effectRegion")
    if not effectRegion then
      error("Status effect object requires 'effectRadius' or 'effectRegion' to be defined.")
    end
    local effectRegionPoints = vEntity.getRegionPoints(effectRegion)
    queryArg1 = effectRegionPoints[1]
    queryArg2 = effectRegionPoints[2]
  end
  effectType = config.getParameter("statusEffectConfig.effectType")
  effectDuration = config.getParameter("statusEffectConfig.effectDuration")
  requireInput = config.getParameter("statusEffectConfig.requireInput")
  isActive = true
end

function update(dt)
  oldUpdate(dt)

  -- Optionally require input to activate.
  if not requireInput or object.getInputNodeLevel(0) then
    if isActive then
      local queried = world.entityQuery(queryArg1, queryArg2, {includedTypes = {"player"}})

      for _, playerId in ipairs(queried) do
        world.sendEntityMessage(playerId, "applyStatusEffect", effectType, effectDuration)
      end
    end
  end
end

function v_statusEffectObject_setActive(active)
  isActive = active
end