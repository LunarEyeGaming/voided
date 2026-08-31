local playedSound

function init()
end

function update(dt)
  if not playedSound then
    local args = config.getParameter("args")
    widget.playSound(args.sound, args.loops, args.volume)
    pane.dismiss()
    playedSound = true
  end
end