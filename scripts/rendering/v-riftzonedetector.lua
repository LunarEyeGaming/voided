require "/scripts/messageutil.lua"
require "/scripts/rect.lua"

require "/scripts/v-animator.lua"
require "/scripts/v-time.lua"

local WHITE = {255, 255, 255, 255}
local ZERO_ALPHA_WHITE = {255, 255, 255, 0}

local detectionRegion
local ticker
local promiseKeeper
local riftZones

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()
  detectionRegion = {-300, -300, 300, 300}
  ticker = VTicker:new()
  promiseKeeper = PromiseKeeper:new()
  riftZones = {}

  ticker:addInterval(0.1, function()
    promiseKeeper:add(world.sendEntityMessage("v-riftzonemanager-stagehand", "getAllRiftZones"), function(res)
      riftZones = res
    end)
  end)
end

function update(dt)
  localAnimator.clearDrawables()

  oldUpdate(dt)

  ticker:update(dt)
  promiseKeeper:update()

  local ownPos = world.entityPosition(player.id())
  for _, riftZone in ipairs(riftZones) do
    local pos = world.distance(riftZone.position, ownPos)
    if rect.contains(detectionRegion, pos) then
      localAnimator.addDrawable({
        image = "/interface/scripted/v-riftzonedetector/point.png",
        position = vec2.mul(pos, 1 / 48),
        fullbright = true,
        color = vAnimator.lerpColor(riftZone.timeToLiveRatio, ZERO_ALPHA_WHITE, WHITE)
      }, "ForegroundOverlay+256")
    end
  end
end