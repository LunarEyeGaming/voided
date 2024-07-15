function init()
  local sounds = config.getParameter("sparkSounds", {})
  animator.setSoundPool("sparks", sounds)
  self.detonated = false
  
  message.setHandler("v-faultywiring-trigger", onTrigger)
end

function update(dt)
  if storage.detonationTimer then
    storage.detonationTimer = storage.detonationTimer - dt
    if storage.detonationTimer <= 0 then
      detonate()
    end
  elseif object.isInputNodeConnected(0) and object.getInputNodeLevel(0) then
    onTrigger()
  end
end

function onTrigger()
  animator.playSound("sparks", -1)
  animator.setParticleEmitterActive("sparks", true)
  storage.detonationTimer = config.getParameter("detonationTime", 0)
end

function die()
  if config.getParameter("triggerOnBreak", false) then
    detonate()
  end
end

function detonate()
  if not self.detonated then
    local pos = config.getParameter("explosionOffset", {0, 0})
    pos = {pos[1] + entity.position()[1], pos[2] + entity.position()[2]}
    world.spawnProjectile(config.getParameter("explosionProjectile", "explosivebarrel"), pos, entity.id(), {0, 0})
    object.smash(true)
  end
end
