module Zena
  # This exception occurs when we have configuration problems.
  class BadConfiguration < Exception
  end
end

class ActiveRecord::Base
  def self.act_as_content
    class_eval do
      def preload_version(v)
        @version = v
      end
  
      def version
        @version ||= Version.find(self[:version_id])
      end
    end
  end
end

load_patches_from_bricks