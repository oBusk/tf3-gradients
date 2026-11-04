-- Teal configuration for editor autocompletion and type checking.
-- Based on <tf3_install_folder>/vscode-template/tlconfig.lua shipped with the game.
-- Adjust the path below if Transport Fever 3 is not installed in the default Steam library.
local tf3 = "C:/Program Files (x86)/Steam/steamapps/common/Transport Fever 3/"

return {
	include_dir = {
		tf3 .. "api/tealdef",
		tf3 .. "base/tealdef",
		"nulldozzer_gradients/content/gui/nulldozzer_gradients",
	},
	global_env_def = "all_def",
}
