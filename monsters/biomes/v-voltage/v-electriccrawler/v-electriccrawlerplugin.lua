--[[
  Script plugin so that you can pick up the lil bean and throw it.
]]

local oldInit = init or function() end
local oldInteract = interact or function() end
local oldUpdate = update or function() end

local pickupItem

local flingVelocity
local initialStunTime

local squirmedOut

local itemToDelete

function init()
  oldInit()

  pickupItem = config.getParameter("pickupItem")

  flingVelocity = config.getParameter("flingVelocity")
  if flingVelocity then
    mcontroller.setVelocity(flingVelocity)
  end

  initialStunTime = config.getParameter("initialStunTime")

  if initialStunTime then
    status.setResource("stunned", initialStunTime)
  end

  local initialHealthPercentage = config.getParameter("initialHealthPercentage")
  if initialHealthPercentage then
    status.setResourcePercentage("health", initialHealthPercentage)
  end

  itemToDelete = config.getParameter("deleteItemDrop")

  -- Do not set to be interactive if the monster is captured.
  if not capturable or not capturable.podUuid() then
    monster.setInteractive(true)
  end
end

function update(dt)
  -- Try to delete the item until it's been deleted.
  if itemToDelete then
    if world.entityExists(itemToDelete) then
      monster.setInteractive(false)  -- Cannot be picked up until the old item disappears to prevent duplication

      mcontroller.setPosition(world.entityPosition(itemToDelete))

      world.takeItemDrop(itemToDelete)
    else
      monster.setInteractive(true)  -- Can be picked up now

      itemToDelete = nil  -- Stop worrying about itemToDelete since it no longer exists
    end
  end

  oldUpdate(dt)
end

function interact(args)
  oldInteract(args)

  monster.setInteractive(false)

  -- Spawn bean pickup
  world.spawnItem(pickupItem, world.entityPosition(args.sourceId), 1, {level = monster.level(),
      healthPercentage = status.resourcePercentage("health"), uniqueParameters = monster.uniqueParameters()})

  -- Setup for silently dying
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  self.deathBehavior = nil
  self.shouldDie = true

  -- Turn invisible
  status.addEphemeralEffect("v-invisible")

  -- Hide health bar
  monster.setDamageBar("None")

  -- Die
  status.setResourcePercentage("health", 0.0)
end