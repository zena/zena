module Zena
  module View
    class TestCase < ActionView::TestCase
      attr_accessor :params, :flash, :controller

      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure
      include ::Authlogic::TestCase

      # Load everything
      include ApplicationController.master_helper_module

      tests ApplicationHelper

      setup :activate_authlogic

      def assert_match(match, target)
        return super if match.kind_of?(Regexp)
        target = Hpricot(target)
        assert !target.search(match).empty?,
          "expected tag, but no tag found matching #{match.inspect} in:\n#{target.inspect}"
      end

      def assert_no_match(match, target)
        return super if match.kind_of?(Regexp)
        target = Hpricot(target)
        assert target.search(match).empty?,
          "expected not tag, but tag found matching #{match.inspect} in:\n#{target.inspect}"
      end

      def session
        @controller.session
      end

      tests ApplicationController.master_helper_module

      def visiting(node_name)
        # We use ApplicationController because it has all helper modules
        @controller = ApplicationController.new #ActionView::TestCase::TestController.new

        # Same type of initialization as TestController
        @controller.instance_eval do
          self.request = ActionController::TestRequest.new
          self.response = ActionController::TestResponse.new

          self.params  = {}
          self.session = {}
          @template = self.response.template = ::ActionView::Base.new(self.class.view_paths, {}, self)
          @template.helpers.send :include, self.class.master_helper_module
          initialize_current_url
        end

        @node = secure!(Node) { nodes(node_name) }
        @controller.instance_variable_set(:@node, @node)

        # Dummy request
        @controller.request.tap do |request|
          request.path_parameters = {
            'controller' => 'nodes',
            'action'     => 'show',
            'path'       => zen_path(nodes(node_name)).split('/')[2..-1],
            'prefix'     => visitor.is_anon? ? visitor.lang : AUTHENTICATED_PREFIX,
          }
          request.symbolized_path_parameters
          @params  = request.params
          @request = request
        end

        @flash   = {}
        class << @flash
          def discard
            clear
          end
        end

        @node
      end
    end
  end
end