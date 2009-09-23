# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.4' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')


Rails::Initializer.run do |config|
  config.action_controller.session = {
    :session_key => 'zena_session',                # min 30 chars
    :secret      => 'jkfawe0[y9wrohifashaksfi934jas09455ohifnksdklh'
  }
end
