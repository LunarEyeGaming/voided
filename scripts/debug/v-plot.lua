require "/scripts/vec2.lua"
require "/scripts/util.lua"

VPlot = {autoScaleX = true, autoScaleY = true, drawPoints = true, drawLines = false, width = 10, height = 10}

function VPlot:new(obj)
  obj = obj or {}
  setmetatable(obj, self)
  self.__index = self

  self.points = {}

  return obj
end

function VPlot:draw(pos)
  local width = self.width
  local height = self.height
  -- Draw axis lines
  world.debugLine(pos, vec2.add(pos, {width, 0}), "white")
  world.debugLine(pos, vec2.add(pos, {0, height}), "white")

  if #self.points == 0 then
    world.debugText("No points in plot", vec2.add(pos, {width / 2, height / 2}), "white")
    return
  end

  -- Draw axis markers
  for x = 0, width, 2 do
    local xValue = util.lerp(x / width, self.minX, self.maxX)
    world.debugText("%s", xValue, {x + pos[1], pos[2] - 1}, "white")
  end
  for y = 0, height, 2 do
    local yValue = util.lerp(y / height, self.minY, self.maxY)
    world.debugText(string.format("%.2f", yValue), {pos[1] - 1, y + pos[2]}, "white")
  end

  local positions = {}

  for _, point in ipairs(self.points) do
    local pointPos = {
        (point[1] - self.minX) / (self.maxX - self.minX) * width + pos[1],
        (point[2] - self.minY) / (self.maxY - self.minY) * height + pos[2]
      }
    table.insert(positions, pointPos)
  end
  -- Draw points
  if self.drawPoints then
    for _, pointPos in ipairs(positions) do
      world.debugPoint(pointPos, "green")
    end
  end

  if self.drawLines then
    for i = 1, #positions - 1 do
      local point1 = positions[i]
      local point2 = positions[i + 1]

      world.debugLine(point1, point2, "green")
    end
  end
end

function VPlot:addPoint(point)
  table.insert(self.points, point)

  if self.maxPoints and #self.points > self.maxPoints then
    table.remove(self.points, 1)
  end

  if self.autoScaleX then
    local minX = math.huge
    local maxX = -math.huge
    for _, p in ipairs(self.points) do
      local x = p[1]
      if x < minX then
        minX = x
      end
      if x > maxX then
        maxX = x
      end
    end

    self.minX = minX
    self.maxX = maxX
  end

  if self.autoScaleY then
    local minY = math.huge
    local maxY = -math.huge
    for _, p in ipairs(self.points) do
      local y = p[2]
      if y < minY then
        minY = y
      end
      if y > maxY then
        maxY = y
      end
    end

    self.minY = minY
    self.maxY = maxY
  end
end