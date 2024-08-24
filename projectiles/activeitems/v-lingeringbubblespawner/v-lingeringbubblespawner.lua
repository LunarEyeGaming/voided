require "/scripts/vec2.lua"

local projectileType
local projectileDistance
local projectileCount
local projectileSpreadAngle
local inheritDamageFactor
local projectileParameters

function init()
  projectileType = config.getParameter("projectileType")
  projectileDistance = config.getParameter("projectileDistance")
  projectileCount = config.getParameter("projectileCount")
  projectileSpreadAngle = config.getParameter("projectileSpreadAngle") * math.pi / 180  -- Convert to radians
  inheritDamageFactor = config.getParameter("inheritDamageFactor")
  projectileParameters = config.getParameter("projectileParameters")

  if inheritDamageFactor then
    projectileParameters.power = projectile.power() * inheritDamageFactor
  end
  projectileParameters.powerMultiplier = projectile.powerMultiplier()
end

function destroy()
  -- Calculate starting angle
  local angle = -projectileSpreadAngle * (projectileCount - 1) / 2

  -- Do the following projectileCount times...
  for _ = 1, projectileCount do
    -- Spawn projectile.
    world.spawnProjectile(
      projectileType,
      vec2.add(vec2.withAngle(angle + mcontroller.rotation(), projectileDistance), mcontroller.position()),
      projectile.sourceEntity(),
      vec2.withAngle(angle + mcontroller.rotation()),
      false,
      projectileParameters
    )
    -- Add angle.
    angle = angle + projectileSpreadAngle
  end
end