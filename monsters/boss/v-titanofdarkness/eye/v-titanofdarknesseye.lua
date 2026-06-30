require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-behavior.lua"

require "/scripts/actions/boss/v-titanofdarkness.lua"

-- Parameters
local appearSpecs
local lookAroundSpecs
local foundTargetWaitTime

-- State variables
local currentAngle
local target
local state
local fovSearcher
local shouldDieVar

function init()
  appearSpecs = config.getParameter("appearSpecs")
  lookAroundSpecs = config.getParameter("lookAroundSpecs", {})
  foundTargetWaitTime = config.getParameter("foundTargetWaitTime")

  fovSearcher = vWorld.FovSearcher:new{
    fov = config.getParameter("fov", 45),
    exposureTime = config.getParameter("exposureTime"),
    sightRange = config.getParameter("sightRange"),
    queryArguments = {
      includedTypes = {"player"},
      withoutEntityId = entity.id()
    }
  }
  fovSearcher:init()
  state = FSM:new()

  currentAngle = -90 * math.pi / 180

  monster.setDamageBar("None")

  state:set(states.appear)
end

function update(dt)
  state:update(dt)
end

function shouldDie()
  return shouldDieVar
end

states = {}

function states.appear()
  animator.setLightActive("eyelightforward", true)
  animator.setLightActive("eyelight", false)
  v_titanAppear(appearSpecs)
  animator.setLightActive("eyelight", true)
  animator.setLightActive("eyelightforward", false)

  state:set(states.lookAround)
end

function states.lookAround()
  local lookAroundThread = coroutine.create(function()
    local thread = coroutine.create(function()
      v_titanLookAround(sb.jsonMerge(lookAroundSpecs, {currentAngle = currentAngle}))
    end)
    -- local status, result = v_titanLookAround(sb.jsonMerge(lookAroundSpecs, {currentAngle = currentAngle}))
    -- if status then
    --   ---@diagnostic disable-next-line: need-check-nil
    --   currentAngle = result.angle
    -- end
    local status1, status2OrError, result
    repeat
      status1, status2OrError, result = coroutine.resume(thread)
      if not status1 then
        error(status2OrError)
      end
      if result then
        currentAngle = result.angle
      end
      coroutine.yield()
    until coroutine.status(thread) == "dead"
  end)

  local rotateEyeThread = coroutine.create(function()
    while true do
      rotateEye{eyeAngle = currentAngle}

      coroutine.yield()
    end
  end)

  local findTargetThread = coroutine.create(function()
    while not target do
      target = fovSearcher:update(script.updateDt(), vec2.add(mcontroller.position(), animator.partPoint("body", "eyeCenter")), currentAngle)[1]

      coroutine.yield()
    end

    animator.setAnimationState("alert", "active")

    world.sendEntityMessage(config.getParameter("master"), "notify", {
      type = "v-titanofdarkness-foundTarget",
      targetId = target,
      targetPosition = world.entityPosition(target)
    })

    util.wait(foundTargetWaitTime, function()
      rotateEye{target = target}
    end)
  end)

  while util.parallel(lookAroundThread, rotateEyeThread, findTargetThread) do
    coroutine.yield()
  end

  state:set(states.disappear)
end

function states.disappear()
  animator.setLightActive("eyelightforward", true)
  animator.setLightActive("eyelight", false)

  -- Disappear
  v_titanAppear{
    appearTime = appearSpecs.appearTime,
    visionStartRotationRate = appearSpecs.visionEndRotationRate,
    visionEndRotationRate = appearSpecs.visionStartRotationRate,
    visionStartRadius = appearSpecs.visionEndRadius,
    visionEndRadius = appearSpecs.visionStartRadius,
    startAlpha = 255,
    endAlpha = 0
  }

  shouldDieVar = true
end

function rotateEye(args)
  local eyeCenter = animator.partPoint("body", "eyeCenter")
  local pupilLookRadius = animator.partProperty("pupil", "lookRadius")
  local targetPos

  if args.target then
    targetPos = world.entityPosition(args.target)
  end

  local eyeAngle
  if targetPos then
    local eyePos = vec2.add(mcontroller.position(), eyeCenter)
    eyeAngle = vec2.angle(world.distance(targetPos, eyePos))
  else
    eyeAngle = args.eyeAngle
  end

  animator.resetTransformationGroup("eye")
  animator.rotateTransformationGroup("eye", eyeAngle, eyeCenter)

  animator.resetTransformationGroup("pupil")
  animator.translateTransformationGroup("pupil", vec2.withAngle(eyeAngle, pupilLookRadius))
end