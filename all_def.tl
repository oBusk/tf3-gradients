-- Global type definitions for the editor, as in the game's vscode-template.
require "api_def"
require "content_def"

-- The mod's own module definitions. Dependencies first: later files use types from earlier ones.
require "point_grid"
require "edge_profile"
require "network_scan"
require "gradient_scale"
require "gradient_tooltip"
