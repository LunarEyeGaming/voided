require "/scripts/rect.lua"

local oldInit = init or function() end

local oldUpdate = update or function() end

local itemQueryRegion

local itemLiftEffectProjectile
local itemLiftEffectProjectileInterval
local timer

function init()
  oldInit()

  itemQueryRegion = rect.translate(config.getParameter("itemQueryRegion"), mcontroller.position())

  itemLiftEffectProjectile = config.getParameter("itemLiftEffectProjectile")
  itemLiftEffectProjectileInterval = config.getParameter("itemLiftEffectProjectileInterval")
  timer = itemLiftEffectProjectileInterval
end

function update(dt)
  oldUpdate(dt)

  timer = timer - dt
  if timer <= 0 then
    triggerItemLiftEffects()
    timer = itemLiftEffectProjectileInterval
  end
end

function triggerItemLiftEffects()
  local queried = world.entityQuery({itemQueryRegion[1], itemQueryRegion[2]}, {itemQueryRegion[3], itemQueryRegion[4]},
  {includedTypes = {"itemdrop"}})

  for _, entityId in ipairs(queried) do
    world.spawnProjectile(itemLiftEffectProjectile, world.entityPosition(entityId))
  end
end