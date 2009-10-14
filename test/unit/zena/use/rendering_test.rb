require 'test_helper'

class RenderingTest < Zena::View::TestCase
  include Zena::Use::Rendering::ControllerMethods
  include Zena::Use::Zafu::ControllerMethods # template_url
  include Zena::Acts::Secure # secure

  def params;  {}; end
  def dev_mode?; false; end
  def lang;  'en'; end
  def zafu_helper; self; end
  def method_missing(*args); ''; end

  def setup
    super
    @node = secure!(Node) { Node.new }
  end

  def test_admin_layout_should_be_a_relative_path_in_sites
    assert_equal "/test.host/zafu/default/Node-+adminLayout/en/_main.erb", admin_layout
  end

end