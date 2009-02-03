
# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

# Load zena specific settings
require File.join(File.dirname(__FILE__), 'zena')
require File.join(File.dirname(__FILE__), 'version')

Rails::Initializer.run do |config|

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )
  config.load_paths += Dir["#{RAILS_ROOT}/vendor/gems/**"].map do |dir|
    File.directory?(lib = "#{dir}/lib") ? lib : dir
  end
  
  config.load_paths += Dir["#{RAILS_ROOT}/bricks/**/models"]
  
  # Use the database for sessions instead of the file system
  # (create the session table with 'rake db:sessions:create')
  # config.action_controller.session_store = :active_record_store
  config.action_controller.session = {
    :session_key => 'zena_session',                # min 30 chars
    :secret      => 'jkfawe0[y9wrohifashaksfi934jas09455ohifnksdklh'
  }

  # Make Active Record use UTC-base instead of local time
  # do not change this !
  config.active_record.default_timezone = :utc
  ENV['TZ'] = 'UTC'
end

Inflector.inflections do |inflect|
  inflect.uncountable %w( children )
end

lib_path = File.join(File.dirname(__FILE__), '../lib')
require File.join(lib_path, 'secure')
require File.join(lib_path, 'multiversion')
require File.join(lib_path, 'has_relations')
require File.join(lib_path, 'image_builder')
Dir.foreach(File.join(lib_path, 'core_ext')) do |f|
  next if f[0..0] == '.'
  require File.join(lib_path, 'core_ext', f)
end
require File.join(lib_path, 'parser')
require File.join(lib_path, 'base_additions')
require File.join(lib_path, 'use_find_helpers')
require File.join(lib_path, 'use_zafu')
require File.join(lib_path, 'node_query')
require File.join(lib_path, 'comment_query')
ZazenParser = Parser.parser_with_rules(Zazen::Rules, Zazen::Tags)
ZafuParser  = Parser.parser_with_rules(Zafu::Rules, Zena::Rules, Zafu::Tags, Zena::Tags)

require 'diff'

foreach_brick do |brick_path|
  lib_path = File.join(brick_path, 'lib')
  next unless File.exist?(lib_path) && File.directory?(lib_path)
  Dir.foreach(lib_path) do |f|
    next unless f =~ /\A.+\.rb\Z/
    require File.join(lib_path, f)
  end
end

# FIXME: this should go into "adapters_ext"
# Fixes #98
module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapter
      def connect
        encoding = @config[:encoding]
        if encoding
          @connection.options(Mysql::SET_CHARSET_NAME, encoding) rescue nil
        end
        @connection.ssl_set(@config[:sslkey], @config[:sslcert], @config[:sslca], @config[:sslcapath], @config[:sslcipher]) if @config[:sslkey]
        @connection.real_connect(*@connection_options)
        execute("SET NAMES '#{encoding}'") if encoding

        # By default, MySQL 'where id is null' selects the last inserted id.
        # Turn this off. http://dev.rubyonrails.org/ticket/6778
        if (Base.default_timezone == :utc) 
          execute("SET time_zone = '+0:0'") 
        end
         	
        execute("SET SQL_AUTO_IS_NULL=0")
      end
    end
  end
end