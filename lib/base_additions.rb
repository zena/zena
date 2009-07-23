module Zena
  # This exception occurs when we have configuration problems.
  class BadConfiguration < Exception
  end
end

Bricks::Patcher.apply_patches