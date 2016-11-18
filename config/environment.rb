# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.18' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

module Gem
  def self.source_index
    sources
  end

  def self.cache
    sources
  end

  SourceIndex = Specification

  class SourceList
    # If you want vendor gems, this is where to start writing code.
    def search(*args); []; end
    def each(&block); end
    include Enumerable
  end
end


Rails::Initializer.run do |config|

  # We need to explicitly require tzinfo or we get weird erro.
  # TZInfo::InvalidTimezoneIdentifier: no such file to load -- tzinfo/definitions/UTC
  require 'tzinfo'

  config.action_controller.session = {
    :key    => 'zena_session',                # min 30 chars
    :secret => 'jkfawe0[y9wrohifashaksfi934jas09455ohifnksdklh'
  }
  config.action_controller.session_store = :active_record_store

  config.i18n.available_locales = [:fr, :de, :en, :it]
end
