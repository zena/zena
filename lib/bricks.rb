require 'bricks/requirements_validation'
require 'bricks/loader'
require 'bricks/helper'

module Bricks
  extend Bricks::RequirementsValidation
  extend Bricks::Loader
  extend Bricks::Helper
  CONFIG = self.config_for_active_bricks
end

