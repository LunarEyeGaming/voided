local oldClearAnimation = clearAnimation or function() end

function clearAnimation()
  mcontroller.controlParameters({gravityEnabled = true})

  oldClearAnimation()
end

-- From terraliblite/scripts/terra_wormheadcustom.lua
function takeDamage(damageRequest)
  status.applySelfDamageRequest(damageRequest)
end