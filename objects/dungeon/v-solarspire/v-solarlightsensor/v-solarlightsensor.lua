local invertOutput

function init()
  invertOutput = config.getParameter("invertOutput")

  if storage.active == nil then
    storage.active = false
  end

  setState(storage.active)
end

function update(dt)
  world.debugText("%s", storage.active, object.position(), "green")
  local boundBox = world.entityMetaBoundBox(entity.id())
  if not boundBox then return end
  boundBox = {
    boundBox[1] + object.position()[1],
    boundBox[2] + object.position()[2],
    boundBox[3] + object.position()[1],
    boundBox[4] + object.position()[2],
  }
  world.debugPoly({
    {boundBox[1], boundBox[2]},
    {boundBox[3], boundBox[2]},
    {boundBox[3], boundBox[4]},
    {boundBox[1], boundBox[4]}
  }, "green")
end

function v_canReceiveBeams()
  return true
end

function receiveBeamState(state)
  storage.active = state

  setState(state)
end

function blocksBeams()
  return false
end

function setState(state)
  animator.setAnimationState("sensor", state and "on" or "off")

  if invertOutput then
    object.setAllOutputNodes(not state)
  else
    object.setAllOutputNodes(state)
  end
end