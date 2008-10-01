require 'fileutils'
# load all fixtures and setup fixture_accessors:
FIXTURE_PATH = File.join(File.dirname(__FILE__), 'fixtures')
FILE_FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures', 'files')
# We use transactional fixtures with a single load for ALL tests (this is not the default rails implementation). Tests are now 5x-10x faster.
module Zena
  module Test
    module LoadFixtures
      
      # Could DRY with file_path defined in Base
      def self.file_path(filename, content_id)
        digest = Digest::SHA1.hexdigest(content_id.to_s)
        fname = filename.split('.').first
        "#{SITES_ROOT}/test.host/data/full/#{digest[0..0]}/#{digest[1..1]}/#{digest[2..2]}/#{fname}"
      end
      
      # make sure versions is of type InnoDB
      begin
        Node.connection.remove_index "versions", ["title", "text", "summary"]
      rescue ActiveRecord::StatementInvalid
      ensure
        Node.connection.execute "ALTER TABLE versions ENGINE = InnoDB;"
      end
      @@loaded_fixtures = {}
      fixture_table_names = []
      
      # no fixtures ? execute rake task
      unless File.exist?(File.join(FIXTURE_PATH, 'nodes.yml'))
        puts "No fixtures in 'test/fixtures'. Building from 'test/sites'."
        `cd #{RAILS_ROOT} && rake zena:build_fixtures`
      end
      
      Dir.foreach(FIXTURE_PATH) do |file|
        next unless file =~ /^(.+)\.yml$/
        table_name = $1
        fixture_table_names << table_name
        
        if ['users', 'sites'].include?(table_name)
          
          define_method(table_name) do |fixture|
            if @@loaded_fixtures[table_name][fixture.to_s]
              # allways reload
              @@loaded_fixtures[table_name][fixture.to_s].find
            else
              raise StandardError, "No fixture with name '#{fixture}' found for table '#{table_name}'"
            end
          end
          
          define_method(table_name + "_id") do |fixture|
            ZenaTest::multi_site_id(fixture)
          end
        else
          
          define_method(table_name) do |fixture|
            fixture_name = "#{$_test_site}_#{fixture}"
            if fix = @@loaded_fixtures[table_name][fixture_name]
              # allways reload
              fix.find
            else
              raise StandardError, "No fixture with name '#{fixture_name}' found for table '#{table_name}' in site '#{$_test_site}'."
            end
          end
          
          define_method(table_name + "_id") do |fixture|
            ZenaTest::id($_test_site, fixture)
          end
        end
        
        if table_name == 'nodes' || table_name == 'zips'
          define_method(table_name + "_zip") do |fixture|
            # needed by additions_test
            fixture_name = table_name == 'zips' ? fixture.to_s : "#{$_test_site}_#{fixture}"
            if fix = @@loaded_fixtures[table_name][fixture_name]
              fix.instance_eval { @fixture['zip'].to_i }
            else
              raise StandardError, "No fixture with name '#{fixture_name}' found for table '#{table_name}'"
            end
          end
        end
        
        if table_name == 'sites'
          define_method("#{table_name}_host") do |fixture|
            if fix = @@loaded_fixtures[table_name][fixture]
              fix.instance_eval { @fixture['host'] }
            else
              raise StandardError, "No fixture with name '#{fixture}' found for '#{table_name}'"
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
          fname, content_id = fixture.instance_eval { [@fixture['name']+"."+@fixture['ext'], @fixture['id'].to_s] }
          path = file_path(fname, content_id)
          FileUtils::mkpath(File.dirname(path))
          if File.exist?(File.join(FILE_FIXTURES_PATH,fname))
            FileUtils::cp(File.join(FILE_FIXTURES_PATH,fname),path)
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

      # ZIP helper
      def uploaded_zip(fname, filename=nil)
        uploaded_file(fname, 'application/zip', filename)
      end

      def file_path(filename, mode = 'full', content_id = nil)
        if content_id
          fname = filename.split('.').first
        else
          if content_id = document_contents_id(filename.to_sym)
            fname = filename.to_s.split('_').first
          else
            puts "#{filename.inspect} fixture not found in document_contents"
            return nil
          end
        end
        digest = Digest::SHA1.hexdigest(content_id.to_s)
        "#{SITES_ROOT}/test.host/data/#{mode}/#{digest[0..0]}/#{digest[1..1]}/#{digest[2..2]}/#{fname}"
      end

    end
    
    module Unit
      include Zena::Test::LoadFixtures
      include Zena::Test::Base
      include Zena::Acts::Secure
      
      def setup
        $_test_site = 'zena'
      end
      
      # Set visitor for unit testing
      def login(name='anon',site_name = nil)
        # set site (find first matching site)
        site = Site.find(:first, :select=>"sites.*, sites.name = '#{site_name}' AS site_ok", :from => "sites, participations",
                         :conditions=>["participations.site_id = sites.id AND participations.user_id = ?", users_id(name)], :order => "site_ok DESC")
        
        $_test_site  = site.name if site
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
        @request    ||= ActionController::TestRequest.new
        @response   ||= ActionController::TestResponse.new
        @request.host = sites_host($_test_site || 'zena')
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
        $_test_site = @controller.send(:visitor).site.name
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
      def login(name=:anon, site='zena')
        $_test_site  = site
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
