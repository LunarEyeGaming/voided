require "/scripts/util.lua"

function init()
  self.translationConfig = config.getParameter("translationConfig")
  self.translationTime = self.translationConfig.duration
  self.translationLength = self.translationConfig.distance  -- How much to move by.
  self.direction = self.translationConfig.direction or 1
  self.frames = self.translationConfig.frames or 1
  self.isSolid = self.translationConfig.isSolid
  self.useHorizontal = self.translationConfig.useHorizontal
  
  if self.useHorizontal then
    self.endOffset = {self.direction * self.translationLength, 0}
  else
    self.endOffset = {0, self.direction * self.translationLength}
  end
  self.translationTimer = 0
  
  if self.isSolid and not storage.spaceStates then
    setupMaterialSpaces()
  end
  
  if storage.active == nil then
    updateActive()
  end
end

function update(dt)
  if storage.active then
    self.translationTimer = math.min(self.translationTime, self.translationTimer + dt)
  else
    self.translationTimer = math.max(0, self.translationTimer - dt)
  end
  local progress = self.translationTimer / self.translationTime
  
  -- TODO: Consider investigating the storage of util.easeInOutSin(progress, 0, 1) 
  -- and applying the result instead of calling util.easeInOutSin multiple times.
  
  if self.isSolid then
    object.setMaterialSpaces(storage.spaceStates[math.floor(util.lerp(progress, 1, #storage.spaceStates + 1))])
  end
  
  animator.setGlobalTag("doorProgress", math.floor(util.lerp(progress, 1, self.frames)))
  animator.resetTransformationGroup("door")
  animator.translateTransformationGroup("door", {
    util.lerp(progress, 0, self.endOffset[1]),
    util.lerp(progress, 0, self.endOffset[2])
  })
end

function onNodeConnectionChange(args)
  updateActive()
end

function onInputNodeChange(args)
  updateActive()
end

function updateActive()
  storage.active = (not object.isInputNodeConnected(0)) or object.getInputNodeLevel(0) -- Closed if no input node connected or input is off
end

function setupMaterialSpaces()
  local spaces = object.spaces()
  storage.spaceStates = {}
  
  if self.useHorizontal then
    local xRange = getXRange(spaces)
    -- WARNING: SPAGHETTI CODE! DO NOT REPLICATE UNLESS YOU WANT YOUR HEAD TO HURT!
    if self.direction == -1 then
      xRange = {xRange[2], xRange[1]}
    end
    
    for x = xRange[1], xRange[2], self.direction do
      local spaceState = {}
      for _, space in ipairs(spaces) do
        if (self.direction == -1 and space[1] <= x) or (self.direction == 1 and space[1] >= x) then
          table.insert(spaceState, {space, "metamaterial:door"})
        end
      end
      table.insert(storage.spaceStates, spaceState)
    end
  else
    local yRange = getYRange(spaces)
    if self.direction == -1 then
      yRange = {yRange[2], yRange[1]}
    end
    
    for y = yRange[1], yRange[2], self.direction do
      local spaceState = {}
      for _, space in ipairs(spaces) do
        if (self.direction == -1 and space[2] <= y) or (self.direction == 1 and space[2] >= y) then
          table.insert(spaceState, {space, "metamaterial:door"})
        end
      end
      table.insert(storage.spaceStates, spaceState)
    end
  end
end

function getXRange(poly)
  local minX = math.huge
  local maxX = -math.huge
  for _, point in ipairs(poly) do
    if point[1] > maxX then
      maxX = point[1]
    end
    if point[1] < minX then
      minX = point[1]
    end
  end
  return {minX, maxX}
end

function getYRange(poly)
  local minY = math.huge
  local maxY = -math.huge
  for _, point in ipairs(poly) do
    if point[2] > maxY then
      maxY = point[2]
    end
    if point[1] < minY then
      minY = point[2]
    end
  end
  return {minY, maxY}
end