require "/scripts/messageutil.lua"
require "/scripts/vec2.lua"

require "/scripts/v-animator.lua"

local CURSOR_INRANGE = 0
local CURSOR_OUTOFRANGE = 1
local CURSOR_CANFIX = 2

local fixRange
local broadcastRange
local lensStatusUpdater
local lensFixedStatuses

local lightningController  ---@type LightningController

function init()
  fixRange = config.getParameter("fixRange")
  broadcastRange = config.getParameter("broadcastRange")
  lensStatusUpdater = PromiseKeeper.new()
  lensFixedStatuses = {}

  activeItem.setScriptedAnimationParameter("cursorImage", config.getParameter("cursorImage"))
  activeItem.setScriptedAnimationParameter("lensHighlightImage", config.getParameter("lensHighlightImage"))
  activeItem.setScriptedAnimationParameter("cursorState", CURSOR_INRANGE)

  lightningController = vAnimator.LightningController:new{
    cfg = config.getParameter("rejectLightningConfig"),
    startC = config.getParameter("rejectLightningStartColor"),
    endC = config.getParameter("rejectLightningEndColor"),
    startOC = config.getParameter("rejectLightningStartOutlineColor"),
    endOC = config.getParameter("rejectLightningEndOutlineColor"),
    dur = config.getParameter("rejectLightningFadeTime")
  }
end

function update(dt, fireMode)
  lightningController:update(dt)

  lensStatusUpdater:update()

  local aimPos = activeItem.ownerAimPosition()

  local solarLenses = findSolarLenses(aimPos)
  updateFixStatuses(solarLenses)

  local canFixLensVar = canFixAnyLens(aimPos)
  local state
  if canFixLensVar and #solarLenses > 0 then
    state = CURSOR_CANFIX
  elseif canFixLensVar then
    state = CURSOR_INRANGE
  else
    state = CURSOR_OUTOFRANGE
  end
  activeItem.setScriptedAnimationParameter("cursorState", state)

  if canFixLensVar then
    local positions = {}
    for i, lens in ipairs(solarLenses) do
      -- Add it only if it exists and it is not fixed (nonexistent or unprocessed entries are marked as nil).
      if lensFixedStatuses[lens] == false then
        positions[i] = world.entityPosition(lens)
      end
    end
    activeItem.setScriptedAnimationParameter("lensPositions", positions)
  else
    activeItem.setScriptedAnimationParameter("lensPositions", {})
  end

  if fireMode == "primary" and prevFireMode ~= fireMode then
    if #solarLenses > 0 and canFixAnyLens(aimPos) then
      animator.playSound("activate")
      animator.setAnimationState("item", "activate", true)

      for _, entityId in ipairs(solarLenses) do
        local promise = world.sendEntityMessage(entityId, "v-solarLens-fix")
        local entityPos = world.entityPosition(entityId)
        lensStatusUpdater:add(promise, function(result)
          if not result then
            local focalPos = vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("item", "focalPoint")))
            lightningController:addRandomSeed(entityPos, focalPos)
            animator.playSound("reject")
            animator.playSound("activateFail")
            animator.setAnimationState("item", "reject", true)
          end
        end)
      end
    else
      animator.playSound("activateFail")
      animator.setAnimationState("item", "activatefail", true)
    end
  end

  prevFireMode = fireMode
end

function canFixAnyLens(aimPos)
  return world.magnitude(aimPos, mcontroller.position()) <= fixRange
end

function findSolarLenses(aimPos)
  local queried = world.entityQuery(aimPos, broadcastRange, {includedTypes = {"object"}, order = "nearest"})
  local results = {}
  for _, entityId in ipairs(queried) do
    if world.getObjectParameter(entityId, "objectName") == "v-solarlens" then
      table.insert(results, entityId)
    end
  end

  return results
end

function updateFixStatuses(lenses)
  for _, lensId in ipairs(lenses) do
    if world.entityExists(lensId) then
      local promise = world.sendEntityMessage(lensId, "v-solarLens-isFixed")
      lensStatusUpdater:add(promise, function(result)
        lensFixedStatuses[lensId] = result
      end)
    else
      lensFixedStatuses[lensId] = nil
    end
  end
end

function uninit()

end

