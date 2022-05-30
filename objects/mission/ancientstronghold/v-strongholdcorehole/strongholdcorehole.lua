function init()
  message.setHandler("open", function()
    animator.setAnimationState("hole", "open")
  end)
  
  message.setHandler("close", function()
    animator.setAnimationState("hole", "closed")
  end)
end

function update(dt)

end