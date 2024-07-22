require "/scripts/util.lua"
require "/scripts/voidedattackutil.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local attacks

function init()
  oldInit()

  attacks = {
    states.attack1
  }

  message.setHandler("attack", function(_, _, sourceId, attackId)
    state:set(attacks[attackId], sourceId)
  end)

  state = FSM:new()
  state:set(states.noop)
end

function update(dt)
  oldUpdate(dt)

  state:update()
end

states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.attack1()
  -- animator.setAnimationState("body", "windup")

  world.spawnProjectile(
    "v-ancientturretshot",
    mcontroller.position(),
    entity.id(),
    vec2.rotate({0, 1}, mcontroller.rotation()),
    false,
    {
      power = v_scaledPower(10)
    }
  )

  world.spawnProjectile(
    "v-ancientturretshot",
    mcontroller.position(),
    entity.id(),
    vec2.rotate({0, -1}, mcontroller.rotation()),
    false,
    {
      power = v_scaledPower(10)
    }
  )

  state:set(states.noop)
end

function getChildren()
  local children = copy(world.callScriptedEntity(self.childId, "getChildren"))

  table.insert(children, entity.id())

  return children
end