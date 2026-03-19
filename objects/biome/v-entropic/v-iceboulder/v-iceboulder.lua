require "/scripts/vec2.lua"

function die(smash)
  if not config.getParameter("projectileOnSmash") or smash then
    world.spawnProjectile(
      config.getParameter("projectile", "v-iceboulder"),
      vec2.add(object.position(), config.getParameter("projectileOffset", {0,0})),
      entity.id(),
      vec2.withAngle(math.random() * 2 * math.pi),
      false,
      config.getParameter("projectileParameters", {})
    )
  end
end
