function init()
  effect.addStatModifierGroup({
    {stat = "protection", amount = config.getParameter("boostAmount", 0)},
  })
end