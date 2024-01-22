require "/items/buildscripts/v-extrabuildfuncs.lua"

function build(directory, config, parameters, level, seed)
  return applyExtraBuildFuncs(directory, config, parameters, level, seed)
end