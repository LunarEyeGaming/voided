--[[
  Using a status effect here to apply a jump pad force because it is more consistent.
]]

function init()
end

function update()
  mcontroller.controlParameters({airJumpProfile = {jumpSpeed = 125, jumpHoldTime = 0.3}})
end