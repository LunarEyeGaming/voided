local flipTime

local pullDirection

local flipTimer

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldFire = fire or function() end

function init()
  oldInit()

  flipTime = config.getParameter("dualFireGracePeriod")

  pullDirection = self.fireAngleOffset > 0 and -1 or 1
  flipTimer = nil
end

function update(dt, fireMode, shiftHeld)
  oldUpdate(dt, fireMode, shiftHeld)

  -- do
  --   local verticalOffset = activeItem.hand() == "primary" and 0 or -1
  --   local pos = {mcontroller.position()[1], mcontroller.position()[2] + verticalOffset}
  --   world.debugText("fireAngleOffset: %s, flipTimer: %s", self.fireAngleOffset, flipTimer, pos, "green")
  -- end

  -- If an angle offset flip is active...
  if flipTimer then
    flipTimer = flipTimer - dt  -- Decrease timer

    -- If the timer has reached zero...
    if flipTimer <= 0 then
      activeItem.callOtherHandScript("flipDirection")  -- Flip again.
      flipTimer = nil  -- Unset timer to indicate that a flip is no longer active.
    end
  end
end

function fire()
  -- Inject some parameters so that the projectile can use them.
  local baseAimDirection = vec2.withAngle(self.aimAngle)
  baseAimDirection[1] = baseAimDirection[1] * self.aimDirection
  self.projectileParameters.baseAimDirection = baseAimDirection
  self.projectileParameters.pullDirection = pullDirection * self.aimDirection

  oldFire()

  activeItem.callOtherHandScript("flipDirection")  -- Flip
  flipTimer = flipTime  -- Set timer to indicate that a flip is active.
end

function flipDirection()
  self.fireAngleOffset = -self.fireAngleOffset
  self.fireOffset[2] = -self.fireOffset[2]
  pullDirection = -pullDirection
end