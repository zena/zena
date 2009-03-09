# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.2.2' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

# Load zena specific settings
# FIXME: should not be needed (not like this)
require File.join(File.dirname(__FILE__), 'zena')
require File.join(File.dirname(__FILE__), 'version')


#FIXME: remove all these hacks !
lib_path = File.join(File.dirname(__FILE__), '../lib')
Dir.foreach(File.join(lib_path, 'core_ext')) do |f|
  next if f[0..0] == '.'
  require File.join(lib_path, 'core_ext', f)
end

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

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )
  # config.load_paths += Dir["#{RAILS_ROOT}/vendor/gems/**"].map do |dir|
  #   File.directory?(lib = "#{dir}/lib") ? lib : dir
  # end
  
  config.load_paths += Dir["#{RAILS_ROOT}/bricks/**/models"]
  
  # Use the database for sessions instead of the file system
  # (create the session table with 'rake db:sessions:create')
  # config.action_controller.session_store = :active_record_store
  config.action_controller.session = {
    :session_key => 'zena_session',                # min 30 chars
    :secret      => 'jkfawe0[y9wrohifashaksfi934jas09455ohifnksdklh'
  }
  
  config.gem 'recaptcha', :version => '0.1.48'
  config.gem 'RedCloth',  :version => '3.0.4'
  config.gem "grosser-fast_gettext", :lib => 'fast_gettext', :version => '~>0.2.10', :source=>"http://gems.github.com/"
  config.gem 'mislav-will_paginate', :version => '~> 2.2.3', :lib => 'will_paginate', :source => 'http://gems.github.com'
  
  # TODO: uncomment this line when remarkable stops loading spec/rails or when spec/rails stops messing unit tests. (http://carlosbrando.lighthouseapp.com/projects/19775-remarkable/tickets/14-breaks-testunit-tests#ticket-14-5)
  #config.gem "carlosbrando-remarkable", :lib => "remarkable", :source => "http://gems.github.com"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # do not change this !
  config.active_record.default_timezone = :utc
  ENV['TZ'] = 'UTC'
end

FastGettext.add_text_domain 'zena', :path => 'locale'

ActiveSupport::Inflector.inflections do |inflect|
  inflect.uncountable %w( children )
end

ZazenParser = Parser.parser_with_rules(Zazen::Rules, Zazen::Tags)
ZafuParser  = Parser.parser_with_rules(Zafu::Rules, Zena::Rules, Zafu::Tags, Zena::Tags)

=begin
#FIXME: remove all these hacks !
require File.join(lib_path, 'secure')
require File.join(lib_path, 'multiversion')
require File.join(lib_path, 'has_relations')
require File.join(lib_path, 'image_builder')

require File.join(lib_path, 'parser')
require File.join(lib_path, 'base_additions')
require File.join(lib_path, 'use_find_helpers')
require File.join(lib_path, 'use_zafu')
require File.join(lib_path, 'node_query')
require File.join(lib_path, 'comment_query')

require 'diff'

=end