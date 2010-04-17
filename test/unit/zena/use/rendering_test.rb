require 'test_helper'

class RenderingTest < Zena::View::TestCase
  def self.layout(*args); ''; end    # Called by Rendering::ControllerMethods
  def self.helper_method(*args); end # Called by Zafu::ControllerMethods
  include Zena::Use::Rendering::ControllerMethods
  include Zena::Use::ZafuTemplates::ControllerMethods # template_url
  include Zena::Acts::Secure # secure

  def params;  {}; end
  def dev_mode?; false; end
  def lang;  'en'; end
  def zafu_helper; @helper || self; end
  def method_missing(*args); ''; end
  def zen_path(*args); ''; end

  context 'With a node and skin' do
    setup do
      @node = secure!(Node) { Node.new }
      @node.skin = nodes(:default)
    end
    context 'resolving template_url' do

      should 'append host and insert lang on template_path_from_template_url' do
        assert_equal '/test.host/zafu/SKIN/TEMPLATE/en/DOM_ID', template_path_from_template_url('SKIN/TEMPLATE/DOM_ID')
      end

      should 'return a fullpath on fullpath_from_template_url' do
        assert_equal "#{SITES_ROOT}/test.host/zafu/SKIN/TEMPLATE/en/DOM_ID", fullpath_from_template_url('SKIN/TEMPLATE/DOM_ID')
      end

      should 'return a relative path on admin_layout' do
        assert_equal "/test.host/zafu/default/Node-+adminLayout/en/_main.erb", admin_layout
      end
    end # Rendering

    context 'Compilation of a template' do


      setup do
        controller = NodesController.new
        controller.session = {}
        @helper = ActionView::Base.new([], {}, controller)
        @helper.send(:_evaluate_assigns_and_ivars)
        @helper.helpers.send :include, controller.class.master_helper_module
      end

      should 'end with render_js inclusion' do
        compiled_template = template_url
        assert_match %r{<%= render_js %></body>}, File.read(File.join(SITES_ROOT, compiled_template))
      end
    end
  end
end