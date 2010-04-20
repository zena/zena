require 'test_helper'

class RenderingTest < Zena::View::TestCase
  context 'With a node and skin' do
    setup do
      login(:anon)
      visiting(:status)
    end

    context 'resolving template_url' do

      should 'append host and insert lang on template_path_from_template_url' do
        assert_equal '/test.host/zafu/SKIN/TEMPLATE/en/DOM_ID', template_path_from_template_url('SKIN/TEMPLATE/DOM_ID')
      end

      should 'return a fullpath on fullpath_from_template_url' do
        assert_equal "#{SITES_ROOT}/test.host/zafu/SKIN/TEMPLATE/en/DOM_ID", fullpath_from_template_url('SKIN/TEMPLATE/DOM_ID')
      end

      should 'return a relative path on admin_layout' do
        assert_equal "/test.host/zafu/default/Node-+adminLayout/en/_main.erb", controller.admin_layout
      end
    end # Rendering

    context 'compiling a template' do
      should 'end with render_js inclusion' do
        assert_match %r{<%= render_js %></body>}, File.read(File.join(SITES_ROOT, controller.template_url))
      end
    end # compiling a template
  end # With a node and skin
end