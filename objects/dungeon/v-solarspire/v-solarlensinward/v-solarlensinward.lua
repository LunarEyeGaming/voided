function init()
  object.setAllOutputNodes(storage.active)

  decorative = config.getParameter("decorative", false)

  if decorative then
    local connectionAngle = config.getParameter("decorativeConnectionAngle", -90) * math.pi / 180
    if connectionAngle then
      animator.resetTransformationGroup("beamconnection")
      animator.rotateTransformationGroup("beamconnection", connectionAngle)
    end
    animator.setAnimationState("beamconnection", connectionAngle and "on" or "off")
    script.setUpdateDelta(0)
  end
end

function v_canReceiveBeams()
  return true
end

function receiveBeamState(state, beamConnectionAngle)
  storage.active = state

  -- See /objects/dungeon/v-solarlens/v-solarlens.lua:#render_workaround
  if beamConnectionAngle then
    animator.resetTransformationGroup("beamconnection")
    animator.rotateTransformationGroup("beamconnection", beamConnectionAngle - math.pi)
  end
  animator.setAnimationState("beamconnection", (beamConnectionAngle and state) and "on" or "off")

  object.setAllOutputNodes(storage.active)
end

function blocksBeams()
  return true
end