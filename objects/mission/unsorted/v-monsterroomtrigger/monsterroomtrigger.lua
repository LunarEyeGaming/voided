require "/scripts/util.lua"
require "/objects/wired/proximitysensor/proximitysensor.lua"

function init()
  self.detectEntityTypes = config.getParameter("detectEntityTypes")
  self.detectBoundMode = config.getParameter("detectBoundMode", "CollisionArea")
  local detectArea = config.getParameter("detectArea")
  local pos = object.position()
  if type(detectArea[2]) == "number" then
    --center and radius
    self.detectArea = {
      {pos[1] + detectArea[1][1], pos[2] + detectArea[1][2]},
      detectArea[2]
    }
  elseif type(detectArea[2]) == "table" and #detectArea[2] == 2 then
    --rect corner1 and corner2
    self.detectArea = {
      {pos[1] + detectArea[1][1], pos[2] + detectArea[1][2]},
      {pos[1] + detectArea[2][1], pos[2] + detectArea[2][2]}
    }
  end

  object.setInteractive(config.getParameter("interactive", true))
  object.setAllOutputNodes(false)
  animator.setAnimationState("switchState", "off")
  self.triggerTimer = 0
end

function update(dt) 
  if self.triggerTimer > 0 then
    self.triggerTimer = self.triggerTimer - dt
  elseif self.triggerTimer <= 0 then
    local entityIds = world.entityQuery(self.detectArea[1], self.detectArea[2], {
        withoutEntityId = entity.id(),
        includedTypes = self.detectEntityTypes,
        boundMode = self.detectBoundMode
      })

    entityIdsFriendly = util.filter(entityIds, function (entityId)
        local entityDamageTeam = world.entityDamageTeam(entityId)
        if entityDamageTeam.type ~= "friendly" then
          return false
        end
        if self.detectDamageTeam.team and self.detectDamageTeam.team ~= entityDamageTeam.team then
          return false
        end
        return true
      end)
    
    entityIdsEnemy = util.filter(entityIds, function (entityId)
        local entityDamageTeam = world.entityDamageTeam(entityId)
        if entityDamageTeam.type ~= "enemy" then
          return false
        end
        if self.detectDamageTeam.team and self.detectDamageTeam.team ~= entityDamageTeam.team then
          return false
        end
        return true
      end)

    if #entityIdsFriendly > 0 and #entityIdsEnemy > 0 then
      trigger()
    else
      object.setAllOutputNodes(false)
      object.setSoundEffectEnabled(false)
      animator.setAnimationState("switchState", "off")
    end
  end
end