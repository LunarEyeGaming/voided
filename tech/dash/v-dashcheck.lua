local useSpecial2

local heldDashKeyLastTick

function init()
  useSpecial2 = config.getParameter("useSpecial2")
end

function pressedDashThisTick(args)
  local result

  if useSpecial2 then
    if input and input.bindDown then
      result = input.bindDown("voided", "dash")
    else
      result = args.moves["special2"] and not heldDashKeyLastTick
      heldDashKeyLastTick = args.moves["special2"]
    end
  else
    result = args.moves["up"] and not heldDashKeyLastTick
    heldDashKeyLastTick = args.moves["up"]
  end

  return result
end