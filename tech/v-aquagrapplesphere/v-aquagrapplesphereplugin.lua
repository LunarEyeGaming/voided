local oldInit = init or function() end
local oldUpdate = update or function() end

local movementParams

function init()
  oldInit()

  movementParams = mcontroller.baseParameters()
  movementParams = sb.jsonMerge(movementParams, self.transformedMovementParameters)
end

function update(args)
  oldUpdate(args)

  if self.active and mcontroller.liquidPercentage() > 0.2 then
    local controlDirection = 0
    if args.moves["up"] then controlDirection = controlDirection + 1 end
    if args.moves["down"] then controlDirection = controlDirection - 1 end

    if controlDirection ~= 0 then
      mcontroller.controlApproachYVelocity(self.ballLiquidSpeed * controlDirection, movementParams.liquidForce)
    end
  end
end