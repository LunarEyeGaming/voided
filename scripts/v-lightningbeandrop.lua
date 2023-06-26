require "/scripts/util.lua"

--[[
  Script that makes it so that any Lightning Beans in the player's inventory will eventually wiggle their way out. It
  also turns Lightning Bean item drops into their monster equivalent.
]]

local itemName
local monsterType

local dropTimeRange
local dropTimer

local dropSoundPool

local itemDropQueryRadius
local itemDropConversionDelay
local trackedItemDrops

function init()
  itemName = "v-electriccrawleritem"
  monsterType = getMonsterType()

  dropTimeRange = {5, 10}
  dropTimer = util.randomInRange(dropTimeRange)
  
  dropSoundPool = {"/sfx/npc/monsters/monster_hop.ogg"}
  
  itemDropQueryRadius = 50
  itemDropConversionDelay = 0.25
  trackedItemDrops = {}
end

function update(dt)
  if player.hasItem(itemName) then
    dropTimer = dropTimer - dt
    
    if dropTimer <= 0 then
      wiggleOut()
      
      dropTimer = util.randomInRange(dropTimeRange)
    end
  else
    dropTimer = util.randomInRange(dropTimeRange)
  end
  
  queryItems()
  updateItems(dt)
  
  world.debugText("queried items: %s", trackedItemDrops, mcontroller.position(), "green")
end

-- Deletes one item of ID itemName from the player's inventory and spawns a monster of type monsterType using its
-- parameters.
function wiggleOut()
  -- This actually gets the override parameters (unlike player.consumeItem), which are necessary to spawn the
  -- Lightning Bean with the appropriate configurations.
  local itemDescriptor = player.getItemWithParameter("itemName", itemName)
  player.consumeItem({name = itemName, count = 1})

  spawnMonsterFromItem(itemDescriptor)
  
  -- Play sound
  world.spawnProjectile("v-proxyprojectile", mcontroller.position(), nil, {0, 0}, false, {
    actionOnReap = {
      {
        action = "sound",
        options = dropSoundPool
      }
    }
  })
end

-- This complex system is necessary because world.takeItemDrop doesn't always work.

-- Updates the timers on tracked items if they have not been converted. Also removes any items that no longer exist and
-- converts them when they are ready to be converted. If an item has already been converted, then we wait until it's
-- deleted to stop tracking it.
function updateItems(dt)
  for entityId, itemInfo in pairs(trackedItemDrops) do
    if not world.entityExists(entityId) then
      trackedItemDrops[entityId] = nil
    elseif not itemInfo.converted then
      itemInfo.timer = itemInfo.timer - dt

      if itemInfo.timer <= 0 then
        local itemDescriptor = world.itemDropItem(entityId)

        spawnMonsterFromItem(itemDescriptor, entityId)
        
        itemInfo.converted = true
      end
    end
  end
end

-- Adds any untracked item drops with ID itemName to trackedItemDrops.
function queryItems()
  local itemDrops = world.itemDropQuery(mcontroller.position(), itemDropQueryRadius)
  
  for _, entityId in ipairs(itemDrops) do
    local itemDescriptor = world.itemDropItem(entityId)
    
    -- If a match has been found and it is not being tracked yet...
    if itemDescriptor.name == itemName and not trackedItemDrops[entityId] then
      trackedItemDrops[entityId] = {timer = itemDropConversionDelay, converted = false}  -- Add entry
    end
  end
end

-- Returns the monsterType configuration value from the itemName
function getMonsterType()
  local itemConfig = root.itemConfig(itemName)

  return itemConfig.config.monsterType
end

-- Spawns a monster using the given item descriptor's parameters. Optionally, an entityId can be provided for the given
-- monster to delete. This is necessary since client-side scripts cannot delete items from existence.
function spawnMonsterFromItem(itemDescriptor, entityId)
  if itemDescriptor.parameters then
    local params = {level = itemDescriptor.parameters.level,
        initialHealthPercentage = itemDescriptor.parameters.healthPercentage, deleteItemDrop = entityId}
    world.spawnMonster(monsterType, mcontroller.position(), sb.jsonMerge(itemDescriptor.parameters.uniqueParameters,
        params))
  end
end