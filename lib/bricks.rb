require 'bricks/raw_config'
require 'bricks/requirements_validation'
require 'bricks/loader'

module Bricks
  extend Bricks::RequirementsValidation
  extend Bricks::Loader
  CONFIG = self.config_for_active_bricks
end

