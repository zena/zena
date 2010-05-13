require 'fileutils'
# load all fixtures and setup fixture_accessors:
FIXTURE_PATH = File.join(File.dirname(__FILE__), 'fixtures')
FILE_FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures', 'files')
# We use transactional fixtures with a single load for ALL tests (this is not the default rails implementation). Tests are now 5x-10x faster.
module Zena
  module Test

    # functional tests
    # module TestController
    #       include Zena::Use::Fixtures
    #       include Zena::Use::TestHelper
    #
    #       def init_controller
    #         $_test_site ||= 'zena'
    #         @request    ||= ActionController::TestRequest.new
    #         @response   ||= ActionController::TestResponse.new
    #         @request.host = sites_host($_test_site)
    #         @controller.instance_eval { @params = {}; @url = ActionController::UrlRewriter.new( @request, {} )}
    #         @controller.instance_variable_set(:@response, @response)
    #         @controller.send(:request=, @request)
    #         @controller.instance_variable_set(:@session, @request.session)
    #       end
    #
    #       def logout
    #         reset_session
    #       end
    #
    #       def session
    #         @controller.send(:session)
    #       end
    #
    #       def flash
    #         session['flash']
    #       end
    #
    #       def err(obj)
    #         obj.errors.each_error do |er,msg|
    #           puts "[#{er}] #{msg}"
    #         end
    #       end
    #
    #       def method_missing(meth,*args, &block)
    #         @controller.send(meth, *args, &block)
    #       end
    #     end

    module Integration
      include Zena::Acts::Secure
    end

    module HelperSetup
      def setup(request, response, url)
        I18n.locale = 'en'
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

    # Helper testing
    module TestHelper
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      #     attr_accessor :flash, :controller
      #
      #     # TODO: make this clean. Maybe use 'tests ....' or include these helpers cleanly in the actual (zafu parsing) module ?
      #     include ActionView::Helpers::ActiveRecordHelper # ActionView::Helpers::ActiveModelHelper
      #     include ActionView::Helpers::TagHelper
      #     include ActionView::Helpers::FormTagHelper
      #     include ActionView::Helpers::FormOptionsHelper
      #     include ActionView::Helpers::FormHelper
      #     include ActionView::Helpers::UrlHelper
      #     include ActionView::Helpers::AssetTagHelper
      #     include ActionView::Helpers::PrototypeHelper
      #
      #     def setup
      #       I18n.locale = 'en'
      #       @controllerClass ||= ApplicationController
      #       self.class.send(:include,@controllerClass.master_helper_module)
      #       eval "class StubController < #{@controllerClass}; include Zena::Test::HelperSetup; end"
      #       super
      #       @request    = ActionController::TestRequest.new
      #       @response   = ActionController::TestResponse.new
      #       @controller = StubController.new
      #       # Fake url rewriter so we can test url_for
      #       @url     = ActionController::UrlRewriter.new @request, {}
      #       @controller.setup(@request, @response, @url)
      #       @flash = {}
      #       ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
      #
      #     end

      def logout
        reset_session
      end

      def secure(*args, &block)
        @controller.send(:secure, *args, &block)
      end

      def err(obj)
        obj.errors.each_error do |er,msg|
          puts "[#{er}] #{msg}"
        end
      end

      def params
        @params ||= {}
      end
    end
  end
end

class Test::Unit::TestCase
  # we have to overwrite the 'default_test' dummy because we use sub-classes
  undef default_test
end

class ZenaTestController < ActionController::TestCase
  #include Zena::Test::TestController
end

Zena::Db.insert_zero_link(Link)