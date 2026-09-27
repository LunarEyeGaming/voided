
local oldInit = init or function() end

function init()
  oldInit()

  message.setHandler("v-wormAnimate", function(_, _, stateType, state)
    if self.childId then
      world.sendEntityMessage(self.childId, "v-wormAnimate", stateType, state)
    end
    animator.setAnimationState(stateType, state)
  end)
end