require 'fileutils'
# load all fixtures and setup fixture_accessors:
FIXTURE_PATH = File.join(File.dirname(__FILE__), 'fixtures')
FILE_FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures', 'files')
# We use transactional fixtures with a single load for ALL tests (this is not the default rails implementation). Tests are now 5x-10x faster.
module Zena
  module Test
    module LoadFixtures
      # make sure versions is of type InnoDB
      begin
        Node.connection.remove_index "versions", ["title", "text", "summary"]
      rescue ActiveRecord::StatementInvalid
      ensure
        Node.connection.execute "ALTER TABLE versions ENGINE = InnoDB;"
      end
      @@loaded_fixtures = {}
      fixture_table_names = []
      Dir.foreach(FIXTURE_PATH) do |file|
        next unless file =~ /^(.+)\.yml$/
        table_name = $1
        fixture_table_names << table_name
        define_method(table_name) do |fixture|
          if @@loaded_fixtures[table_name][fixture.to_s]
            # allways reload
            @@loaded_fixtures[table_name][fixture.to_s].find
          else
            raise StandardError, "No fixture with name '#{fixture}' found for table '#{table_name}'"
          end
        end
        define_method(table_name + "_id") do |fixture|
          if @@loaded_fixtures[table_name][fixture.to_s]
            @@loaded_fixtures[table_name][fixture.to_s].instance_eval { @fixture['id'].to_i }
          else
            raise StandardError, "No fixture with name '#{fixture}' found for table '#{table_name}'"
          end
        end
        
        if table_name == 'nodes' || table_name == 'zips'
          define_method(table_name + "_zip") do |fixture|
            if @@loaded_fixtures[table_name][fixture.to_s]
              @@loaded_fixtures[table_name][fixture.to_s].instance_eval { @fixture['zip'].to_i }
            else
              raise StandardError, "No fixture with name '#{fixture}' found for table '#{table_name}'"
            end
          end
        end
      end

      fixtures = Fixtures.create_fixtures(FIXTURE_PATH, fixture_table_names)
      unless fixtures.nil?
        if fixtures.instance_of?(Fixtures)
          @@loaded_fixtures[fixtures.table_name] = fixtures
        else
          fixtures.each { |f| @@loaded_fixtures[f.table_name] = f }
        end
      end

      unless File.exist?("#{SITES_ROOT}/test.host/data")
        @@loaded_fixtures['document_contents'].each do |name,fixture|
          path = fixture.instance_eval { [@fixture['ext'],@fixture['version_id'].to_s,@fixture['name']+"."+@fixture['ext']] }
          name = path.pop
          FileUtils::mkpath(File.join(RAILS_ROOT,'sites', 'test.host', 'data', *path))
          path << name
          if File.exist?(File.join(FILE_FIXTURES_PATH,name))
            FileUtils::cp(File.join(FILE_FIXTURES_PATH,name),File.join(RAILS_ROOT,'sites', 'test.host', 'data', *path))
          end
        end
      end
    end
    
    module Base
      
      def preserving_files(path, &block)
        path = "/#{path}" unless path[0..0] == '/'
        if File.exist?("#{SITES_ROOT}#{path}")
          FileUtils::cp_r("#{SITES_ROOT}#{path}","#{SITES_ROOT}#{path}.bak")
          move_back = true
        else
          move_back = false
        end
        begin
          yield
        ensure
          FileUtils::rmtree("#{SITES_ROOT}#{path}")
          if move_back
            FileUtils::mv("#{SITES_ROOT}#{path}.bak","#{SITES_ROOT}#{path}")
          end
        end
      end

      def without_files(path, &block)
        path = "/#{path}" unless path[0..0] == '/'
        if File.exist?("#{SITES_ROOT}#{path}")
          FileUtils::mv("#{SITES_ROOT}#{path}","#{SITES_ROOT}#{path}.bak")
          move_back = true
        else
          move_back = false
        end
        begin
          yield
        ensure
          FileUtils::rmtree("#{SITES_ROOT}#{path}")
          if move_back
            FileUtils::mv("#{SITES_ROOT}#{path}.bak","#{SITES_ROOT}#{path}")
          end
        end
      end
      
      def with_caching
        @perform_caching_bak = ApplicationController.perform_caching
        ApplicationController.perform_caching = true
        Cache.perform_caching = true
        CachedPage.perform_caching = true
        yield
      ensure
        Cache.perform_caching = @perform_caching_bak
        CachedPage.perform_caching = @perform_caching_bak
        ApplicationController.perform_caching = @perform_caching_bak
      end

      # taken from http://manuals.rubyonrails.com/read/chapter/28#page237 with some modifications
      def uploaded_file(fname, content_type="application/octet-stream", filename=nil)
        path = File.join(FILE_FIXTURES_PATH, fname)
        filename ||= File.basename(path)
        # simulate small files with StringIO
        if File.stat(path).size < 1024
          # smaller then 1 Ko
          t = StringIO.new(File.read(path))
        else
          t = Tempfile.new(fname)
          FileUtils.copy_file(path, t.path)
        end
        (class << t; self; end;).class_eval do
          alias local_path path if defined?(:path)
          define_method(:original_filename) { filename }
          define_method(:content_type) { content_type }
        end
        return t
      end

      # JPEG helper
      def uploaded_jpg(fname, filename=nil)
        uploaded_file(fname, 'image/jpeg', filename)
      end

      # PDF helper
      def uploaded_pdf(fname, filename=nil)
        uploaded_file(fname, 'application/pdf', filename)
      end

      # TEXT helper
      def uploaded_text(fname, filename=nil)
        uploaded_file(fname, 'text/plain', filename)
      end

      # PNG helper
      def uploaded_png(fname, filename=nil)
        uploaded_file(fname, 'image/png', filename)
      end

      # TGZ helper
      def uploaded_archive(fname, filename=nil)
        uploaded_file(fname, 'application/x-gzip', filename)
      end

    end
    
    module Unit
      include Zena::Test::LoadFixtures
      include Zena::Test::Base
      include Zena::Acts::Secure
      
      # Set visitor for unit testing
      def login(name='anon')
        # set site (find first matching site)
        site = Site.find(:first, :select=>"sites.*", :from => "sites, participations",
                         :conditions=>["participations.site_id = sites.id AND participations.user_id = ?", users_id(name)])
        visitor = User.make_visitor(:site => site, :id => users_id(name))
        visitor.ip = '10.0.0.127'
        GetText.set_locale_all visitor.lang
      end

      def err(obj)
        obj.errors.each do |er,msg|
          puts "[#{er}] #{msg}"
        end
      end
    end

    module TestController
      include Zena::Test::LoadFixtures
      include Zena::Test::Base

      def init_controller
        @request    = ActionController::TestRequest.new
        @response   = ActionController::TestResponse.new
        @controller.instance_eval { @params = {}; @url = ActionController::UrlRewriter.new( @request, {} )}
        @controller.instance_variable_set(:@response, @response)
        @controller.send(:request=, @request)
        @controller.instance_variable_set(:@session, @request.session)
      end

      def login(visitor=:anon)
        return logout if visitor == :anon
        @controller_bak = @controller
        @controller = SessionController.new
        post 'create', :login=>visitor.to_s, :password=>visitor.to_s
        sess = @controller.send(:session)
        @controller_bak.send(:session=, sess )
        @controller_bak.instance_variable_set(:@visitor, nil ) # clear cached visitor
        @controller = @controller_bak
      end

      def logout
        @controller_bak = @controller
        @controller = SessionController.new
        post 'destroy'
        @controller_bak.send(:session=,@controller.send(:session))
        @controller_bak.instance_variable_set(:@visitor,nil) # clear cached visitor
        @controller = @controller_bak
      end

      def session
        @controller.send(:session)
      end
      
      def flash
        session['flash']
      end

      def err(obj)
        obj.errors.each do |er,msg|
          puts "[#{er}] #{msg}"
        end
      end

      def method_missing(meth,*args, &block)
        @controller.send(meth, *args, &block)
      end
    end
    
    module Integration
      include Zena::Acts::Secure
    end

    module HelperSetup
      def setup(request, response, url)
        GetText.set_locale_all 'en'
        @request = request
        @url = url
        initialize_template_class(response)
        assign_shortcuts(request, response)
        initialize_current_url
        assign_names
      end
      def set_params(hash)
        @_params = hash
        @request.instance_variable_set(:@parameters,hash)
        @url = ActionController::UrlRewriter.new(@request, hash)
      end
      def rescue_action(e) raise e; end;
    end

    module TestHelper
      include Zena::Test::LoadFixtures
      include Zena::Test::Base
      attr_accessor :flash, :controller

      include ActionView::Helpers::ActiveRecordHelper
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::FormTagHelper
      include ActionView::Helpers::FormOptionsHelper
      include ActionView::Helpers::FormHelper
      include ActionView::Helpers::UrlHelper
      include ActionView::Helpers::AssetTagHelper
      include ActionView::Helpers::PrototypeHelper

      def setup
        GetText.set_locale_all 'en'
        @controllerClass ||= ApplicationController
        self.class.send(:include,@controllerClass.master_helper_module)
        eval "class StubController < #{@controllerClass}; include Zena::Test::HelperSetup; end"
        super

        @request    = ActionController::TestRequest.new
        @response   = ActionController::TestResponse.new
        @controller = StubController.new
        # Fake url rewriter so we can test url_for
        @url     = ActionController::UrlRewriter.new @request, {}
        @controller.setup(@request, @response, @url)
        @flash = {}
        ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
        
      end

      # login for helper testing
      def login(name=:anon)
        return logout if name == :anon
        @controller_bak = @controller
        @controller = SessionController.new
        post 'create', :login=>name.to_s, :password=>name.to_s
        @controller_bak.send(:session=,@controller.send(:session))
        @controller_bak.instance_variable_set(:@visitor,nil) # clear cached visitor
        @controller = @controller_bak
      end

      def logout
        @controller_bak = @controller
        @controller = SessionController.new
        post 'destroy'
        @controller_bak.send(:session=,@controller.send(:session))
        @controller_bak.instance_variable_set(:@visitor,nil) # clear cached visitor
        @controller = @controller_bak
      end

      def secure(*args, &block)
        @controller.send(:secure, *args, &block)
      end

      def err(obj)
        obj.errors.each do |er,msg|
          puts "[#{er}] #{msg}"
        end
      end
      
      # methods for accessing the controller:
      def visitor
        @controller.send(:visitor)
      end
      
      def params
        @controller.send(:params)
      end
    end
  end
end

class Test::Unit::TestCase
  # we have to overwrite the 'default_test' dummy because we use sub-classes
  undef default_test
end

class ZenaTestUnit < Test::Unit::TestCase
  include Zena::Test::Unit
  def setup; super; User.make_visitor(:host=>'test.host', :id=>users_id(:anon)); end
  def self.use_transactional_fixtures; true; end
  def self.use_instantiated_fixtures; false; end
end

class ZenaTestHelper < Test::Unit::TestCase
  include Zena::Test::TestHelper
  def self.use_transactional_fixtures; true; end
  def self.use_instantiated_fixtures; false; end
end

class ZenaTestController < Test::Unit::TestCase
  include Zena::Test::TestController
  def self.use_transactional_fixtures; true; end
  def self.use_instantiated_fixtures; false; end
end