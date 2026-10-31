require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/statuseffects/v-tickdamage.lua"

local destabilizeTime
local destabilizeTickDamage
local fadeColor
local fadeColorMaxOpacity

local timer

function init()
  animator.setParticleEmitterOffsetRegion("flakes", mcontroller.boundBox())

  if entity.entityType() == "player" then
    destabilizeTime = config.getParameter("playerDestabilizeTime")
  else
    destabilizeTime = config.getParameter("nonPlayerDestabilizeTime")
  end

  destabilizeTickDamage = VTickDamage:new{
    kind = "v-void",
    amount = 20,
    interval = 1.0,
    firstTickDelay = destabilizeTime,
    damageType = "IgnoresDef"
  }

  fadeColor = config.getParameter("fadeColor")
  fadeColorMaxOpacity = config.getParameter("fadeColorMaxOpacity")

  timer = 0
end

function update(dt)
  timer = math.min(destabilizeTime, timer + dt)

  destabilizeTickDamage:update(dt)
  if timer == destabilizeTime then
    animator.setParticleEmitterActive("flakes", true)
  else
    animator.setParticleEmitterActive("flakes", false)
  end

  effect.setParentDirectives(string.format("fade=%s=%f", fadeColor, timer / destabilizeTime * fadeColorMaxOpacity))
end

function uninit()

end
