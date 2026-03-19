local preFreezeMovementModifiers
local freezeMovementModifiers
local freezeThreshold
local freezeDuration
local freezeDamage

local timer
local freezeAmount  -- Controlled by message handlers.
local state

function init()
  animator.setParticleEmitterOffsetRegion("snow", mcontroller.boundBox())
  animator.setParticleEmitterActive("snow", true)

  effect.setParentDirectives(config.getParameter("directives", ""))

  preFreezeMovementModifiers = config.getParameter("preFreezeMovementModifiers", {})
  freezeMovementModifiers = config.getParameter("freezeMovementModifiers", {})
  freezeThreshold = config.getParameter("freezeThreshold")
  freezeDuration = config.getParameter("freezeDuration")
  freezeDamage = config.getParameter("freezeDamage")
  state = "preFreeze"
  timer = 0
  freezeAmount = 0

  message.setHandler("v-auroriteeffect-freeze", function(_, _, amount)
    freezeAmount = freezeAmount + amount
  end)
end

function update(dt)
  world.debugText("state: %s, timer: %s, freezeAmount: %s", state, timer, freezeAmount, mcontroller.position(), "green")
  timer = timer - dt
  if state == "preFreeze" then
    mcontroller.controlModifiers(preFreezeMovementModifiers)
    if freezeAmount >= freezeThreshold then
      timer = freezeDuration
      state = "freeze"
    end
  elseif state == "freeze" then
    mcontroller.controlModifiers(freezeMovementModifiers)

    if timer <= 0 then
      status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = freezeDamage,
        damageSourceKind = "ice",
        sourceEntityId = entity.id()
      })

      freezeAmount = 0  -- Reset freezeAmount
      state = "preFreeze"
    end
  else
    sb.logError("v-auroriteeffect: Invalid state")
  end
end