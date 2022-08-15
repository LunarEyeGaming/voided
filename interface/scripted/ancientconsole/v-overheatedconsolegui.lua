local activateItem
local required

function init()
  activateItem = config.getParameter("activateItem")
  required = config.getParameter("requiredCount")

  update()
end

function update(dt)
  local current = player.hasCountOfItem(activateItem)
  widget.setText("costLabel", string.format("%s / %s", current, required))
  widget.setFontColor("costLabel", current >= required and {255, 255, 255} or {255, 0, 0})
  widget.setButtonEnabled("activateButton", current >= required)
end

function cooldown()
  if player.consumeItem({name = activateItem, count = required}) then
    world.sendEntityMessage(pane.sourceEntity(), "cooldown")
    pane.dismiss()
  end
end
