local sounds

function init()
  sounds = config.getParameter("sounds")
end

function update(dt)

end

function dismissed()
  for _,sound in pairs(sounds) do
    pane.stopAllSounds(sound)
  end
end