local mod = {}

-- Called once after all game and mod resources are loaded.
-- For now it only logs, so you can confirm in the in-game console that the mod is active.
mod.postRunFn = function(_captureParams, _configDict : {{string, string}}, _allModParams : {string : {string : integer}})
	log.message("[nulldozzer_gradients] loaded")
end

return mod
