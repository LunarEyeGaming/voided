require "/scripts/projectiles/v-mergergeneric.lua"

local teleportQueryRange
local teleportStatusEffect
local teleportDelay
local mergerType
local mergeRange
local exitId

local merger  ---@type VMerger

local teleportTimer

function init()
  teleportQueryRange = config.getParameter("teleportQueryRange")
  teleportStatusEffect = config.getParameter("teleportStatusEffect")
  teleportDelay = config.getParameter("teleportDelay", 0)
  mergerType = config.getParameter("mergerType")
  mergeRange = config.getParameter("mergeRange")
  exitId = config.getParameter("linkingNode")

  -- merger = VMerger:new(mergerType, mergeRange, false, true)

  teleportTimer = teleportDelay
end

function update(dt)
  -- merger:process()
end

function destroy()
end