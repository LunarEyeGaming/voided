require "/scripts/vec2.lua"
require "/scripts/v-vec2.lua"

local emissionInterval
local emissionFuzzAngle
local emissionDistance

local emissionTimer

local oldInit = init or function() end
local oldUpdate = update or function() end

local cfg  ---@type fun(key: string): any

function init()
  oldInit()

  -- sb.logInfo("Initializing animation script")

  cfg = animationConfig.animationParameter
  emissionTimer = 0

  -- sb.logInfo("Finished initializing animation script")
end

function update()
  oldUpdate()

  local dt = script.updateDt()
  if cfg("shouldEmitSuction") then
    emissionTimer = emissionTimer - dt

    if emissionTimer <= 0 then
      emissionInterval = cfg("emissionInterval")
      emissionFuzzAngle = cfg("emissionFuzzAngle") * math.pi / 180
      emissionDistance = cfg("emissionDistance")

      local position = cfg("firePosition")
      local aimAngle = cfg("fireAngle")
      local particle = cfg("suctionParticle")

      local angle = vVec2.randomAngle(aimAngle, emissionFuzzAngle)

      -- Rotate velocity, approach, etc.
      particle.initialVelocity = rotate(particle.initialVelocity, angle)
      particle.finalVelocity = rotate(particle.finalVelocity, angle)
      particle.approach = rotate(particle.approach, angle)
      particle.position = rotate(particle.position, angle)

      sb.logInfo("%s, %s", particle, position)

      localAnimator.spawnParticle(particle, position)

      emissionTimer = emissionInterval
    end

  end

end

function rotate(v, angle)
  if v then
    return vec2.rotate(v, angle)
  end
end