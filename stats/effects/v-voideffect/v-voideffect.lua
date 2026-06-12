require "/scripts/status.lua"

local damageBonusFactor
local damageTaken
local listener

function init()
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  effect.setParentDirectives("fade=BF3300=0.25")
  animator.playSound("burn", -1)

  damageBonusFactor = 0.5
  damageTaken = 0

  listener = damageListener("damageTaken", function(notifications)
    ---@type DamageNotification
    for _, notification in ipairs(notifications) do
      damageTaken = damageTaken + notification.healthLost
    end
  end)

  script.setUpdateDelta(5)
end

function update(dt)
  listener:update()
end

function onExpire()
  status.applySelfDamageRequest({
    damageType = "IgnoresDef",
    damage = math.floor(damageTaken * damageBonusFactor),
    damageSourceKind = "v-void",
    sourceEntityId = entity.id()
  })
end

function uninit()

end
