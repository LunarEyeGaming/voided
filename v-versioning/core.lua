function init()
  if not storage.versions then
    storage.versions = {}
  end
  local versions = storage.versions

  local cfg = root.assetJson("/v-versioning.config")

  for name, version in pairs(cfg) do
    -- If an entry in versions is not defined, set it to the one in cfg without doing anything.
    if not versions[name] then
      versions[name] = version
    -- Otherwise, if it is defined and it is less than the one in cfg, run the associated patch module(s) to update from
    -- the previous version to the current version.
    elseif versions[name] < version then
      local get, set = getVersionProperty(name)

      local data = get()

      local iterVersion = versions[name]
      repeat
        -- Load patch module
        require(string.format("/v-versioning/%s_%d_%d.lua", name, iterVersion, iterVersion + 1))

        -- Run it.
        data = update_(data)

        iterVersion = iterVersion + 1
      until iterVersion >= version

      set(data)
    end
  end
end

---Returns a version property's getter and setter.
---@param name string
---@return fun(): any
---@return fun(v: any)
function getVersionProperty(name)
  local versionProp = versionProperties[name]

  return versionProp.get, versionProp.set
end

versionProperties = {}

versionProperties.MinistarRenderConfig = {
  get = function()
    return player.getProperty("v-ministareffects-renderConfig")
  end,
  set = function(v)
    player.setProperty("v-ministareffects-renderConfig", v)
  end
}