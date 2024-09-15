function destroy()
  local cfg = config.getParameter("specialEffectConfig")

  local queried = world.entityQuery(mcontroller.position(), cfg.effectRadius, {includedTypes = {"player"}})

  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "v-invokeSpecialEffect", cfg.kind, cfg.arguments, cfg.onScreenOnly, mcontroller.position())
  end
end