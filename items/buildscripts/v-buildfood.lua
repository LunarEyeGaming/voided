-- require "/scripts/util.lua"
-- require "/scripts/vec2.lua"
-- require "/scripts/versioningutils.lua"
-- require "/items/buildscripts/abilities.lua"
require "/items/buildscripts/v-extrabuildfuncs.lua"
require "/items/buildscripts/buildfood.lua"

local oldBuild = build

function build(directory, config, parameters, level, seed)
  config, parameters = oldBuild(directory, config, parameters, level, seed)

  return applyExtraBuildFuncs(directory, config, parameters, level, seed)
end
