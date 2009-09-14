require 'test_helper'

class RenderingTest < Zena::View::TestCase
  include Zena::Use::Rendering::ControllerMethods
  include Zena::Use::Zafu::ControllerMethods # template_url
  include Zena::Acts::Secure # secure

  def params;  {}; end
  def session; {}; end
  def lang;  'en'; end

  def setup
    super
    @node = secure!(Node) { Node.new }
  end

  def test_admin_layout_should_be_an_absolute_path
    assert_match %r{\A\/}, SITES_ROOT
    assert_equal "#{SITES_ROOT}/test.host/zafu/default/Node-+adminLayout/en/_main.erb", admin_layout
  end

end