-- Parameters
local spirePortalUniqueId
local destabilizeCheckInterval

local destabilizeCheckTimer


function init()
  spirePortalUniqueId = config.getParameter("spirePortalUniqueId")
  destabilizeCheckInterval = config.getParameter("destabilizeCheckInterval", 1.0)

  object.setAllOutputNodes(false)

  destabilizeCheckTimer = destabilizeCheckInterval
end

function update(dt)
  destabilizeCheckTimer = destabilizeCheckTimer - dt

  if destabilizeCheckTimer <= 0 then
    local spirePortalId = world.loadUniqueEntity(spirePortalUniqueId)
    if spirePortalId ~= 0 and world.entityExists(spirePortalId) and world.callScriptedEntity(spirePortalId, "isDestabilized") then
      object.setAllOutputNodes(true)
    end
    destabilizeCheckTimer = destabilizeCheckInterval
  end
end