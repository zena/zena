# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.4' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

#class String
#  alias :__old_format_m :%
#  def %(hash = {})
#    if hash.kind_of?(Hash)
#      ret = dup
#      hash.keys.each do |key, value|
#        ret.gsub!("\%\{#{key}\}", value.to_s)
#      end
#      return ret
#    else
#      ret = gsub(/%\{/, '%%{')
#      ret.__old_format_m(hash)
#    end
#  end
#end

# avoids ActionView::Helpers::TextHelpers to load RedCloth before we do with our frozen gem
class RedCloth < String; end

Rails::Initializer.run do |config|
  config.action_controller.session = {
    :session_key => 'zena_session',                # min 30 chars
    :secret      => 'jkfawe0[y9wrohifashaksfi934jas09455ohifnksdklh'
  }
end

ActiveSupport::Inflector.inflections do |inflect|
  inflect.uncountable %w( children )
end
