function init()
  local args = config.getParameter("args")
  widget.playSound(args.sound, args.loops, args.volume)
  pane.dismiss()
end