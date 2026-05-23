require "/scripts/util.lua"
require "/scripts/vec2.lua"

local detectEntityTypes
local detectBoundMode
local detectDamageTeam
local detectArea
local detectVelocityComparison  ---@type fun(velocity: Vec2F): boolean Function for filtering by velocity

local triggerTimer

---@alias VSpeedSensor.ThresholdMode "lt" | "lte" | "gt" | "gte" | "range"

---@class VSpeedSensor.MagThreshold
---@field valueToCompare "mag"
---@field mode VSpeedSensor.ThresholdMode
---@field value number | Vec2F

---@class VSpeedSensor.XYThreshold
---@field valueToCompare "xy"
---@field xMode VSpeedSensor.ThresholdMode?
---@field xValue (number | Vec2F)?
---@field yMode VSpeedSensor.ThresholdMode?
---@field yValue (number | Vec2F)?

local comparisonFunctions = {
  lt = function(lv, rv)
    return lv < rv
  end,

  lte = function(lv, rv)
    return lv <= rv
  end,

  gt = function(lv, rv)
    return lv > rv
  end,

  gte = function(lv, rv)
    return lv >= rv
  end,

  range = function(lv, rv)
    return rv[1] <= lv and lv <= rv[2]
  end
}

local comparisonStrings = {
  lt = function(lv, rv)
    return string.format("%s < %s", lv, rv)
  end,
  lte = function(lv, rv)
    return string.format("%s <= %s", lv, rv)
  end,
  gt = function(lv, rv)
    return string.format("%s > %s", lv, rv)
  end,
  gte = function(lv, rv)
    return string.format("%s >= %s", lv, rv)
  end,
  range = function(lv, rv)
    return string.format("%s < %s < %s", rv[1], lv, rv[2])
  end
}

function init()
  detectEntityTypes = config.getParameter("detectEntityTypes")
  detectBoundMode = config.getParameter("detectBoundMode", "CollisionArea")
  detectDamageTeam = config.getParameter("detectDamageTeam")
  detectVelocityComparison = makeComparisonFunction("detectVelocityComparison")
  --[[
    valueToCompare: xy
      * xMode: lt | lte | gt | gte | range
      * yMode: lt | lte | gt | gte | range
      * xValue: number (if not range)
      * xValue: Vec2F (if range)
      * yValue: number (if not range)
      * yValue: Vec2F (if range)
    valueToCompare: mag
      * mode: lt | lte | gt | gte | range
      * value: number (if not range)
      * value: Vec2F (if range)
  ]]

  local detectAreaParam = config.getParameter("detectArea")
  local pos = object.position()
  if type(detectAreaParam[2]) == "number" then
    --center and radius
    detectArea = {
      {pos[1] + detectAreaParam[1][1], pos[2] + detectAreaParam[1][2]},
      detectAreaParam[2]
    }
  elseif type(detectAreaParam[2]) == "table" and #detectAreaParam[2] == 2 then
    --rect corner1 and corner2
    detectArea = {
      {pos[1] + detectAreaParam[1][1], pos[2] + detectAreaParam[1][2]},
      {pos[1] + detectAreaParam[2][1], pos[2] + detectAreaParam[2][2]}
    }
  end

  object.setInteractive(config.getParameter("interactive", true))
  object.setAllOutputNodes(false)
  animator.setAnimationState("switchState", "off")
  triggerTimer = 0
end

function trigger()
  object.setAllOutputNodes(true)
  animator.setAnimationState("switchState", "on")
  object.setSoundEffectEnabled(true)
  triggerTimer = config.getParameter("detectDuration")
end

function onInteraction(args)
  trigger()
end

function update(dt)
  -- world.debugText(debugString, object.position(), "green")
  if triggerTimer > 0 then
    triggerTimer = triggerTimer - dt
  elseif triggerTimer <= 0 then
    local entityIds = world.entityQuery(detectArea[1], detectArea[2], {
        withoutEntityId = entity.id(),
        includedTypes = detectEntityTypes,
        boundMode = detectBoundMode
      })

    if detectDamageTeam then
      entityIds = util.filter(entityIds, function (entityId)
          local entityDamageTeam = world.entityDamageTeam(entityId)
          if detectDamageTeam.type and detectDamageTeam.type ~= entityDamageTeam.type then
            return false
          end
          if detectDamageTeam.team and detectDamageTeam.team ~= entityDamageTeam.team then
            return false
          end
          return true
        end)
    end

    -- Filter out entities below the speed threshold
    entityIds = util.filter(entityIds, function(entityId)
      local velocity = world.entityVelocity(entityId)
      if not velocity then
        return false
      end

      return detectVelocityComparison(velocity)
    end)

    if #entityIds > 0 then
      trigger()
    else
      object.setAllOutputNodes(false)
      object.setSoundEffectEnabled(false)
      animator.setAnimationState("switchState", "off")
    end
  end
end

function makeComparisonFunction(compName)
  local comp = config.getParameter(compName)  ---@type VSpeedSensor.XYThreshold | VSpeedSensor.MagThreshold

  -- sb.logInfo("%s", comp)

  if type(comp) ~= "table" then
    error(string.format("Parameter '%s' must be an object. Actual Lua type: %s", compName, type(comp)))
  end

  if comp.valueToCompare == "mag" then
    local value = comp.value
    if not value then
      error(string.format("'%s.%s' not defined", compName, "value"))
    end

    local func = comparisonFunctions[comp.mode or "gte"]

    -- local vString = comparisonStrings[comp.mode or "gte"]("vec2.mag(velocity)", value)
    -- debugString = string.format("%s", vString)

    return function(velocity)
      return func(vec2.mag(velocity), value)
    end
  elseif comp.valueToCompare == "xy" then
    -- xMode or yMode (or both) can be defined
    if comp.xValue and comp.yValue then
      local xValue = comp.xValue
      local xFunc = comparisonFunctions[comp.xMode or "gte"]
      local yValue = comp.yValue
      local yFunc = comparisonFunctions[comp.yMode or "gte"]

      -- local xString = comparisonStrings[comp.xMode or "gte"]("velocity[1]", xValue)
      -- local yString = comparisonStrings[comp.yMode or "gte"]("velocity[2]", yValue)
      -- debugString = string.format("%s or %s", xString, yString)

      return function(velocity)
        return xFunc(velocity[1], xValue) or yFunc(velocity[2], yValue)
      end
    elseif comp.xValue then
      local xValue = comp.xValue
      local xFunc = comparisonFunctions[comp.xMode or "gte"]

      -- local xString = comparisonStrings[comp.xMode or "gte"]("velocity[1]", xValue)
      -- debugString = string.format("%s", xString)

      return function(velocity)
        return xFunc(velocity[1], xValue)
      end
    elseif comp.yValue then
      local yValue = comp.yValue
      local yFunc = comparisonFunctions[comp.yMode or "gte"]

      -- local yString = comparisonStrings[comp.yMode or "gte"]("velocity[2]", yValue)
      -- debugString = string.format("%s", yString)

      return function(velocity)
        return yFunc(velocity[2], yValue)
      end
    else
      error(string.format("xValue and/or yValue must be defined in '%s'", compName))
    end
  else
    error(string.format("Unknown value type to compare in '%s': %s.", compName, comp.valueToCompare))
  end
end
