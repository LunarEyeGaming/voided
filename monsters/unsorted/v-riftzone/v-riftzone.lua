require "/scripts/vec2.lua"
require "/scripts/interp.lua"

local scanRadius
local tileSofteningRadius
local invisibleOre
local visibleOre
local appearTime

local appearTimer
local prevPos

local prevRadius

local playSoundTickTimer

function init()
  scanRadius = 35
  tileSofteningRadius = 80
  monster.setAnimationParameter("riftSize", scanRadius)
  invisibleOre = "v-nulliuminvisible"
  visibleOre = "v-nulliumvisible"
  appearTime = 7

  appearTimer = 0
  prevPos = vec2.floor(mcontroller.position())
  monster.setDamageBar("None")

  prevRadius = 0

  playSoundTickTimer = 2
end

function update(dt)
  if appearTimer then
    if playSoundTickTimer then
      playSoundTickTimer = playSoundTickTimer - 1
      if playSoundTickTimer <= 0 then

        animator.playSound("open")
        playSoundTickTimer = nil
      end
    end

    appearTimer = appearTimer + dt

    if appearTimer >= appearTime then
      appearTimer = nil
      return
    end

    local scanRadiusLerped = interp.sin(appearTimer / appearTime, 0, scanRadius)
    local tileSofteningRadiusLerped = interp.sin(appearTimer / appearTime, 0, tileSofteningRadius)
    monster.setAnimationParameter("riftSize", scanRadiusLerped)

    updateMatMods(scanRadiusLerped)

    applyRiftDestabilization(scanRadiusLerped)
    applySoftenedTiles(tileSofteningRadiusLerped)
  else
    mcontroller.setVelocity(config.getParameter("movementVelocity", {0, 0}))

    updateMatMods(scanRadius)

    applyRiftDestabilization(scanRadius)
    applySoftenedTiles(tileSofteningRadius)
  end
end

function applyRiftDestabilization(radius)
  local queried = world.entityQuery(mcontroller.position(), radius, {
    includedTypes = {"creature"},
    withoutEntityId = entity.id()
  })

  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "applyStatusEffect", "v-riftdestabilization")
  end
end

function applySoftenedTiles(radius)
  local queried = world.entityQuery(mcontroller.position(), radius, {
    includedTypes = {"player"},
    withoutEntityId = entity.id()
  })

  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "applyStatusEffect", "v-softenedtiles")
  end
end

function updateMatMods(radius)
  radius = math.floor(radius)
  local ownPos = vec2.floor(mcontroller.position())
  world.debugPoint(ownPos, "green")

  for x = -radius, radius do
    for y = -radius, radius do
      local frontScanPos = vec2.add(ownPos, {x, y})

      local frontScanDist = world.magnitude(ownPos, frontScanPos)
      local frontScanDist2 = world.magnitude(prevPos, frontScanPos)
      if frontScanDist <= radius and frontScanDist2 > prevRadius then
        world.debugPoint(frontScanPos, "green")
        attemptPlaceMatMod(frontScanPos)
      end
    end
  end

  for x = -radius, radius do
    for y = -radius, radius do
      local backScanPos = vec2.add(ownPos, {x, y})

      local backScanDist = world.magnitude(ownPos, backScanPos)
      local backScanDist2 = world.magnitude(prevPos, backScanPos)
      if backScanDist > radius and backScanDist2 <= prevRadius then
        world.debugPoint(backScanPos, "green")
        attemptRemoveMatMod(backScanPos)
      end
    end
  end

  prevPos = ownPos
  prevRadius = radius
end

function attemptPlaceMatMod(pos)
  if world.mod(pos, "foreground") == invisibleOre then
    world.placeMod(pos, "foreground", visibleOre)
  end
end

function attemptRemoveMatMod(pos)
  if world.mod(pos, "foreground") == visibleOre then
    world.placeMod(pos, "foreground", invisibleOre)
  end
end

function shouldDie()
  return false
end