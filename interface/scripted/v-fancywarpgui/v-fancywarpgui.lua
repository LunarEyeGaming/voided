require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local sounds
local settings
local canvasWindowSize
local canvas  ---@type CanvasWidget
local canvasWindowRect

local destInfoBoxHeight

local destinationSettings
local mapObject
-- Drawables with a zero or negative z-level. Ordered by z-level. Drawables with the same z-level do not have a stable
-- order.
local belowDrawables
-- Drawables with an undefined z-level. They render above everything in belowDrawables in the order they are listed.
local noZLevelDrawables
-- Drawables with a positive z-level. Ordered by z-level. Drawables with the same z-level do not have a stable order.
local aboveDrawables

local wasHovering
local isHovering

local isSelected
local wasSelected
local selectionTimer

-- HOOKS & CALLBACKS

function init()
  sounds = config.getParameter("sounds")
  settings = config.getParameter("renderSettings")
  canvasWindowSize = widget.getSize("consoleScreenCanvas")
  canvas = widget.bindCanvas("consoleScreenCanvas")
  canvasWindowRect = rect.withSize(widget.getPosition("consoleScreenCanvas"), canvasWindowSize)
  destInfoBoxHeight = widget.getSize("destinfo")[2]

  destinationSettings = config.getParameter("destinationSettings")
  mapObject = destinationSettings.mapObject

  local otherDrawables = destinationSettings.otherDrawables

  -- Build lists of drawables
  belowDrawables = {}
  noZLevelDrawables = {}
  aboveDrawables = {}

  for _, drawable in ipairs(otherDrawables) do
    if drawable.zLevel then
      if drawable.zLevel > 0 then
        table.insert(aboveDrawables, drawable)
      else
        table.insert(belowDrawables, drawable)
      end
    else
      table.insert(noZLevelDrawables, drawable)
    end
  end

  -- Sort aboveDrawables and belowDrawables by zLevel
  table.sort(aboveDrawables, function(a, b) return a.zLevel < b.zLevel end)
  table.sort(belowDrawables, function(a, b) return a.zLevel < b.zLevel end)

  populateInfoBox()

  -- Hide info box.
  widget.setVisible("destinfo", false)
end

function update(dt)
  canvas:clear()

  renderBackground()

  for _, drawable in ipairs(belowDrawables) do
    canvas:drawImageDrawable(drawable.image, drawable.position, drawable.scale or 1.0)
  end

  for _, drawable in ipairs(noZLevelDrawables) do
    canvas:drawImageDrawable(drawable.image, drawable.position, drawable.scale or 1.0)
  end

  canvas:drawImageDrawable(mapObject.image, mapObject.position, mapObject.scale or 1.0)

  for _, drawable in ipairs(aboveDrawables) do
    canvas:drawImageDrawable(drawable.image, drawable.position, drawable.scale or 1.0)
  end

  if isSelected then
    selectionTimer = selectionTimer + dt
    renderSelection(dt)
  else
    updateHoverState()
  end

  updateInfoBox()
end

function dismissed()
  for _,sound in pairs(sounds) do
    pane.stopAllSounds(sound)
  end
end

function canvasClickEvent(position, button, isButtonDown)
  if widget.hasFocus("consoleScreenCanvas") and not widget.active("jumpDialog") then
    attemptSelection(position, button, isButtonDown)
  end
end

function teleportToDestination()
  player.warp(destinationSettings.warpLocation, "beam")
  pane.dismiss()
end

-- HELPER FUNCTIONS

-- Populates the contents of the info box.
function populateInfoBox()
  widget.setImage("destinfo.inner.previewImage", destinationSettings.previewImage)

  widget.setText("destinfo.inner.name", destinationSettings.title)
  widget.setText("destinfo.inner.subtitle", destinationSettings.subtitle)
  widget.setText("destinfo.inner.description", destinationSettings.description)

  widget.setText("destinfo.inner.threatValue", destinationSettings.threatLevel)
  widget.setFontColor("destinfo.inner.threatValue", destinationSettings.threatLevelColor)
end

---Based on cockpitview.lua::View:renderBackground(). Renders the starry background.
function renderBackground()
  local center = {0, 0}
  -- get the lower left texture offset from the center of the screen
  -- this is way more complicated than it should be
  local offset = vec2.add(vec2.mul(center, settings.backgroundScale), vec2.mul(vec2.div(canvasWindowSize, 2), (1.0 - settings.backgroundScale)))

  local screenCoords = {0, 0, canvasWindowSize[1], canvasWindowSize[2]}
  for _,background in pairs(settings.backgrounds) do
    canvas:drawTiledImage(background, offset, screenCoords, settings.backgroundScale, settings.backgroundColor)
  end
end

---Based on cockpitview.lua::View:renderSelection(). Renders the selection reticle.
---@param dt any
function renderSelection(dt)
  local animation = settings.selectMarkerAnimation
  local frame = math.ceil(math.min(animation.cycle, selectionTimer) / animation.cycle * animation.frames)
  canvas:drawImage(string.format(animation.image, frame), mapObject.position, 1, "white", true)
end

---Updates everything concerning hovering.
function updateHoverState()
  wasHovering = isHovering

  isHovering = vec2.mag(vec2.sub(canvas:mousePosition(), mapObject.position)) < mapObject.selectRadius

  -- Play hover sound.
  if isHovering and not wasHovering then
    pane.playSound(sounds.hover)
  end

  -- Show hover image.
  if isHovering then
    canvas:drawImage(settings.hoverImage, mapObject.position, 1, "white", true)
  end
end

---Based on cockpitview.lua::View:renderInfoBox(). Updates everything concerning the info box's rendering. This is safe
---to call unconditionally.
function updateInfoBox()
  -- If it is not selected but was selected before...
  if not isSelected and wasSelected then
    -- Hide info box.
    widget.setVisible("destinfo", false)
  -- Otherwise, if it is selected right now...
  elseif isSelected then
    -- If it was not selected before...
    if not wasSelected then
      -- Show info box.
      widget.setVisible("destinfo", true)
    end

    local size = widget.getSize("destinfo")

    -- Update size of info box
    local height = math.min(1.0, selectionTimer / settings.destInfo.expandTime) * destInfoBoxHeight
    widget.setSize("destinfo", {size[1], height})
    widget.setSize("destinfo.background", {size[1], height})
    widget.setSize("destinfo.inner", {size[1] - 2, height - 10})

    -- Calculate position of info box
    local position = vec2.add(vec2.add(mapObject.position, {0, -height / 2}), settings.destInfo.offset)

    local box = rect.withSize(vec2.add(position, rect.ll(canvasWindowRect)), {size[1], height})
    box = rect.bound(box, rect.pad(canvasWindowRect, -settings.windowBorderMargin))

    -- Calculate endpoints of elbow line and adjust info box bounds to use the minimum offset
    local line
    if box[1] - mapObject.position[1] < settings.destInfo.minOffset then
      box[3] = mapObject.position[1] - settings.destInfo.offset[1]
      box[1] = box[3] - size[1]
      box = rect.bound(box, rect.pad(canvasWindowRect, -settings.windowBorderMargin))
      line = {
        vec2.sub({math.floor(box[3] - 1), (box[4] + box[2]) / 2}, {canvasWindowRect[1], canvasWindowRect[2]}),
        vec2.add(mapObject.position, {-3, 0})
      }
    else
      line = {
        vec2.add(mapObject.position, {3, 0}),
        vec2.sub({math.floor(box[1]), (box[4] + box[2]) / 2}, {canvasWindowRect[1], canvasWindowRect[2]})
      }
    end
    -- Draw elbow line
    local mid = (line[1][1] + line[2][1]) / 2
    canvas:drawLine(line[1], {mid, line[1][2]}, {23, 178, 0}, 2)
    canvas:drawLine({mid, line[1][2]}, {mid, line[2][2]}, {23, 178, 0}, 2)
    canvas:drawLine({mid, line[2][2]}, line[2], {23, 178, 0}, 2)


    -- Adjust position of info box.
    widget.setPosition("destinfo", rect.ll(box))

    -- Display inner contents if the info box has finished expanding.
    if selectionTimer > settings.destInfo.expandTime then
      widget.setVisible("destinfo.inner", true)
    else
      widget.setVisible("destinfo.inner", false)
    end
  end

  wasSelected = isSelected
end

---Attempts to select the destination of interest given a click position `position`, the button that was pressed
---`button`, and a boolean `isButtonDown` determining whether it was down or up.
---@param position Vec2I
---@param button unsigned
---@param isButtonDown boolean
function attemptSelection(position, button, isButtonDown)
  -- If this event was because the user let go of the mouse button, or it is not mouse 1, abort.
  if not isButtonDown or button ~= 0 then return end

  -- If the user clicked over the selection area...
  if vec2.mag(vec2.sub(position, mapObject.position)) < mapObject.selectRadius then
    -- If the thing is not already selected...
    if not isSelected then
      pane.playSound(sounds.select)

      -- Mark it as selected and reset the selection timer.
      isSelected = true
      selectionTimer = 0
    end
  else
    if isSelected then
      pane.playSound(sounds.deselect)

      isSelected = false
    end
  end
end