require 'test_helper'

class ZafuTest < Zena::View::TestCase
  include Zena::Use::Zafu::ViewMethods
  include Zena::Use::Zafu::ControllerMethods

  # mocks
  def session; {} end
  def lang; 'en' end
  def zafu_helper; self end
  def method_missing(m, *args); [m,args].inspect end

  def test_page_numbers
    s = ""
    page_numbers(2, 3, ',') {|p,j| s << "#{j}#{p}"}
    assert_equal "1,2,3", s
    s = ""
    page_numbers(2, 30, ',') {|p,j| s << "#{j}#{p}"}
    assert_equal "1,2,3,4,5,6,7,8,9,10", s
    s = ""
    page_numbers(14, 30, ',') {|p,j| s << "#{j}#{p}"}
    assert_equal "10,11,12,13,14,15,16,17,18,19", s
    s = ""
    page_numbers(28, 30, ' | ') {|p,j| s << "#{j}#{p}"}
    assert_equal "21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30", s
  end

  def test_render_body_ends_with_js_render
    @node = secure!(Node) { nodes(:status) }
    compiled_template = template_url
    assert_match %r{<%= render_js %></body>}, File.read(File.join(SITES_ROOT, compiled_template))
  end
  
  def test_template_path_from_template_url
    assert_equal "/test.host/zafu/default/Node-test/en/pagir", template_path_from_template_url('/default/Node-test/pagir')
  end
  
  def test_fullpath_from_template_url
    assert_equal "#{SITES_ROOT}/test.host/zafu/default/Node-test/en/pagir", fullpath_from_template_url('/default/Node-test/pagir')
  end
end