require "/scripts/util.lua"
require "/scripts/vec2.lua"

local stagehandSpawned

function init()
  script.setUpdateDelta(60)
end

function update(dt)
  -- Spawn stagehand.
  if not stagehandSpawned then
    world.spawnStagehand(mcontroller.position(), "v-icemelter")
    stagehandSpawned = true
    return
  end
end