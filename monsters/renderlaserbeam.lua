local oldInit = init

function init()
  oldInit()
  monster.setAnimationParameter("beams", config.getParameter("beams"))

  local enabledBeams = config.getParameter("enabledBeams")

  if enabledBeams then
    self.enabledLaserBeams = enabledBeams
  else
    -- Enabled beams is, by default, all beams with names.
    self.enabledLaserBeams = {}
    for _, beam in ipairs(config.getParameter("beams")) do
      if beam.name then
        table.insert(self.enabledLaserBeams, beam.name)
      end
    end
  end
  monster.setAnimationParameter("enabledBeams", self.enabledLaserBeams)
end