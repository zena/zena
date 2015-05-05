# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.18' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|

  # We need to explicitly require tzinfo or we get weird erro.
  # TZInfo::InvalidTimezoneIdentifier: no such file to load -- tzinfo/definitions/UTC
  require 'tzinfo'

  config.action_controller.session = {
    :key    => 'zena_session',                # min 30 chars
    :secret => 'jkfawe0[y9wrohifashaksfi934jas09455ohifnksdklh'
  }
  config.action_controller.session_store = :active_record_store
end
