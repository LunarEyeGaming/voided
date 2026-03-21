local freezeRate
local waterId

function init()
  freezeRate = 0.5
  waterId = 1
end

function update(dt)
  if mcontroller.liquidPercentage() > 0.1 and mcontroller.liquidId() == waterId then
    status.overConsumeResource("v-warmth", freezeRate * dt)
  end
end