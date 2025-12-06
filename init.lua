--- === hs._dtc.xml ===
---
--- Simplistic XML support for Hammerspoon

local USERDATA_TAG = "hs._dtc.xml"
local module = require(USERDATA_TAG .. ".internal")

-- Register documentation if available
local basePath = package.searchpath(USERDATA_TAG, package.path)
if basePath then
    basePath = basePath:match("^(.+)/init.lua$")
    if basePath and require("hs.fs").attributes(basePath .. "/docs.json") then
        require("hs.doc").registerJSONFile(basePath .. "/docs.json")
    end
end

local public = {
    constants = module._getConstants(),
}

for k, v in pairs(module) do
    if k:sub(1, 1) ~= "_" then
        public[k] = v
    end
end

return public;
