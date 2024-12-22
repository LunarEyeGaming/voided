require "/scripts/util.lua"
require "/scripts/staticrandom.lua"
require "/items/buildscripts/v-extrabuildfuncs.lua"
require "/scripts/v-util.lua"

function build(directory, config, parameters, level, seed)
  -- Responsible for baking the randomness into the item so that the values never change for a singular item.
  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
      return parameters[keyName]
    elseif config[keyName] ~= nil then
      return config[keyName]
    else
      return defaultValue
    end
  end

  -- initialize randomization
  if seed then
    parameters.seed = seed
  else
    seed = configParameter("seed")
    if not seed then
      math.randomseed(util.seedTime())
      seed = math.random(1, 4294967295)
      parameters.seed = seed
    end
  end

  -- Get parameters
  local baseNoteTextChoices = configParameter("noteTextChoices")
  local obfuscationChance = configParameter("obfuscationChance")
  local obfuscationCharacter = configParameter("obfuscationCharacter")
  local expectedCoordLength = configParameter("expectedCoordLength")

  -- Choose a random note text.
  local baseNoteText = randomFromList(baseNoteTextChoices, seed, "baseNoteText")
  -- Obfuscate the text and set config.noteText to be it.
  config.noteText = vUtil.obfuscateString(baseNoteText, makeRandomBoolTable(seed, #baseNoteText, obfuscationChance), obfuscationCharacter)

  -- Generate X and Y obfuscation values. We use a different method of generating noise so that we never get all blanks
  -- (which can be very frustrating, especially when it happens multiple times in a row).
  local obfuscatedDigits = makeRandomBoolTable(seed, expectedCoordLength * 2, obfuscationChance)
  config.obfuscatedDigits = {
    -- Split table.
    sliceTable(obfuscatedDigits, 1, expectedCoordLength),
    sliceTable(obfuscatedDigits, expectedCoordLength + 1, expectedCoordLength * 2)
  }

  return applyExtraBuildFuncs(directory, config, parameters, level, seed)
end

--[[
  Returns a table of random boolean values with length `count` based on a `seed`. The probability of any value in the
  table being true is `trueProb`, and for it to be false, it has a probability of `1 - trueProb`.
]]
function makeRandomBoolTable(seed, count, trueProb)
  local randGen = sb.makeRandomSource(seed)
  local result = {}

  for i = 1, count do
    local testVar = randGen:randf()
    table.insert(result, testVar <= trueProb)
  end

  return result
end

--[[
  sliceTable(tbl, start, end_) is equal to the elements of `tbl` from `start` to `end_`.

  Precondition: `start` and `end_` represent indices within the table.
]]
function sliceTable(tbl, start, end_)
  local newTbl = {}
  for i = start, end_ do
    table.insert(newTbl, tbl[i])
  end

  return newTbl
end

--[[
  The same as the util.shuffle function, but with an engine random number generator `gen` as input to keep things
  deterministic.
]]
function sbShuffle(list, gen)
  -- Fisher-Yates shuffle
  if #list < 2 then return end
  for i = #list, 2, -1 do
    -- Make a random float between 0 and i + 1 (exclusive) and floor it to emulate math.random(i)
    local j = math.floor(gen:randf(0, i + 1))
    local tmp = list[j]
    list[j] = list[i]
    list[i] = tmp
  end
end