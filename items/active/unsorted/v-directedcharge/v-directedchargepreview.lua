require "/scripts/vec2.lua"
require "/scripts/v-animator.lua"

local drawPreview = {}

local movingLineCycle
local movingLineFrames

local movingLineTimer

function drawPreview.direction()
end

function drawPreview.position()
  local placementPos = animationConfig.animationParameter("placementPos") or {0, 0}

  localAnimator.addDrawable({
    image = "/items/active/unsorted/v-directedcharge/preview.png",
    position = placementPos,
    rotation = -math.pi / 2
  }, "ForegroundTile+10")

  drawMovingLine(
    activeItemAnimation.ownerPosition(),
    placementPos,
    "/items/active/unsorted/v-directedcharge/line/start.png",
    "/items/active/unsorted/v-directedcharge/line/mid.png",
    "/items/active/unsorted/v-directedcharge/line/end.png",
    1.0,
    vAnimator.frameNumber(movingLineTimer, movingLineCycle, 1, movingLineFrames)
  )
end

function drawPreview.none()

end

function init()
  -- previewMap = {
  --   direction = previewDirection,
  --   position = previewPosition,
  --   none = previewNone
  -- }
  movingLineCycle = 1
  movingLineFrames = 1

  movingLineTimer = 0
end

function update(dt)
  movingLineTimer = movingLineTimer + dt
  if movingLineTimer >= movingLineCycle then
    movingLineTimer = 0
  end

  local mode = animationConfig.animationParameter("placementPreviewMode") or "none"
  localAnimator.clearDrawables()
  drawPreview[mode]()  -- Run preview function based on mode.
end

function drawMovingLine(from, to, startImage, midImage, endImage, segmentSize, frameNumber)
  local distance = world.distance(to, from)
  local direction = vec2.norm(distance)
  local angle = vec2.angle(direction)
  local segments, lastSegmentSize = math.modf(vec2.mag(distance))
  local lastSegmentSizePx = lastSegmentSize * 8

  for i = 0, segments do
    local image = midImage .. ":" .. frameNumber
    if i == 0 then
      image = startImage .. ":" .. frameNumber
    end
    if i == segments then
      image = endImage .. ":" .. frameNumber
    end

    localAnimator.addDrawable({
      image = image,
      position = vec2.add(from, vec2.mul(direction, i * segmentSize)),
      rotation = angle,
      fullbright = true
    }, "ForegroundTile+10")
  end
end