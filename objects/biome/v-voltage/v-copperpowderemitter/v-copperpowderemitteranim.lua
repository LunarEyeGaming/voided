require "/scripts/util.lua"

local emitterSpecs
local emissionInterval
local emissionTimer

local ownPosition

local windLevel

local dt

function init()
  emitterSpecs = objectAnimator.getParameter("windParticleEmitter")

  -- Handle bad data.
  if not emitterSpecs then
    error("emitterSpecs not defined", 0)
  end

  if not emitterSpecs.emissionRate and not emitterSpecs.emissionWindFactor then
    error("emissionRate or emissionWindFactor not defined", 0)
  end

  -- Check for zero or negative values for emissionRate or emissionWindFactor, whichever one is defined.
  if emitterSpecs.emissionRate and emitterSpecs.emissionRate <= 0 then
    error("emissionRate must not be zero or negative", 0)
  end

  if emitterSpecs.emissionWindFactor and emitterSpecs.emissionWindFactor <= 0 then
    error("emissionWindFactor must not be zero or negative", 0)
  end

  if not emitterSpecs.particle then
    error("particle specifications not defined")
  end

  -- Apply defaults
  emitterSpecs.windThreshold = emitterSpecs.windThreshold or 0
  emitterSpecs.particle.initialVelocity = emitterSpecs.particle.initialVelocity or {0, 0}
  emitterSpecs.emissionRateVariance = emitterSpecs.emissionRateVariance or 0.0
  emitterSpecs.emissionVarianceWindFactor = emitterSpecs.emissionVarianceWindFactor or 0.0

  -- Initialize variables.
  if emitterSpecs.emissionWindFactor then
    emissionInterval = 0  -- Placeholder value
  else  -- emitterSpecs.emissionRate is defined
    emissionInterval = 1 / emitterSpecs.emissionRate
  end

  emissionTimer = emissionInterval

  ownPosition = objectAnimator.position()

  dt = script.updateDt()
end

function update()
  windLevel = world.windLevel(ownPosition)

  if math.abs(windLevel) > emitterSpecs.windThreshold then
    emissionTimer = emissionTimer - dt

    if emissionTimer <= 0 then
      emitParticle()

      emissionTimer = emissionInterval

      local emissionRate

      -- Update emissionInterval based on wind if configured. Also check that windLevel is not zero to avoid a division
      -- by zero error. Otherwise, update emissionInterval based on the variance.
      if emitterSpecs.emissionWindFactor then
        -- Calculate emissionRate from emissionWindFactor plus a bit of variance, all scaled to the wind level.
        emissionRate = (emitterSpecs.emissionWindFactor + util.randomInRange({-emitterSpecs.emissionVarianceWindFactor,
            emitterSpecs.emissionVarianceWindFactor})) * math.abs(windLevel)
      else
        emissionRate = emitterSpecs.emissionRate + util.randomInRange({-emitterSpecs.emissionRateVariance,
            emitterSpecs.emissionRateVariance})
      end

      if emissionRate ~= 0 then
        emissionInterval = 1 / emissionRate
      end
    end
  end

  --world.debugText("emissionInterval: %s", emissionInterval, ownPosition, "green")
end

function emitParticle()
  -- Copy particle specifications of emitter for later modification.
  local particleSpecs = copy(emitterSpecs.particle)

  -- Add wind to velocity
  particleSpecs.initialVelocity[1] = particleSpecs.initialVelocity[1] + windLevel

  -- If configured to apply hue shift to the particle, apply it.
  if emitterSpecs.applyHueShift then
    applyHueShift(particleSpecs)
  end

  -- Emit the particle.
  localAnimator.spawnParticle(particleSpecs, ownPosition)
end

-- Apply hue shift from the material below it.
function applyHueShift(particleSpecs)
  local hueshift = world.materialHueShift({ownPosition[1], ownPosition[2] - 1}, "foreground") * 360 / 256

  if particleSpecs.type ~= "textured" and particleSpecs.type ~= "animated" then
    error(string.format("script does not support hueshift for particle of type '%s'", particleSpecs.type), 0)
  end

  -- Add hueshift directive to particleSpecs image / animation
  if particleSpecs.type == "textured" then
    particleSpecs.image = particleSpecs.image .. "?hueshift=" .. hueshift
  else
    particleSpecs.animation = particleSpecs.animation .. "?hueshift=" .. hueshift
  end
end