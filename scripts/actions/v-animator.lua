require "/scripts/v-behavior.lua"
require "/scripts/util.lua"

-- param beamName
-- param active
function v_setLaserBeamActive(args)
  local rq = vBehavior.requireArgsGen("v_setLaserBeamActive", args)

  if not rq{"beamName", "active"} then return false end

  -- If the arguments specify to set the beam to active and the beam name is not already in enabledLaserBeams...
  if args.active and not contains(self.enabledLaserBeams, args.beamName) then
    -- Add it to the list of enabled beams.
    table.insert(self.enabledLaserBeams, args.beamName)
  -- Otherwise, if the arguments specify to set the beam to inactive...
  elseif not args.active then
    -- Delete the beam name from the list of enabled beams.
    self.enabledLaserBeams = util.filter(self.enabledLaserBeams, function(x) return x ~= args.beamName end)
  end
  -- Update the parameter.
  monster.setAnimationParameter("enabledBeams", self.enabledLaserBeams)

  return true
end