require "/scripts/util.lua"
require "/scripts/v-animator.lua"

local oldInit = init or function() end

function init()
  oldInit()

  -- Apply palette swaps depending on the current world type.

  local paletteSwap = getElementalPaletteSwap(world.type())

  if paletteSwap then
    local directives = vAnimator.paletteSwapToString(paletteSwap)

    animator.setGlobalTag("directives", directives)
  else
    animator.setGlobalTag("directives", "")
  end
end

---Returns a palette swap for the current world type, or `nil` if not found.
---@param worldType string
---@return table<Color, Color>?
function getElementalPaletteSwap(worldType)
  local elementalPaletteSwaps = config.getParameter("elementalPaletteSwaps")

  -- Find the first set of palette swaps that contains the given world type.
  for _, paletteSwap in ipairs(elementalPaletteSwaps) do
    if contains(paletteSwap.worldTypes, worldType) then
      return paletteSwap.swaps
    end
  end

  return nil
end