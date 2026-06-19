function patch(config)
  config.description = config.description:gsub("%^blue;%[Special 2%]", "^green;[LShift]")

  return config
end